"""Tests use synthetic files only. They never score the repository gold set."""
import contextlib
import csv
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


SCORE = module('eval_score', ROOT / 'scripts/eval_score.py')
STATE = module('sidecar_state', ROOT / '.claude/skills/mount-production-db/scripts/state.py')


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.gold = self.path / 'GOLD.csv'
        self.write_csv(self.gold, ['slice_id', 'id', 'gold'],
                       [['1', str(i), 'in_class' if i < 10 else 'out_class'] for i in range(20)])
        self.base = self.path / 'base.csv'
        self.candidate = self.path / 'candidate.csv'
        self.write_predictions(self.base, {0, 1, 2, 3, 4, 5, 6, 7, 10, 11})
        self.write_predictions(self.candidate, set(range(10)))
        self.config = self.path / 'config.json'
        self.config.write_text(json.dumps({run: {'code_revision': 'fixture', 'model': None} for run in ('baseline', 'candidate')}))

    def write_csv(self, path, header, values):
        with path.open('w', newline='') as stream:
            writer = csv.writer(stream)
            writer.writerow(header)
            writer.writerows(values)

    def write_predictions(self, path, qualified):
        self.write_csv(path, ['slice_id', 'id', 'bucket'],
                       [['1', str(i), 'qualified' if i in qualified else 'excluded'] for i in range(20)])

    def cli(self, mode, *args):
        output = self.path / 'result.json'
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/eval_score.py'), mode, *args,
                                 '--config', str(self.config), '--repo', str(ROOT), '--command', 'fixture baseline; fixture candidate',
                                 '--out', str(output)], text=True, capture_output=True)
        return result, output

    def test_confusion_counts(self):
        counts, precision, omission = SCORE.score(SCORE.gold(self.gold), self.base)
        self.assertEqual(counts, {'tp': 8, 'fp': 2, 'tn': 8, 'fn': 2})
        self.assertEqual(float(precision), .2)
        self.assertEqual(float(omission), .2)

    def test_classifier_report_and_no_overwrite(self):
        args = ('--gold', str(self.gold), '--baseline', str(self.base), '--candidate', str(self.candidate))
        result, output = self.cli('classifier', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(output.read_text())
        self.assertEqual(report['verdict'], 'keep')
        self.assertEqual(len(report['inputs']), 4)
        self.assertIn('revision', report['code'])
        self.assertEqual(report['inputs'][1]['sha256'], SCORE.sha256(self.gold))
        previous = output.read_bytes()
        result, _ = self.cli('classifier', *args)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(output.read_bytes(), previous)

    def test_worse_omission_kills_even_with_better_precision(self):
        self.write_predictions(self.candidate, {0, 1})
        result, output = self.cli('classifier', '--gold', str(self.gold), '--baseline', str(self.base), '--candidate', str(self.candidate))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text())['verdict'], 'kill')

    def test_minimum_and_unsure_labels(self):
        text = self.gold.read_text().replace('1,0,in_class', '1,0,unsure')
        self.gold.write_text(text)
        with self.assertRaisesRegex(ValueError, '20 labelled'):
            SCORE.gold(self.gold)

    def test_example_refused(self):
        with self.assertRaisesRegex(ValueError, 'live GOLD.csv'):
            SCORE.gold(self.path / 'GOLD.example.csv')

    def test_missing_duplicate_invalid_and_zero_denominator_predictions(self):
        labels = SCORE.gold(self.gold)
        for content, error in [('slice_id,id,bucket\n1,0,qualified\n', 'exactly match'),
                               ('slice_id,id,bucket\n1,0,qualified\n1,0,excluded\n', 'duplicate')]:
            self.candidate.write_text(content)
            with self.assertRaisesRegex(ValueError, error):
                SCORE.score(labels, self.candidate)
        self.write_predictions(self.candidate, set(range(20)))
        with self.assertRaisesRegex(ValueError, 'both|qualified and excluded'):
            SCORE.score(labels, self.candidate)
        self.candidate.write_text(self.base.read_text().replace('qualified', 'bogus'))
        with self.assertRaisesRegex(ValueError, 'bucket'):
            SCORE.score(labels, self.candidate)

    def test_pipeline_without_gold(self):
        self.gold.unlink()
        measurements = self.path / 'measurements.json'
        data = {'metric': 'recovery', 'baseline': 40, 'candidate': 65, 'target': 60, 'direction': 'higher', 'new_errors': 0}
        measurements.write_text(json.dumps(data))
        result, output = self.cli('pipeline', '--data', str(self.base), '--measurements', str(measurements))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text())['verdict'], 'keep')
        output.unlink()
        data['new_errors'] = 1
        measurements.write_text(json.dumps(data))
        result, output = self.cli('pipeline', '--data', str(self.base), '--measurements', str(measurements))
        self.assertEqual(json.loads(output.read_text())['verdict'], 'kill')

    def test_pipeline_rejects_nan(self):
        measurements = self.path / 'measurements.json'
        measurements.write_text('{"baseline": NaN, "candidate": 2, "target": 2, "new_errors": 0}')
        result, output = self.cli('pipeline', '--data', str(self.base), '--measurements', str(measurements))
        self.assertEqual(result.returncode, 2)
        self.assertFalse(output.exists())

    def test_state_roundtrip_encoding_permissions_and_no_secrets(self):
        state_path = self.path / 'state.json'
        pointer = self.path / 'pointer.json'
        dump = self.path / 'dump'
        dump.write_bytes(b'dump fixture')
        name = 'db /@?;$(echo no)'
        values = {'SESSION_ID': 'test', 'COMPOSE_PROJECT': 'eval-sidecar-test', 'DB_PORT': '55444',
                  'S3_URI': 's3://test/dump', 'DUMP_PATH': str(dump), 'STATE_DIR': str(self.path),
                  'STATE_FILE': str(state_path), 'COMPOSE_FILE': '/tmp/path with spaces/compose.yml',
                  'MCP_ENV_FILE': str(pointer), 'DB_NAME': name, 'DB_PASS': 'secret-superuser'}
        stdout = io.StringIO()
        with patch.dict(os.environ, values), contextlib.redirect_stdout(stdout):
            STATE.create()
        data = STATE.read(state_path)
        self.assertEqual(unquote(urlparse(data['DATABASE_URL']).path[1:]), name)
        self.assertNotIn('SUPERUSER_URL', data)
        self.assertNotIn('secret-superuser', state_path.read_text() + stdout.getvalue())
        self.assertNotIn('DATABASE_URL', stdout.getvalue())
        self.assertEqual(state_path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(pointer.stat().st_mode & 0o777, 0o600)

    def test_legacy_state_is_never_executed(self):
        sentinel = self.path / 'sentinel'
        file = self.path / 'state.env'
        file.write_text(f"SESSION_ID='$(touch {sentinel})'\n")
        self.assertIn('$(touch', STATE.read(file)['SESSION_ID'])
        self.assertFalse(sentinel.exists())


if __name__ == '__main__':
    unittest.main()

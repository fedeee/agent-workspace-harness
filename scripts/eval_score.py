#!/usr/bin/env python3
"""Validate frozen evaluation data and record reproducible offline results."""
import argparse
import csv
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

LABELS = {'in_class', 'out_class'}
BUCKETS = {'qualified', 'excluded'}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def rows(path, required):
    with Path(path).open(newline='', encoding='utf-8-sig') as stream:
        reader = csv.DictReader(stream)
        if len(reader.fieldnames or []) != len(set(reader.fieldnames or [])):
            raise ValueError(f'{path}: duplicate CSV headers')
        if not required.issubset(reader.fieldnames or []):
            raise ValueError(f'{path}: required columns: {sorted(required)}')
        result = {}
        for row in reader:
            if None in row or any(value is None for value in row.values()):
                raise ValueError(f'{path}: malformed CSV row')
            key = (row['slice_id'], row['id'])
            if not all(part.strip() for part in key) or key in result:
                raise ValueError(f'{path}: empty or duplicate (slice_id, id)')
            result[key] = row
    return result


def gold(path):
    if Path(path).name != 'GOLD.csv':
        raise ValueError('use the live GOLD.csv; example files are not evaluation data')
    data = rows(path, {'slice_id', 'id', 'gold'})
    if any(row['gold'] not in LABELS | {'unsure'} for row in data.values()):
        raise ValueError('gold must be in_class, out_class, or unsure')
    if sum(row['gold'] in LABELS for row in data.values()) < 20:
        raise ValueError('classifier evaluation requires at least 20 labelled rows')
    return data


def score(labels, path):
    predictions = rows(path, {'slice_id', 'id', 'bucket'})
    if predictions.keys() != labels.keys():
        raise ValueError('prediction IDs must exactly match the frozen gold IDs')
    counts = dict(tp=0, fp=0, tn=0, fn=0)
    for key, row in predictions.items():
        if row['bucket'] not in BUCKETS:
            raise ValueError('prediction bucket must be qualified or excluded')
        label = labels[key]['gold']
        if label == 'unsure':
            continue
        name = ('tp' if label == 'in_class' else 'fp') if row['bucket'] == 'qualified' else ('fn' if label == 'in_class' else 'tn')
        counts[name] += 1
    qualified = counts['tp'] + counts['fp']
    excluded = counts['tn'] + counts['fn']
    if not qualified or not excluded:
        raise ValueError('each run needs labelled qualified and excluded rows')
    precision_error = Fraction(counts['fp'], qualified)
    omission_error = Fraction(counts['fn'], excluded)
    return counts, precision_error, omission_error


def revision(repo):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.DEVNULL)
    head = git('rev-parse', 'HEAD').decode().strip()
    patch = git('diff', 'HEAD', '--binary')
    root = Path(git('rev-parse', '--show-toplevel').decode().strip())
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')
    hashes = {name.decode(): sha256(root / name.decode()) for name in untracked if name and (root / name.decode()).is_file()}
    return {'revision': head, 'dirty': bool(patch or hashes),
            'tracked_diff_sha256': hashlib.sha256(patch).hexdigest(), 'untracked_sha256': hashes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    validate = sub.add_parser('validate', help='validate classifier labels without a database')
    validate.add_argument('--gold', default='_eval/GOLD.csv')
    classifier = sub.add_parser('classifier')
    classifier.add_argument('--gold', default='_eval/GOLD.csv')
    classifier.add_argument('--baseline', required=True, help='CSV: slice_id,id,bucket')
    classifier.add_argument('--candidate', required=True, help='CSV: slice_id,id,bucket')
    pipeline = sub.add_parser('pipeline')
    pipeline.add_argument('--data', required=True, help='frozen input file or exported dump slice')
    pipeline.add_argument('--measurements', required=True, help='JSON: metric, baseline, candidate, target, direction, new_errors')
    for command in (classifier, pipeline):
        command.add_argument('--config', required=True, help='JSON with baseline and candidate model/runtime settings; no credentials')
        command.add_argument('--command', required=True, help='exact baseline and candidate commands; use environment names for secrets')
        command.add_argument('--repo', default='.')
        command.add_argument('--out', required=True, help='new JSON report path; existing results are never overwritten')
    args = parser.parse_args()
    try:
        if args.mode == 'validate':
            labels = gold(args.gold)
            print(json.dumps({'rows': len(labels), 'labelled': sum(r['gold'] in LABELS for r in labels.values()), 'sha256': sha256(args.gold)}))
            return
        config = json.loads(Path(args.config).read_text())
        if not isinstance(config, dict) or not {'baseline', 'candidate'}.issubset(config):
            raise ValueError('config must specify baseline and candidate settings')
        for run in ('baseline', 'candidate'):
            settings = config[run]
            if not isinstance(settings, dict) or not settings.get('code_revision'):
                raise ValueError('record a code_revision for baseline and candidate')
            if args.mode == 'classifier' and 'model' not in settings:
                raise ValueError('record each model identifier, or null for deterministic classifiers')
        if not args.command.strip():
            raise ValueError('record the exact evaluation commands')
        inputs = [args.config]
        if args.mode == 'classifier':
            labels = gold(args.gold)
            base, bp, br = score(labels, args.baseline)
            candidate, cp, cr = score(labels, args.candidate)
            keep = cp < bp and cr <= br
            result = {'baseline': {**base, 'precision_error': float(bp), 'false_omission_rate': float(br)},
                      'candidate': {**candidate, 'precision_error': float(cp), 'false_omission_rate': float(cr)},
                      'rule': 'precision error drops; false omission rate does not rise'}
            inputs += [args.gold, args.baseline, args.candidate]
        else:
            measurement = json.loads(Path(args.measurements).read_text())
            for key in ('baseline', 'candidate', 'target', 'new_errors'):
                value = measurement[key]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                    raise ValueError('pipeline measurements must be finite numbers')
            if not isinstance(measurement['metric'], str) or not measurement['metric'].strip():
                raise ValueError('name the pipeline metric')
            direction = measurement['direction']
            if direction not in ('higher', 'lower') or measurement['new_errors'] < 0:
                raise ValueError('invalid pipeline direction or error count')
            baseline, candidate, target = (measurement[k] for k in ('baseline', 'candidate', 'target'))
            keep = ((candidate > baseline and candidate >= target) if direction == 'higher' else
                    (candidate < baseline and candidate <= target)) and measurement['new_errors'] == 0
            result = {'measurements': measurement, 'rule': 'improve to the declared target with zero new errors'}
            inputs += [args.data, args.measurements]
        report = {'schema_version': 1, 'mode': args.mode, 'created_at': datetime.now(timezone.utc).isoformat(),
                  'inputs': [{'path': str(Path(path).resolve()), 'sha256': sha256(path)} for path in inputs],
                  'code': revision(args.repo), 'configuration': config, 'command': args.command,
                  'scorer_sha256': sha256(__file__), 'result': result, 'verdict': 'keep' if keep else 'kill'}
        output = Path(args.out)
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open('x') as stream:
            json.dump(report, stream, indent=2, allow_nan=False)
            stream.write('\n')
        print(f"{report['verdict']}: {output}")
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        parser.exit(2, f'eval-score: {error}\n')


if __name__ == '__main__':
    main()

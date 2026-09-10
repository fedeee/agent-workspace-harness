"""Offline regression checks for adoption, hooks, and config parity."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('codex_mcp', ROOT / 'scripts/codex_mcp.py')
MCP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MCP)


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='harness-test-')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo with spaces'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)

    def adopt(self, *flags, success=True):
        result = subprocess.run(
            ['bash', str(ROOT / 'scripts/adopt.sh'), str(self.repo), '--yes', *flags],
            env={**os.environ, 'HARNESS_PYTHON': sys.executable}, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_codex_core_and_detection(self):
        (self.repo / 'AGENTS.md').write_text('# Existing rules\n')
        self.adopt()
        self.assertTrue((self.repo / '.agents/skills/create-plan/SKILL.md').is_file())
        self.assertFalse((self.repo / '.cursor/skills').exists())
        self.assertFalse((self.repo / '.codex').exists())
        text = (self.repo / 'AGENTS.md').read_text()
        self.assertTrue(text.startswith('# Existing rules'))
        self.assertIn('Read `CLAUDE.md`', text)

    def test_codex_number_and_optional_skills(self):
        self.adopt('--agents', '4', '--eval', '--sidecar')
        self.assertTrue((self.repo / '.agents/skills/eval-loop/SKILL.md').is_file())
        self.assertTrue((self.repo / '.agents/skills/mount-production-db/scripts/mount.sh').is_file())
        self.assertNotIn('context7', (self.repo / '.codex/config.toml').read_text())

    def test_codex_dry_run(self):
        self.adopt('--agents', 'codex', '--mcp', '--hooks', '--eval', '--dry-run')
        self.assertEqual([p.name for p in self.repo.iterdir()], ['.git'])

    @unittest.skipIf(MCP.tomllib is None, 'Python 3.11+ required for existing TOML')
    def test_codex_preserves_config_and_is_idempotent(self):
        (self.repo / '.codex').mkdir()
        original = '# Keep comments\nmodel = "custom-model"\n[mcp_servers.context7]\ncommand = "custom"\n'
        config = self.repo / '.codex/config.toml'
        config.write_text(original)
        self.adopt('--agents', 'codex', '--mcp')
        first = config.read_text()
        self.assertTrue(first.startswith(original))
        parsed = MCP.tomllib.loads(first)
        self.assertEqual(parsed['mcp_servers']['context7']['command'], 'custom')
        self.assertIn('playwright', parsed['mcp_servers'])
        self.adopt('--agents', 'codex', '--mcp')
        self.assertEqual(first, config.read_text())

    @unittest.skipIf(MCP.tomllib is None, 'Python 3.11+ required for existing TOML')
    def test_invalid_codex_config_is_not_changed(self):
        (self.repo / '.codex').mkdir()
        config = self.repo / '.codex/config.toml'
        config.write_text('invalid = [')
        self.adopt('--agents', 'codex', '--mcp', success=False)
        self.assertEqual(config.read_text(), 'invalid = [')

    def test_copilot_uses_servers_and_preserves_existing(self):
        (self.repo / '.vscode').mkdir()
        config = self.repo / '.vscode/mcp.json'
        config.write_text(json.dumps({'inputs': [], 'servers': {'context7': {'command': 'custom'}}}))
        self.adopt('--agents', 'copilot', '--mcp')
        data = json.loads(config.read_text())
        self.assertNotIn('mcpServers', data)
        self.assertIn('playwright', data['servers'])
        self.assertEqual(data['servers']['context7']['command'], 'custom')
        self.assertEqual(data['inputs'], [])

    def test_hooks_merge_and_repeat(self):
        (self.repo / '.codex').mkdir()
        config = self.repo / '.codex/hooks.json'
        custom = {'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': 'echo custom'}]}
        config.write_text(json.dumps({'custom': True, 'hooks': {'PreToolUse': [custom]}}))
        self.adopt('--agents', 'codex', '--hooks')
        first = json.loads(config.read_text())
        self.assertTrue(first['custom'])
        self.assertIn(custom, first['hooks']['PreToolUse'])
        self.assertEqual(len(first['hooks']['PreToolUse']), 2)
        self.adopt('--agents', 'codex', '--hooks')
        self.assertEqual(first, json.loads(config.read_text()))

    def test_existing_partial_gitignore_gets_secret_rules(self):
        (self.repo / '.gitignore').write_text('_worktrees/\n')
        self.adopt('--agents', 'codex')
        self.assertIn('_local/*.env', (self.repo / '.gitignore').read_text())

    def test_symlink_destination_refused(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        (self.repo / '.agents').symlink_to(outside, target_is_directory=True)
        self.adopt('--agents', 'codex', success=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_hooks_protocols(self):
        blocked = ['git push', 'git -C /tmp push origin main', '/usr/bin/git -c a=b push',
                   'git commit --no-verify', 'git commit -n', 'ssh', '/usr/bin/ssh host',
                   'bash -lc "git -C /tmp push"', 'git status && git push']
        allowed = ['git status', 'git diff', 'git commit -m "fix bug"',
                   'echo "git push"', 'rg --no-ignore pattern', 'git log -n 5']
        for command in blocked + allowed:
            for agent in ('cursor', 'claude', 'codex'):
                with self.subTest(command=command, agent=agent):
                    payload = {'command': command} if agent == 'cursor' else {
                        'hook_event_name': 'PreToolUse',
                        'tool_input': {'cmd' if agent == 'codex' else 'command': command}}
                    result = subprocess.run([sys.executable, str(ROOT / '.cursor/hooks/deny-shell.py')],
                                            input=json.dumps(payload), capture_output=True, text=True, check=True)
                    data = json.loads(result.stdout)
                    if agent == 'cursor':
                        self.assertEqual(data['permission'], 'deny' if command in blocked else 'allow')
                    elif command in blocked:
                        self.assertEqual(data['hookSpecificOutput']['permissionDecision'], 'deny')
                    else:
                        self.assertEqual(data, {})

    def test_hook_runs_from_subdirectory(self):
        self.adopt('--agents', 'codex', '--hooks')
        sub = self.repo / 'sub'
        sub.mkdir()
        config = json.loads((self.repo / '.codex/hooks.json').read_text())
        command = config['hooks']['PreToolUse'][0]['hooks'][0]['command']
        result = subprocess.run(['bash', '-c', command], cwd=sub,
                                input=json.dumps({'tool_input': {'cmd': 'git push'}}),
                                text=True, capture_output=True, check=True)
        self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')

    def test_sidecar_without_eval_finds_repo(self):
        self.adopt('--agents', 'codex', '--sidecar', '--no-eval')
        result = subprocess.run(['bash', str(self.repo / '.agents/skills/mount-production-db/scripts/mount.sh')],
                                env={**os.environ, 'EVAL_BACKUP_BUCKET': ''}, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('set EVAL_BACKUP_BUCKET', result.stderr)
        self.assertNotIn('could not find', result.stderr)

    def mock_command(self, name, body):
        directory = Path(self.temp.name) / 'bin'
        directory.mkdir(exist_ok=True)
        path = directory / name
        path.write_text('#!/usr/bin/env bash\n' + body)
        path.chmod(0o755)
        return str(directory)

    def test_restore_exit_one_fails_and_cleans_up(self):
        self.adopt('--agents', 'codex', '--sidecar')
        sid = uuid.uuid4().hex[:12]
        state = Path('/tmp') / ('eval-sidecar-' + sid)
        self.addCleanup(shutil.rmtree, state, True)
        self.mock_command('aws', 'touch "$4"\n')
        self.mock_command('python3', 'if [[ "$1" == -c ]]; then echo "$TEST_SID"; else cat >/dev/null; echo 55499; fi\n')
        mock_path = self.mock_command('docker', 'echo "$*" >> "$TEST_LOG"\ncase "$*" in *pg_restore*) exit 1;; esac\n')
        log = Path(self.temp.name) / 'docker.log'
        result = subprocess.run(['bash', str(self.repo / '.agents/skills/mount-production-db/scripts/mount.sh'),
                                 's3://test/db.dump'], capture_output=True, text=True,
                                env={**os.environ, 'PATH': mock_path + ':' + os.environ['PATH'],
                                     'TEST_SID': sid, 'TEST_LOG': str(log)})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('pg_restore failed with exit 1', result.stderr)
        self.assertEqual(log.read_text().count('down -v'), 1)
        self.assertFalse(state.exists())

    def test_teardown_rejects_unexpected_directory(self):
        state = Path(self.temp.name) / 'state.env'
        state.write_text(f'SESSION_ID=test\nSTATE_DIR={shlex.quote(str(self.repo))}\nCOMPOSE_PROJECT=eval-sidecar-test\nDB_PORT=55444\n')
        result = subprocess.run(['bash', str(ROOT / '.claude/skills/mount-production-db/scripts/teardown.sh'), str(state)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unexpected sidecar state directory', result.stderr)
        self.assertTrue(self.repo.exists())

    def test_mount_success_uses_json_and_teardown_removes_pointer(self):
        self.adopt('--agents', 'codex', '--sidecar')
        sid = uuid.uuid4().hex[:12]
        state_dir = Path('/tmp') / ('eval-sidecar-' + sid)
        self.addCleanup(shutil.rmtree, state_dir, True)
        pointer = Path(self.temp.name) / 'pointer.json'
        sql = Path(self.temp.name) / 'sql.txt'
        self.mock_command('aws', 'touch "$4"\n')
        self.mock_command('python3', 'if [[ "$1" == -c ]]; then echo "$TEST_SID"; elif [[ "$1" == - ]]; then cat >/dev/null; echo 55499; else exec "$REAL_PYTHON" "$@"; fi\n')
        mock_path = self.mock_command('docker', 'case "$*" in *psql*) cat > "$TEST_SQL";; esac\nexit 0\n')
        env = {**os.environ, 'PATH': mock_path + ':' + os.environ['PATH'],
               'REAL_PYTHON': sys.executable, 'TEST_SID': sid, 'TEST_SQL': str(sql),
               'EVAL_MCP_ENV': str(pointer), 'EVAL_DB_NAME': 'test /@ db', 'EVAL_DB_PASS': 'private-password'}
        scripts = self.repo / '.agents/skills/mount-production-db/scripts'
        result = subprocess.run(['bash', str(scripts / 'mount.sh'), 's3://test/dump'], env=env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        state = json.loads(Path(report['STATE_FILE']).read_text())
        self.assertTrue(state['DATABASE_URL'].endswith('/test%20%2F%40%20db'))
        self.assertNotIn('private-password', result.stdout + result.stderr + json.dumps(state))
        self.assertIn('DATABASE :"target_db"', sql.read_text())
        result = subprocess.run(['bash', str(scripts / 'teardown.sh'), sid], env=env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(pointer.exists())
        self.assertFalse(state_dir.exists())

    def test_teardown_keeps_state_when_docker_fails(self):
        sid = uuid.uuid4().hex[:12]
        state_dir = Path('/tmp') / ('eval-sidecar-' + sid)
        state_dir.mkdir()
        self.addCleanup(shutil.rmtree, state_dir, True)
        state = state_dir / 'state.env'
        state.write_text(f'SESSION_ID={sid}\nSTATE_DIR={state_dir}\nCOMPOSE_PROJECT=eval-sidecar-{sid}\nDB_PORT=55444\n')
        mock_path = self.mock_command('docker', 'exit 1\n')
        result = subprocess.run(['bash', str(ROOT / '.claude/skills/mount-production-db/scripts/teardown.sh'), str(state)],
                                env={**os.environ, 'PATH': mock_path + ':' + os.environ['PATH']},
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(state.exists())

    def test_worktree_cleanup_checks_branch(self):
        self.adopt('--agents', 'codex')
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                        'commit', '-qm', 'test fixture'], check=True)
        script = self.repo / 'scripts/worktree_agent.sh'
        subprocess.run(['bash', str(script), 'test/branch'], capture_output=True, check=True)
        result = subprocess.run(['bash', str(script), '--clean', 'test-branch'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('belongs to test/branch', result.stderr)
        subprocess.run(['bash', str(script), '--clean', 'test/branch'], capture_output=True, check=True)

    def test_mirrors_match(self):
        source = ROOT / '.claude/skills'
        for folder in ('.cursor/skills', '.agents/skills'):
            mirror = ROOT / folder
            for path in source.rglob('*'):
                if path.is_file() and '__pycache__' not in path.parts:
                    self.assertEqual(path.read_bytes(), (mirror / path.relative_to(source)).read_bytes())


if __name__ == '__main__':
    unittest.main()

"""Exercise installer menus through a real pseudo-terminal."""
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import termios
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PromptTests(unittest.TestCase):
    def run_prompt(self, command, keys, expected_code=0):
        master, slave = pty.openpty()
        before = termios.tcgetattr(slave)
        process = subprocess.Popen(
            ['bash', '-c', f'source {shlex.quote(str(ROOT / "scripts/adopt.sh"))}; {command}'],
            stdin=slave, stdout=slave, stderr=slave,
            env={**os.environ, 'TERM': 'xterm'},
        )
        output = bytearray()
        try:
            deadline = time.monotonic() + 5
            while b'\r\x1b[2K' not in output:
                self.assertLess(time.monotonic(), deadline, bytes(output))
                if select.select([master], [], [], 0.1)[0]:
                    output.extend(os.read(master, 65536))
            os.write(master, keys)
            while process.poll() is None:
                self.assertLess(time.monotonic(), deadline, bytes(output))
                if select.select([master], [], [], 0.1)[0]:
                    output.extend(os.read(master, 65536))
            while select.select([master], [], [], 0)[0]:
                output.extend(os.read(master, 65536))
            self.assertEqual(process.returncode, expected_code, bytes(output))
            after = termios.tcgetattr(slave)
            # macOS can set PENDIN when Bash restores canonical input.
            after[3] &= ~getattr(termios, 'PENDIN', 0)
            before[3] &= ~getattr(termios, 'PENDIN', 0)
            self.assertEqual(after, before)
            return output.decode()
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()
            os.close(master)
            os.close(slave)

    def test_detected_defaults(self):
        output = self.run_prompt('prompt_agents "copilot codex"; echo "RESULT:$AGENTS_SELECTED"', b'\n')
        self.assertIn('RESULT:copilot codex', output)

    def test_multi_select_and_wrap(self):
        output = self.run_prompt('prompt_agents ""; echo "RESULT:$AGENTS_SELECTED"',
                                 b' \x1b[B \x1b[A\x1b[A \n')
        self.assertIn('RESULT:codex', output)

    def test_empty_selection_requires_choice(self):
        output = self.run_prompt('prompt_agents cursor; echo "RESULT:$AGENTS_SELECTED"', b' \n \n')
        self.assertIn('Select at least one agent.', output)
        self.assertIn('RESULT:cursor', output)

    def test_yes_no_defaults_and_arrows(self):
        for default, keys, result in [(1, b'\n', 'yes'), (0, b'\n', 'no'),
                                      (0, b'\x1b[A\n', 'yes'), (1, b'\x1bOB\n', 'no')]:
            with self.subTest(default=default, keys=keys):
                output = self.run_prompt(
                    f'if prompt_yes_no "Continue?" {default}; then echo RESULT:yes; else echo RESULT:no; fi', keys)
                self.assertIn(f'RESULT:{result}', output)

    def test_escape_cancels(self):
        output = self.run_prompt('prompt_agents cursor; echo UNREACHABLE', b'\x1b', 130)
        self.assertIn('aborted', output)
        self.assertNotIn('UNREACHABLE', output)


if __name__ == '__main__':
    unittest.main()

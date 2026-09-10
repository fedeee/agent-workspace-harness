#!/usr/bin/env python3
"""Read sidecar data without executing it; write private, atomic JSON files."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import tempfile
from urllib.parse import quote


def read(path):
    text = Path(path).read_text()
    if text.lstrip().startswith('{'):
        data = json.loads(text)
    else:
        # Older sessions used shell assignments. Parse only; never source them.
        data = {}
        for line in text.splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            key, sep, value = line.partition('=')
            if not sep or not re.fullmatch(r'[A-Z_]+', key):
                raise ValueError('invalid legacy state assignment')
            parts = shlex.split(value, comments=False)
            if len(parts) > 1:
                raise ValueError('invalid legacy state value; remount the database')
            data[key] = parts[0] if parts else ''
    if not isinstance(data, dict) or any(not isinstance(v, (str, int)) for v in data.values()):
        raise ValueError('invalid sidecar state object')
    return data


def write(path, data):
    path = Path(path)
    descriptor, temporary = tempfile.mkstemp(prefix='.sidecar-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(data, stream, indent=2)
            stream.write('\n')
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def create():
    keys = ('SESSION_ID', 'COMPOSE_PROJECT', 'DB_PORT', 'S3_URI', 'DUMP_PATH',
            'STATE_DIR', 'STATE_FILE', 'COMPOSE_FILE', 'MCP_ENV_FILE')
    data = {key: os.environ[key] for key in keys}
    name = quote(os.environ['DB_NAME'], safe='')
    port = int(data['DB_PORT'])
    data['DATABASE_URL'] = f'postgresql://eval_ro:eval_ro@localhost:{port}/{name}'
    data['EVAL_SIDECAR_URL'] = f'postgresql://eval_ro:eval_ro@host.docker.internal:{port}/{name}'
    digest = hashlib.sha256()
    with open(data['DUMP_PATH'], 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    data['DUMP_SHA256'] = digest.hexdigest()
    write(data['STATE_FILE'], data)
    write(data['MCP_ENV_FILE'], {key: data[key] for key in ('SESSION_ID', 'STATE_FILE', 'EVAL_SIDECAR_URL')})
    # Report locations, never database credentials.
    print(json.dumps({key: data[key] for key in ('SESSION_ID', 'STATE_FILE', 'DUMP_SHA256')}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('get', 'create'))
    parser.add_argument('path', nargs='?')
    parser.add_argument('key', nargs='?')
    args = parser.parse_args()
    try:
        if args.action == 'create':
            create()
        else:
            value = str(read(args.path)[args.key])
            if '\n' in value or '\x00' in value:
                raise ValueError('multiline state values are not supported')
            print(value)
    except (OSError, ValueError, KeyError, TypeError):
        parser.exit(2, 'sidecar-state: invalid or unreadable state; inspect the file or remount\n')


if __name__ == '__main__':
    main()

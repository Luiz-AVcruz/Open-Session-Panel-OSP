#!/usr/bin/env python3
"""Resolve Teardown includes, check Lua 5.1 syntax and exercise server/client contracts."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mod'


def expand(path, active=()):
    path = path.resolve()
    if not path.is_relative_to(MOD) or path in active:
        raise ValueError(f'Invalid include: {path}')
    lines = []
    for line in path.read_text().splitlines():
        if line.startswith('#version '):
            if line.strip() != '#version 2':
                raise ValueError(f'Unsupported version in {path}')
            continue
        include = re.fullmatch(r'#include "([^\"]+)"', line.strip())
        if include:
            lines.append(expand(MOD / include[1], active + (path,)))
        else:
            lines.append(line)
    return '\n'.join(lines) + '\n'


def main():
    runtime = shutil.which('luajit')
    if not runtime:
        raise SystemExit('LuaJIT (Lua 5.1 compatible) is required for development checks.')
    source = expand(MOD / 'main.lua')
    with tempfile.TemporaryDirectory(prefix='osp-check-') as tmp:
        bundle = Path(tmp) / 'main.lua'
        bundle.write_text(source)
        subprocess.run([runtime, '-b', str(bundle), str(Path(tmp) / 'syntax.luac')], check=True)
        options = Path(tmp) / 'options.lua'
        options.write_text(expand(MOD / 'options.lua'))
        subprocess.run([runtime, '-b', str(options), str(Path(tmp) / 'options.luac')], check=True)
        for test in sorted((ROOT / 'tests').glob('test_*.lua')):
            entry = options if test.name == 'test_options.lua' else bundle
            subprocess.run([runtime, str(test), str(entry)], cwd=ROOT, check=True)
    print('PASS: expanded entry point, Lua 5.1 syntax and all available contract tests')


if __name__ == '__main__':
    main()

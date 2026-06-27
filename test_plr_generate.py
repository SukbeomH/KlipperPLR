#!/usr/bin/env python3
import subprocess
import tempfile
from pathlib import Path

GEN = Path(__file__).with_name('plr_generate.py')


def run_case(source, resume_z='2.0', expect_ok=True):
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / 'source.gcode'
        out = Path(td) / 'out.gcode'
        src.write_text(source)
        proc = subprocess.run(
            ['python3', str(GEN), str(resume_z), str(src), str(out)],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if expect_ok and proc.returncode != 0:
            raise AssertionError(f'expected success, got {proc.returncode}\nSTDOUT={proc.stdout}\nSTDERR={proc.stderr}')
        if not expect_ok:
            if proc.returncode == 0:
                raise AssertionError('expected failure but succeeded')
            if out.exists():
                raise AssertionError('failed generation must not leave output file')
            return proc
        return out.read_text().splitlines()


def assert_first_line(lines, expected):
    if not lines:
        raise AssertionError('empty output')
    if lines[0] != expected:
        raise AssertionError(f'first line mismatch: {lines[0]!r} != {expected!r}')


def test_thumbnail_base64_comment_is_ignored():
    lines = run_case('''
; thumbnail begin
; Z8jQVLH+not-a-number
; thumbnail end
M140 S110
M104 S250
G1 X0 Y0 Z0.25 F1200
G1 X1 Y1 E0.2
G1 Z2.09 F36000
G1 X2 Y2 E0.3
''')
    assert_first_line(lines, 'SET_KINEMATIC_POSITION Z=2.09')
    if any('8jQVLH' in line for line in lines[:12]):
        raise AssertionError('base64 thumbnail token leaked into PLR header')


def test_inline_comment_z_is_ignored():
    lines = run_case('''
G1 X0 Y0 Z0.3 ; Z99.9 comment must be ignored
G1 X5 Y5 ; Z8jQVLH ignored
G1 X10 Y10 Z2.4 E1.2
''')
    assert_first_line(lines, 'SET_KINEMATIC_POSITION Z=2.4')


def test_compact_lowercase_motion_is_supported():
    lines = run_case('''
g1x0y0z0.2e0.1
g1x1y1z2.05e0.2
''')
    assert_first_line(lines, 'SET_KINEMATIC_POSITION Z=2.05')


def test_absolute_extruder_restores_last_e_before_resume():
    lines = run_case('''
M82
G1 X0 Y0 Z0.3 E1.25
G1 X1 Y1 E2.5
G1 Z2.1 F3600
G1 X2 Y2 E3.0
''')
    if 'G92 E2.5' not in lines[:10]:
        raise AssertionError(f'expected G92 E2.5 in header, got {lines[:10]!r}')


def test_relative_extruder_restores_m83_mode():
    lines = run_case('''
M83
G1 X0 Y0 Z0.3 E0.1
G1 Z2.1 F3600
G1 X2 Y2 E0.2
''')
    header = '\n'.join(lines[:12])
    if 'G92 E0' not in header or 'M83' not in header:
        raise AssertionError(f'expected relative E restore in header, got {lines[:12]!r}')


def test_comment_temperature_commands_are_ignored():
    lines = run_case('''
; M104 S999
; M140 S999
M104 S240
M140 S105
G1 Z2.2 F3600
''')
    header = lines[:8]
    if any('999' in line for line in header):
        raise AssertionError(f'comment temperature leaked into header: {header!r}')
    if 'M104 S240' not in header or 'M140 S105' not in header:
        raise AssertionError(f'real temperature commands missing: {header!r}')


def test_no_resume_z_fails_without_output():
    proc = run_case('''
; only comments
G1 X0 Y0 Z0.2
G1 X1 Y1
''', resume_z='2.0', expect_ok=False)
    if 'no numeric G0/G1 Z move' not in proc.stderr:
        raise AssertionError(f'unexpected stderr: {proc.stderr!r}')


def main():
    tests = [name for name in globals() if name.startswith('test_')]
    for name in sorted(tests):
        globals()[name]()
        print(f'PASS {name}')
    print(f'{len(tests)} tests passed')


if __name__ == '__main__':
    main()

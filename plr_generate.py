#!/usr/bin/env python3
import re
import sys
from pathlib import Path

TOKEN_RE = re.compile(r'([A-Za-z])([-+]?(?:\d+(?:\.\d*)?|\.\d+))')
MOTION_CMDS = {'G0', 'G00', 'G1', 'G01'}
TEMP_CMDS = {'M104', 'M109', 'M140', 'M190', 'M106'}


def split_code(line):
    return line.split(';', 1)[0].strip()


def command(code):
    if not code:
        return ''
    first = code.split(None, 1)[0].upper()
    match = re.match(r'([GMT]\d+)', first)
    return match.group(1) if match else ''


def params(code):
    return {letter.upper(): float(value) for letter, value in TOKEN_RE.findall(code)}


def is_motion(code):
    return command(code) in MOTION_CMDS


def fmt_num(value):
    text = f'{value:.5f}'.rstrip('0').rstrip('.')
    return text if text else '0'


def find_resume_index(parsed, resume_z):
    for index, code, values in parsed:
        if is_motion(code) and 'Z' in values and values['Z'] >= resume_z:
            return index, values['Z']
    raise RuntimeError(f'no numeric G0/G1 Z move found at or above Z={resume_z}')


def last_temperatures(parsed, stop_index):
    last = {}
    order = []
    for index, code, _values in parsed:
        if index >= stop_index:
            break
        cmd = command(code)
        if cmd not in TEMP_CMDS:
            continue
        if 'S' not in params(code):
            continue
        if cmd not in order:
            order.append(cmd)
        last[cmd] = code
    return [last[cmd] for cmd in order if cmd in last]


def extrusion_setup(parsed, resume_index):
    relative = False
    last_e = None
    first_future_e = None
    for index, code, values in parsed:
        cmd = command(code)
        if index < resume_index:
            if cmd == 'M82':
                relative = False
            elif cmd == 'M83':
                relative = True
            elif is_motion(code) and 'E' in values:
                last_e = values['E']
        elif first_future_e is None and is_motion(code) and 'E' in values:
            first_future_e = values['E']
    if relative:
        return ['G92 E0', 'M83']
    e_value = last_e if last_e is not None else first_future_e
    if e_value is None:
        return []
    return [f'G92 E{fmt_num(e_value)}']


def generate(resume_z, source_path, output_path):
    lines = source_path.read_text(errors='ignore').splitlines()
    parsed = []
    for index, line in enumerate(lines):
        code = split_code(line)
        if not code:
            continue
        parsed.append((index, code, params(code)))

    resume_index, resume_actual_z = find_resume_index(parsed, resume_z)
    output = [f'SET_KINEMATIC_POSITION Z={fmt_num(resume_actual_z)}']
    output.append('M118 START_TEMPS...')
    output.extend(last_temperatures(parsed, resume_index))
    output.extend(extrusion_setup(parsed, resume_index))
    output.extend([
        'G91',
        'G1 Z10',
        'G90',
        'G28 X Y',
        'G91',
        'G1 Z-5',
        'G90',
        'M106 S204',
    ])
    output.extend(lines[resume_index:])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = output_path.with_name(output_path.name + '.tmp')
    tmp_path.write_text('\n'.join(output) + '\n')
    tmp_path.replace(output_path)
    return resume_actual_z, len(output)


def main(argv):
    if len(argv) != 4:
        print('usage: plr_generate.py RESUME_Z SOURCE_GCODE OUTPUT_GCODE', file=sys.stderr)
        return 2
    resume_z = float(argv[1])
    source_path = Path(argv[2])
    output_path = Path(argv[3])
    if not source_path.is_file():
        print(f'source G-code not found: {source_path}', file=sys.stderr)
        return 1
    try:
        actual_z, line_count = generate(resume_z, source_path, output_path)
    except Exception as exc:
        print(f'PLR generation failed: {exc}', file=sys.stderr)
        return 1
    print(f'PLR generated: {output_path} resume_z={fmt_num(actual_z)} lines={line_count}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))

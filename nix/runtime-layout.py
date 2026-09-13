"""Generate named output layouts from compositor modes before locking."""
import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def select_outputs(outputs, configured, discover):
    enabled = {o['name']: o for o in outputs if o.get('enabled')}
    specs = list(configured)
    if discover:
        names = {m['name'] for m in specs}
        specs += [{'name': n} for n in enabled if n not in names]
    selected = []
    for spec in specs:
        name = spec['name']
        if name not in enabled:
            continue
        if not re.fullmatch(r'[A-Za-z0-9._-]+', name):
            raise ValueError(f'Unsupported output name: {name!r}')
        width, height = spec.get('width'), spec.get('height')
        if (width is None) != (height is None):
            raise ValueError(f'{name}: specify both width and height')
        if width is None:
            modes = [m for m in enabled[name].get('modes', [])
                     if m.get('width', 0) > 0 and m.get('height', 0) > 0]
            if not modes:
                raise ValueError(f'{name}: no supported modes reported')
            mode = max(modes, key=lambda m: (m['width'] * m['height'], m['width'], m['height']))
            width, height = mode['width'], mode['height']
        if min(4 * height // 9, width // 4) // 12 <= 0:
            raise ValueError(f'{name}: resolution too small')
        selected.append((name, width, height))
    if not selected:
        raise ValueError('No enabled outputs match the Sakoora configuration')
    return selected


def generate(source, destination, name, width, height, style, namespace):
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for folder in ('styles', 'to_move'):
            shutil.copytree(source / folder, work / folder, symlinks=True)
        # Nix store sources are read-only; generators replace files in this copy.
        for path in work.rglob('*'):
            if not path.is_symlink():
                path.chmod(path.stat().st_mode | 0o200)
        pw = min(4 * height // 9, width // 4)
        env = dict(os.environ, S_PATH=str(work), width=str(width), height=str(height),
                   pw=str(pw), pp=str(pw // 12))
        for s in (1, 2):
            subprocess.run(['bash', str(source / f'style-{s}')], env=env, check=True)
        root = work / 'to_move/sakoora.hyprlock'
        variables = set()
        for path in root.rglob('*.conf'):
            variables.update(re.findall(r'^\$([A-Za-z_][A-Za-z_0-9]*)\s*=', path.read_text(), re.M))
        for path in root.rglob('*'):
            if path.is_symlink() or not path.is_file():
                continue
            if path.suffix not in ('.conf', '.sh') and path.parent.name != 'scripts':
                continue
            text = path.read_text().replace('.config/hypr/sakoora.hyprlock/',
                                           f'.cache/sakoora-layout/outputs/{namespace}/')
            text = text.replace('hyprlock-cache/', f'hyprlock-cache/{namespace}/')
            if path.suffix == '.conf':
                text = re.sub(r'\$([A-Za-z_][A-Za-z_0-9]*)',
                              lambda m: '$' + namespace + '_' + m[1] if m[1] in variables else m[0], text)
            if path.name == 'hyprlock.conf':
                text = re.sub(r'^monitor\s*=.*\n?', '', text, flags=re.M)
                text = re.sub(r'^(background|image|shape|label|input-field) \{$',
                              lambda m: m[0] + '\nmonitor = ' + name, text, flags=re.M)
            path.write_text(text)
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(root, destination, symlinks=True)
    return (destination / f'style-{style}/hyprlock.conf').read_text()


def main():
    source, settings_path, style = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
    settings = json.loads(settings_path.read_text())
    root = Path.home() / '.cache/sakoora-layout'
    root.mkdir(parents=True, exist_ok=True)
    with (root / 'generation.lock').open('w') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        prepare(source, settings, style, root)


def prepare(source, settings, style, root):
    outputs = json.loads(subprocess.check_output(['wlr-randr', '--json']))
    selected = select_outputs(outputs, settings['monitors'], settings['autoDetect'])
    configs, jobs = [], []
    for index, (name, width, height) in enumerate(selected):
        namespace = 'auto_' + name.replace('-', '_').replace('.', '_') + '_' + str(index)
        destination = root / 'outputs' / namespace
        config = generate(source, destination, name, width, height, style, namespace)
        if index:
            config = re.sub(r'^animations \{\n.*?^\}\n?', '', config, flags=re.M | re.S)
        configs.append(config)
        jobs.append((destination / f'style-{style}/scripts/panels', name))
    def panels(job):
        script, name = job
        subprocess.run(['bash', str(script), *sys.argv[4:]],
                       env=dict(os.environ, SAKOORA_MONITOR=name), check=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        list(pool.map(panels, jobs))
    pending = root / 'current_style.conf.tmp'
    pending.write_text('\n'.join(configs))
    pending.replace(root / 'current_style.conf')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'sakoora-panels: {error}')

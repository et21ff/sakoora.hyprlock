import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import json

spec = importlib.util.spec_from_file_location('layout', Path(__file__).with_name('runtime-layout.py'))
layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layout)


class LayoutTests(unittest.TestCase):
    outputs = [
        {'name': 'DP-1', 'enabled': True, 'modes': [
            {'width': 1920, 'height': 1080, 'current': True},
            {'width': 2560, 'height': 1440},
            {'width': 3840, 'height': 900}]},
        {'name': 'eDP-1', 'enabled': True, 'modes': [{'width': 1920, 'height': 1200}]},
        {'name': 'HDMI-A-1', 'enabled': False, 'modes': []},
    ]

    def test_maximum_area_and_disconnected(self):
        result = layout.select_outputs(self.outputs, [{'name': 'DP-1'}, {'name': 'HDMI-A-1'}], False)
        self.assertEqual(result, [('DP-1', 2560, 1440)])

    def test_explicit_override_and_discovery(self):
        result = layout.select_outputs(self.outputs, [{'name': 'DP-1', 'width': 1280, 'height': 720}], True)
        self.assertEqual(result, [('DP-1', 1280, 720), ('eDP-1', 1920, 1200)])

    def test_missing_dimensions_and_modes(self):
        for specs in ([{'name': 'DP-1', 'width': 1920}], [{'name': 'missing'}]):
            with self.assertRaises(ValueError):
                layout.select_outputs(self.outputs, specs, False)
        with self.assertRaises(ValueError):
            layout.select_outputs([{'name': 'DP-1', 'enabled': True}], [], True)

    def test_generated_styles_are_isolated(self):
        source = Path(__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory() as tmp:
            for style in (1, 2):
                destination = Path(tmp) / str(style)
                config = layout.generate(source, destination, 'DP-1', 2560, 1440, style, 'auto_DP_1')
                self.assertIn('monitor = DP-1', config)
                self.assertIn('$auto_DP_1_', config)
                self.assertNotIn('.config/hypr/sakoora.hyprlock/', config)
                panels = (destination / f'style-{style}/scripts/panels').read_text()
                self.assertIn('hyprlock-cache/auto_DP_1/', panels)
                sizes = (destination / 'style-1/sizes-hyprlock.sh').read_text()
                self.assertIn('capture_size=2560x1440', sizes)

    def test_runtime_combines_outputs_and_runs_named_panels(self):
        source = Path(__file__).resolve().parent.parent
        run = layout.subprocess.run
        captured = []
        def fake_run(args, **kwargs):
            if args[1].endswith('/scripts/panels'):
                captured.append(kwargs['env']['SAKOORA_MONITOR'])
                return
            return run(args, **kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            settings = home / 'settings.json'
            settings.write_text(json.dumps({'autoDetect': True, 'monitors': []}))
            with patch.object(layout.Path, 'home', return_value=home), \
                 patch.object(layout.sys, 'argv', ['layout', str(source), str(settings), '1']), \
                 patch.object(layout.subprocess, 'check_output', return_value=json.dumps(self.outputs)), \
                 patch.object(layout.subprocess, 'run', side_effect=fake_run):
                layout.main()
            config = (home / '.cache/sakoora-layout/current_style.conf').read_text()
            self.assertEqual(config.count('animations {'), 1)
            self.assertIn('monitor = DP-1', config)
            self.assertIn('monitor = eDP-1', config)
            self.assertCountEqual(captured, ['DP-1', 'eDP-1'])


if __name__ == '__main__':
    unittest.main()

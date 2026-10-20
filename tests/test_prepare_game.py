"""Tests without game files or third-party SDKs."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('prepare_game', Path(__file__).resolve().parents[1] / 'tools' / 'prepare_game.py')
pg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pg)


class TestGameImporter(unittest.TestCase):
    def test_only_needed_files_are_imported(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'game.zip'
            with zipfile.ZipFile(source, 'w') as f:
                prefix = 'The Game/'
                for n in ['0.txt', 'arc.nsa', 'default.ttf', 'img/boxart.png', 'img/title.jpg', 'game.exe', 'SDL.dll', 'envdata']:
                    f.writestr(prefix + n, n.encode())
            dest = root / 'game'
            self.assertEqual(pg.import_zip(source, dest, False), 5)
            for n in ('0.txt', 'arc.nsa', 'default.ttf', 'img/boxart.png', 'img/title.jpg'):
                self.assertTrue((dest / n).is_file(), n)
            for n in ('game.exe', 'SDL.dll', 'envdata'):
                self.assertFalse((dest / n).exists(), n)
            with self.assertRaises(FileExistsError):
                pg.import_zip(source, dest, False)
            self.assertEqual(pg.import_zip(source, dest, True), 5)

    def test_invalid_archive_structure(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'broken.zip'
            with zipfile.ZipFile(source, 'w') as f:
                f.writestr('0.txt', b'data')
            with self.assertRaises(ValueError):
                pg.import_zip(source, root / 'game', False)


if __name__ == '__main__':
    unittest.main()

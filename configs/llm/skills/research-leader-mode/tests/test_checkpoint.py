import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "show_board", Path(__file__).resolve().parents[1] / "scripts/show-board.py")
board = importlib.util.module_from_spec(spec)
spec.loader.exec_module(board)


class CheckpointTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name).resolve()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.other = self.repo / "other.txt"
        self.other.write_text("committed\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Initial project")
        self.note = self.repo / "research notes" / "可学习性's.md"
        self.note.parent.mkdir()
        self.note.write_text("# Before\n")

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.repo)] + list(args), universal_newlines=True).strip()

    def test_snapshot_preserves_project_head_index_and_other_files(self):
        self.other.write_text("staged work\n")
        self.git("add", "other.txt")
        self.other.write_text("unstaged work\n")
        head = self.git("rev-parse", "HEAD")
        index = (self.repo / ".git/index").read_bytes()
        commit = board.checkpoint(self.note)
        relative = str(self.note.relative_to(self.repo))
        self.assertEqual(self.git("show", commit + ":" + relative), "# Before")
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual((self.repo / ".git/index").read_bytes(), index)
        self.assertEqual(self.other.read_text(), "unstaged work\n")
        self.assertEqual(board.checkpoint(self.note), commit)

        self.note.write_text("# After\n")
        self.git("add", "--", relative)
        self.assertEqual(board.baseline(self.note), commit)
        self.assertIn("+# After", self.git("diff", commit, "--", relative))
        next_commit = board.checkpoint(self.note)
        self.assertEqual(self.git("rev-parse", next_commit + "^"), commit)
        self.assertEqual(self.git("diff", next_commit, "--", relative), "")

    def test_topics_have_independent_baselines(self):
        second = self.note.parent / "transfer.md"
        second.write_text("# Transfer\n")
        first_commit = board.checkpoint(self.note)
        second_commit = board.checkpoint(second)
        self.note.write_text("# Learnability update\n")
        board.checkpoint(self.note)
        self.assertNotEqual(board.baseline(self.note), first_commit)
        self.assertEqual(board.baseline(second), second_commit)

    def test_empty_new_note_can_be_checkpointed(self):
        self.note.write_text("")
        commit = board.checkpoint(self.note)
        self.assertEqual(self.git("show", commit + ":" + str(self.note.relative_to(self.repo))), "")


if __name__ == "__main__":
    unittest.main()

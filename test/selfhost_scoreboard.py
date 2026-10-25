"""Keep coverage reports useful when a compiler, expectation or bootstrap fails."""

import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import run_tests as rt

tc = rt.tc


class Scoreboard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.here = self.root / "test"
        self.directory = self.root / "build/gen/baseline/selfhost/scoreboard"
        self.baselines = self.root / "selfhost/scoreboard"
        self.baselines.mkdir(parents=True)
        self.fixture = self.here / "codegen/example.goose"
        self.fixture.parent.mkdir(parents=True)
        self.fixture.write_text("main() {}\n")
        self.expected = self.here / "expected"
        self.expected.mkdir()
        (self.expected / "example.out").write_text("ok\n")
        self.addCleanup(patch.stopall)
        patch.object(tc, "REPO_ROOT", self.root).start()
        patch.object(rt, "HERE", self.here).start()
        self.runner = rt.Runner("goose", 1)
        self.runner.profile = "baseline"
        self.cc = Mock()
        self.cc.compile.return_value = (True, "")

    def score(self, emission=(0, "", ""), program=(0, "ok\n", "")):
        with patch.object(tc, "run_capture", side_effect=[emission, program]) as run:
            result = self.runner.score_fixture("stage2", self.fixture, self.cc, self.directory)
        return result, run

    def test_runtime_defines_and_build_options(self):
        self.fixture.write_text("// runtime-define: GS_DEBUG=1\nmain() {}\n")
        self.runner.profile = "sanitize"
        (status, _), run = self.score()
        self.assertEqual(status, "pass")
        self.assertEqual(run.call_args_list[0].args[0][-1], "test/codegen/example.goose")
        args, kwargs = self.cc.compile.call_args
        self.assertEqual(args[0], self.directory / "codegen/example/out.c")
        self.assertEqual(kwargs["opt"], 1)
        self.assertEqual(kwargs["defines"], ["GS_DEBUG=1"])
        self.assertTrue(kwargs["strict_decls"])
        self.assertGreater(kwargs["timeout"], 0)

    def test_runtime_define_failure_prefix(self):
        self.fixture.write_text("// runtime-define: GS_DEBUG=1\nmain() {}\n")
        (self.baselines / "run.txt").write_text("")
        with patch.object(self.runner, "score_fixture", return_value=("mismatch", "why")):
            with self.runner.into(rt.Out()):
                self.runner.score_runs(lambda: "stage2", [self.fixture], self.cc, ())
        self.assertIn("runtime-define GS_DEBUG=1: why", (self.directory / "run.tsv").read_text())

    def test_emitted_c_builds_and_runs_from_any_working_directory(self):
        cc = tc.test_cc()
        if cc is None:
            self.skipTest("no native C compiler")
        capture = tc.run_capture

        def emit_or_run(argv, **kwargs):
            if "stage2" in argv:
                Path(argv[argv.index("-o") + 1]).write_text(
                    '#include <stdio.h>\nint main(void) { puts("ok"); return 0; }\n')
                return 0, "", ""
            return capture(argv, **kwargs)

        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        original_cwd = Path.cwd()
        try:
            with patch.object(tc, "run_capture", side_effect=emit_or_run):
                for cwd in (self.root, self.here, elsewhere):
                    with self.subTest(cwd=cwd):
                        os.chdir(cwd)
                        result = self.runner.score_fixture("stage2", self.fixture, cc, self.directory)
                        self.assertEqual(result, ("pass", ""))
        finally:
            os.chdir(original_cwd)

    def test_native_and_sidecar_fixtures_are_unsupported_before_emission(self):
        for source, sidecar in (("import gfx;\n", False), ("main() {}\n", True)):
            with self.subTest(source=source):
                self.fixture.write_text(source)
                if sidecar:
                    self.fixture.with_suffix(".build").touch()
                (status, _), run = self.score()
                self.assertEqual(status, "unsupported")
                run.assert_not_called()
        package = self.here / "packages/pkg_float_abi.goose"
        package.parent.mkdir()
        package.write_text("main() {}\n")
        status, _ = self.runner.score_fixture("stage2", package, self.cc, self.directory)
        self.assertEqual(status, "unsupported")

    def test_mismatch_keeps_reason_and_stderr(self):
        (status, detail), _ = self.score(program=(0, "wrong", "program diagnostic\nmore"))
        self.assertEqual(status, "mismatch")
        self.assertEqual(detail, "expected-output example.goose: program diagnostic")

    def test_mismatch_without_stderr_has_no_separator(self):
        (status, detail), _ = self.score(program=(0, "wrong", ""))
        self.assertEqual((status, detail), ("mismatch", "expected-output example.goose"))

    def test_runtime_failure_in_selfhost_is_a_crash(self):
        (status, detail), _ = self.score(emission=(1, "", "goose runtime error: index out of bounds\n"))
        self.assertEqual(status, "crash")
        self.assertEqual(detail, "goose runtime error: index out of bounds")

    def test_expected_abort_still_passes(self):
        (self.expected / "example.aborts").touch()
        (self.expected / "example.stderr").write_text("expected abort\n")
        (status, _), _ = self.score(program=(-6, "ok\n", "expected abort\n"))
        self.assertEqual(status, "pass")

    def test_cc_error_uses_first_error_after_warnings(self):
        self.cc.compile.return_value = (False, 'warning: first\nbuild/out.c:2: error: "bad"\n')
        (status, detail), _ = self.score()
        self.assertEqual((status, detail), ("cc-error", 'build/out.c:2: error: "bad"'))

    def test_cc_error_shortens_only_diagnostic_paths_with_posix_separators(self):
        cfile = self.directory / "codegen/example/out.c"
        self.cc.compile.return_value = (False, f"{cfile}:2: error: bad\n")
        (status, detail), _ = self.score()
        self.assertEqual(status, "cc-error")
        self.assertEqual(detail, f"{cfile.relative_to(self.root).as_posix()}:2: error: bad")

    def test_cc_timeout_reports_phase(self):
        self.cc.compile.side_effect = subprocess.TimeoutExpired("cc", 30, stderr=b"compiling\n")
        (status, detail), _ = self.score()
        self.assertEqual((status, detail), ("timeout", "cc: 30s fixture timeout"))
        self.assertEqual((self.directory / "codegen/example/cc.log").read_text(), "compiling\n")

    def test_plain_tsv_blank_baseline_lines_and_add_only_bless_per_board(self):
        baseline = self.baselines / "run.txt"
        baseline.write_text("example.goose\n\n")
        out = rt.Out()
        with self.runner.into(out):
            self.runner.scoreboard("run", {"example.goose": ("codegen", "pass", "")})
        self.assertEqual(out.failures, 0)
        results = {"example.goose": ("codegen", "mismatch", 'reason: "bad"\tvalue\nmore'),
                   "new.goose": ("codegen", "pass", "")}
        out = rt.Out()
        with self.runner.into(out):
            self.runner.scoreboard("run", results, bless=True)
        self.assertEqual(out.failures, 2)
        self.assertIn("refusing --bless-selfhost for run", "".join(out.text))
        self.assertEqual(baseline.read_text(), "example.goose\n\n")
        self.assertIn('example.goose\tcodegen\tmismatch\treason: "bad" value\n',
                      (self.directory / "run.tsv").read_text())
        with self.runner.into(rt.Out()):
            self.runner.scoreboard("check", {"stdlib/x.goose": ("stdlib", "pass", "")},
                                   bless=True)
        self.assertEqual((self.baselines / "check.txt").read_text(), "stdlib/x.goose\n")
        self.assertTrue((self.directory / "check.tsv").exists())
        self.assertEqual(baseline.read_text(), "example.goose\n\n")

    def test_failed_bootstrap_preserves_previous_report(self):
        self.directory.mkdir(parents=True)
        report = self.directory / "run.tsv"
        report.write_text("previous report\n")
        with patch.object(self.runner, "score_fixture") as score:
            out = rt.Out()
            with self.runner.into(out):
                self.runner.score_runs(lambda: None, [self.fixture], self.cc, (), True)
        score.assert_not_called()
        self.assertEqual(out.failures, 2)
        self.assertIn("stage-2 bootstrap", "".join(out.text))
        self.assertEqual(report.read_text(), "previous report\n")

    def test_summary_counts_each_boards_own_statuses_in_stable_order(self):
        out = rt.Out()
        results = {"x.goose": ("stdlib", "unchecked", ""),
                   "y.goose": ("stdlib", "checked", "")}
        (self.baselines / "check.txt").touch()
        with self.runner.into(out):
            self.runner.scoreboard("check", results)
        self.assertIn("selfhost check scoreboard: 1 checked, 1 unchecked\n", out.text)


class ToolTimeouts(unittest.TestCase):
    def test_children_read_eof_from_stdin(self):
        code, out, err = tc.run_capture([sys.executable, "-c",
                                         "import sys; print(repr(sys.stdin.read()))"], timeout=2)
        self.assertEqual((code, out, err), (0, "''\n", ""))

    def test_compile_forwards_timeout_and_native_define_spelling(self):
        for style, flag in (("gcc", "-DGS_DEBUG=1"), ("msvc", "/DGS_DEBUG=1")):
            with self.subTest(style=style), patch.object(tc, "run_capture", return_value=(0, "", "")) as run:
                cc = tc.CC("clang", "cc", "c++", style, "test compiler")
                self.assertEqual(cc.compile("in.c", "out", defines=["GS_DEBUG=1"], timeout=2), (True, ""))
                self.assertIn(flag, run.call_args.args[0])
                self.assertEqual(run.call_args.kwargs["timeout"], 2)

    def test_timeout_kills_children_holding_output_open(self):
        start = time.monotonic()
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            tc.run_capture([sys.executable, "-c",
                            "import subprocess, sys, time; "
                            "subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(10)']); "
                            "print('ready', flush=True); time.sleep(10)"], timeout=0.5)
        self.assertIn(b"ready", caught.exception.output)
        self.assertLess(time.monotonic() - start, 5)

    @unittest.skipIf(tc.IS_WINDOWS, "POSIX process groups")
    def test_process_exiting_at_deadline_keeps_timeout_status(self):
        process = Mock()
        process.communicate.side_effect = [subprocess.TimeoutExpired("cc", 1), (b"", b"")]
        with patch.object(tc.subprocess, "Popen") as popen, \
                patch.object(tc.os, "killpg", side_effect=ProcessLookupError):
            popen.return_value = process
            with self.assertRaises(subprocess.TimeoutExpired):
                tc.run_capture(["cc"], timeout=1)
        self.assertEqual(popen.call_args.kwargs["stdin"], subprocess.DEVNULL)

    def test_windows_timeout_kills_tree_and_bounds_pipe_cleanup(self):
        for kill_error in (None, OSError("taskkill unavailable"), subprocess.TimeoutExpired("taskkill", 5)):
            for drain_timeout in (False, True):
                with self.subTest(kill_error=kill_error, drain_timeout=drain_timeout):
                    process = Mock(pid=123)
                    final = subprocess.TimeoutExpired("cc", 5, output=b"partial", stderr=b"error") \
                        if drain_timeout else (b"partial", b"error")
                    process.communicate.side_effect = [subprocess.TimeoutExpired("cc", 1), final]
                    with patch.object(tc, "IS_WINDOWS", True), \
                            patch.object(tc.subprocess, "Popen", return_value=process), \
                            patch.object(tc.subprocess, "run", side_effect=kill_error) as kill:
                        with self.assertRaises(subprocess.TimeoutExpired) as caught:
                            tc.run_capture(["cc"], timeout=1)
                    self.assertEqual(kill.call_args.args[0], ["taskkill", "/T", "/F", "/PID", "123"])
                    self.assertEqual(kill.call_args.kwargs["timeout"], 5)
                    process.kill.assert_called_once_with()
                    self.assertEqual(process.communicate.call_args.kwargs["timeout"], 5)
                    self.assertEqual(caught.exception.timeout, 1)
                    self.assertEqual(caught.exception.output, b"partial")
                    self.assertEqual(caught.exception.stderr, b"error")
                    if drain_timeout:
                        process.stdout.close.assert_not_called()
                        process.stderr.close.assert_not_called()


if __name__ == "__main__":
    unittest.main()

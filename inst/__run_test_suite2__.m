## Copyright (C) 2005-2019 David Bateman
## Copyright (C) 2019 Andrew Janke
##
## This file is part of Octave.
##
## Octave is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## Octave is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, see
## <https://www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn  {} {} __run_test_suite2__ (@var{fcndirs}, @var{fixedtestdirs})
## @deftypefnx {} {} __run_test_suite2__ (@var{fcndirs}, @var{fixedtestdirs}, @var{topsrcdir}, @var{topbuilddir})
## Undocumented internal function.
## @end deftypefn

## varargout signature:
## rslts = __run_test_suite2__ (...)
## [pass, fail, xfail, xbug, skip, rtskip, regress, failed_files] = __run_test_suite2__ (...)
function varargout = __run_test_suite2__ (fcndirs, fixedtestdirs, topsrcdir = [], topbuilddir = [])

  # Run tests, saving results to log

  log_file = pick_log_file;

  orig_page_screen_output = page_screen_output ();
  orig_wstate = warning ();
  unwind_protect
    page_screen_output (false);
    warning ("on", "quiet");
    warning ("off", "Octave:deprecated-function");
    warning ("off", "Octave:legacy-function");
    rslts = testify.internal.BistRunResult;
    fid = fopen2 (log_file, "wt");
    unwind_protect
      test2_refactor ("", "explain", "-log-fid", fid);

      ## TODO: This fid arg doesn't work. Fix it.
      runner = testify.internal.MultiBistRunner (fid);
      runner.add_octave_builtins;
      runner.add_octave_standard_library;
      runner.add_octave_site_m_files;

      rslts = runner.run_tests;

      reporter = testify.internal.BistResultsReporter;
      reporter.print_results_summary (rslts);
    unwind_protect_cleanup
      printf ("\n");
      printf ("Log file: %s\n", log_file);
      fclose (fid);
    end_unwind_protect
  unwind_protect_cleanup
    warning ("off", "all");
    warning (orig_wstate);
    page_screen_output (orig_page_screen_output);
  end_unwind_protect

  if nargout > 0
    varargout = { rslts };
  endif

endfunction

function out = pick_log_file ()
  log_dir = fullfile (testify.internal.Util.testify_data_dir, ...
    "logs", "test-suite");
  mkdir (log_dir);
  log_base = sprintf ("testsuite-%s-%s-%s.log", ...
    testify.internal.Util.safe_hostname, ...
    testify.internal.Util.os_name,
    datestr (now, "yyyymmdd_HHMMSS"));
  log_file = fullfile (log_dir, log_base);
  log_file = make_absolute_filename (log_file);
  out = log_file;
endfunction

## No test coverage for internal function.  It is tested through calling fcn.
%!assert (1)

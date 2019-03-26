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

  [top_log_file, detail_log_file, log_location] = pick_log_files;
  fprintf ("Logging to: %s\n", log_location);
  print_log_header (top_log_file);

  t0 = tic;

  orig_page_screen_output = page_screen_output ();
  orig_wstate = warning ();
  unwind_protect
    page_screen_output (false);
    warning ("on", "quiet");
    warning ("off", "Octave:deprecated-function");
    warning ("off", "Octave:legacy-function");
    rslts = testify.internal.BistRunResult;
    diary (top_log_file)
    diary on
    log_fid = fopen2 (detail_log_file, "wt");
    dummy_runner = testify.internal.BistRunner;
    dummy_runner.print_results_format_key (log_fid);
    unwind_protect
      runner = testify.internal.MultiBistRunner (log_fid);
      runner.add_octave_builtins;
      runner.add_octave_standard_library;
      runner.add_octave_site_m_files;

      rslts = runner.run_tests;

      reporter = testify.internal.BistResultsReporter;
      reporter.print_results_summary (rslts);
    unwind_protect_cleanup
      printf ("\n");
      printf ("Log location: %s\n", log_location);
      fclose (log_fid);
    end_unwind_protect
  unwind_protect_cleanup
    warning ("off", "all");
    warning (orig_wstate);
    page_screen_output (orig_page_screen_output);
    diary off
  end_unwind_protect

  if nargout > 0
    varargout = { rslts };
  endif

endfunction

function print_log_header (log_file)
  host = testify.internal.Util.safe_hostname;
  fid = fopen2 (log_file, "w");
  fprintf (fid, "Tests run on %s at %s\n", host, datestr (now));
  fprintf (fid, "\n");
  testify.internal.LogHelper.display_system_info (fid);
  fclose (fid);
endfunction

function [top_log_file, detail_log_file, log_location] = pick_log_files ()
  log_dir = fullfile (testify.internal.Config.testify_data_dir, ...
    "logs", "test-suite");
  mkdir (log_dir);
  log_run_dir_base = sprintf ("testsuite-%s-%s-%s", ...
    testify.internal.Util.safe_hostname, ...
    testify.internal.Util.os_name,
    datestr (now, "yyyymmdd_HHMMSS"));
  log_run_dir = fullfile (log_dir, log_run_dir_base);
  mkdir (log_run_dir);
  log_location = log_run_dir;
  top_log_file = fullfile (log_run_dir, "results.log");
  top_log_file = make_absolute_filename (top_log_file);
  detail_log_file = fullfile (log_run_dir, "details.log");
  detail_log_file = make_absolute_filename (detail_log_file);
endfunction

## No test coverage for internal function.  It is tested through calling fcn.
%!assert (1)

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

  t0 = tic;
  testsdir = __octave_config_info__ ("octtestsdir");
  libinterptestdir = fullfile (testsdir, "libinterp");
  liboctavetestdir = fullfile (testsdir, "liboctave");
  fcnfiledir = __octave_config_info__ ("fcnfiledir");
  if (nargin < 1)
    fcndirs = { liboctavetestdir, libinterptestdir, fcnfiledir };
  else
    fcndirs = cellstr (fcndirs);
  endif
  fixedtestdir = fullfile (testsdir, "fixed");
  if (nargin < 2)
    fixedtestdirs = { fixedtestdir };
  else
    fixedtestdirs = cellstr (fixedtestdirs);
  endif
  ## FIXME: These names don't really make sense if we are running
  ##        tests for an installed copy of Octave.
  if (isempty (topsrcdir))
    topsrcdir = fcnfiledir;
  endif
  if (isempty (topbuilddir))
    topbuilddir = testsdir;
  endif

  pso = page_screen_output ();
  orig_wstate = warning ();
  logfile = make_absolute_filename ("fntests.log");
  unwind_protect
    page_screen_output (false);
    warning ("on", "quiet");
    warning ("off", "Octave:deprecated-function");
    warning ("off", "Octave:legacy-function");
    rslts = testify.internal.BistRunResult;
    fid = fopen2 (logfile, "wt");
    unwind_protect
      test2_refactor ("", "explain", "-log-fid", fid);

      runner = testify.internal.MultiBistRunner (fid);
      runner.add_octave_builtins;
      runner.add_octave_standard_library;
      runner.add_octave_site_m_files;

      rslts = runner.run_tests;

      reporter = testify.internal.BistResultsReporter;
      reporter.print_results_summary (rslts);
    unwind_protect_cleanup
      fclose (fid);
    end_unwind_protect
  unwind_protect_cleanup
    warning ("off", "all");
    warning (orig_wstate);
    page_screen_output (pso);
  end_unwind_protect

  if nargout > 0
    varargout = { rslts };
  endif

endfunction


## No test coverage for internal function.  It is tested through calling fcn.
%!assert (1)

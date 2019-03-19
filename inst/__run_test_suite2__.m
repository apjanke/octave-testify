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
    try
      fid = fopen (logfile, "wt");
      if (fid < 0)
        error ("__run_test_suite2__: could not open %s for writing", logfile);
      endif
      test ("", "explain", fid);
      puts ("\nIntegrated test scripts:\n\n");
      for i = 1:length (fcndirs)
        rslt = run_test_dir (fid, fcndirs{i}, false, topbuilddir, topsrcdir);
        rslts = rslts + rslt;
      endfor
      puts ("\nFixed test scripts:\n\n");
      for i = 1:length (fixedtestdirs)
        rslt = run_test_dir (fid, fixedtestdirs{i}, true, topbuilddir, topsrcdir);
        rslts = rslts + rslt;
      endfor

      t_elapsed = toc (t0);
      puts ("\nSummary:\n\n");
      hg_id = __octave_config_info__ ("hg_id");
      printf ("  GNU Octave Version: %s (hg id: %s)\n", OCTAVE_VERSION, hg_id);
      printf ("  Execution time: %.0f s\n", t_elapsed);
      printf ("\n");
      printf ("  %-30s %6d\n", "PASS", rslts.n_pass);
      printf ("  %-30s %6d\n", "FAIL", rslts.n_really_fail);
      if (rslts.n_regression > 0)
        printf ("  %-30s %6d\n", "REGRESSION", rslts.n_regression);
      endif
      if (rslts.n_xfail_bug > 0)
        printf ("  %-30s %6d\n", "XFAIL (reported bug)", rslts.n_xfail_bug);
      endif
      if (rslts.n_xfail > 0)
        printf ("  %-30s %6d\n", "XFAIL (expected failure)", rslts.n_xfail);
      endif
      if (rslts.n_skip_feature > 0)
        printf ("  %-30s %6d\n", "SKIP (missing feature)", rslts.n_skip_feature);
      endif
      if (rslts.n_skip_runtime > 0)
        printf ("  %-30s %6d\n", "SKIP (run-time condition)", rslts.n_skip_runtime);
      endif
      if ! isempty (rslts.failed_files)
        printf ("\n");
        printf ("  Failed tests:\n");
        for i = 1:numel (rslts.failed_files)
          printf ("     %s\n", reduce_test_file_name (rslts.failed_files{i}, ...
            topbuilddir, topsrcdir));
        endfor
      endif
      puts ("\n");
      printf ("See the file %s for additional details.\n", logfile);
      if (rslts.n_xfail > 0 || rslts.n_xfail_bug > 0)
        puts ("\n");
        puts ("XFAIL items are known bugs or expected failures.\n");
        puts ("Bug report numbers may be found in the log file:\n");
        puts (logfile);
        puts ("\nPlease help improve Octave by contributing fixes for them.\n");
      endif
      if (rslts.n_skip_feature > 0 || rslts.n_skip_runtime > 0)
        puts ("\n");
        puts ("Tests are often skipped because required features were\n");
        puts ("disabled or were not present when Octave was built.\n");
        puts ("The configure script should have printed a summary\n");
        puts ("indicating which dependencies were not found.\n");
      endif

      ## Weed out deprecated, legacy, and private functions
      files_with_tests = rslts.files_with_tests;
      weed_idx = cellfun (@isempty, regexp (files_with_tests, '\<deprecated\>|\<legacy\>|\<private\>', 'once'));
      files_with_tests = files_with_tests(weed_idx);
      files_with_no_tests = rslts.files_with_no_tests;
      weed_idx = cellfun (@isempty, regexp (files_with_no_tests, '\<deprecated\>|\<legacy\>|\<private\>', 'once'));
      files_with_no_tests = files_with_no_tests(weed_idx);

      report_files_with_no_tests (files_with_tests, files_with_no_tests, ".m");

      puts ("\nPlease help improve Octave by contributing tests for these files\n");
      printf ("(see the list in the file %s).\n\n", logfile);

      fprintf (fid, "\nFiles with no tests:\n\n%s",
                    list_in_columns (files_with_no_tests, 80));
      fclose (fid);
    catch err
      disp (lasterr ());
    end_try_catch
  unwind_protect_cleanup
    warning ("off", "all");
    warning (orig_wstate);
    page_screen_output (pso);
  end_unwind_protect

  if nargout == 1
    varargout = { rslts };
  elseif nargout > 1
    varargout = {
      rslts.n_pass;
      rslts.n_fail;
      rslts.n_xfail;
      rslts.n_xfail_bug;
      rslts.n_skip_feature;
      rslts.n_skip_runtime;
      rslts.n_regression;
      rslts.failed_files;
    };
  endif

endfunction

function rslts = run_test_dir (fid, d, is_fixed, topbuilddir, topsrcdir)

  lst = dir (d);
  rslts = testify.internal.BistRunResult;
  for i = 1:length (lst)
    nm = lst(i).name;
    if (lst(i).isdir && nm(1) != "." && ! strcmp (nm, "private"))
      rslt = run_test_dir (fid, [d, filesep, nm], is_fixed, topbuilddir, topsrcdir);
      rslts = rslts + rslt;
    endif
  endfor

  saved_dir = pwd ();
  unwind_protect
    [dnm, fnm] = fileparts (d);
    if (fnm(1) != "@")
      cd (d);
    endif
    for i = 1:length (lst)
      nm = lst(i).name;
      ## Ignore hidden files
      if (nm(1) == '.')
        continue
      endif
      if ((! is_fixed && length (nm) > 2 && strcmpi (nm((end-1):end), ".m"))
          || (! is_fixed && length (nm) > 4 && strcmpi (nm((end-3):end), "-tst"))
          || (is_fixed && length (nm) > 4 && strcmpi (nm((end-3):end), ".tst")))
        p = n = xf = xb = sk = rtsk = rgrs = 0;
        ffnm = fullfile (d, nm);
        rslt.files_processed{end+1} = ffnm;
        ## Only run if contains %!test, %!assert, %!error, %!fail, or %!warning
        if (has_tests (ffnm))
          tmp = reduce_test_file_name (ffnm, topbuilddir, topsrcdir);
          print_test_file_name (tmp);
          rslt = my_test (ffnm, "quiet", fid);
          rslt.files_with_tests{end+1} = ffnm;
          print_pass_fail (rslt);
          rslts = rslts + rslt;
        endif
      endif
    endfor
  unwind_protect_cleanup
    cd (saved_dir);
  end_unwind_protect

endfunction


function rslt = my_test (file, options, fid)
  [~,rslt] = test (file, options, fid);
  if rslt.n_fail < 0 || rslt.n_really_fail < 0
    keyboard
  endif
  if rslt.n_really_fail > 0
    rslt.failed_files{end+1} = file;
  endif
  if rslt.n_test > 0
    rslt.files_with_tests{end+1} = file;
  endif
endfunction

function print_test_file_name (nm)
  nmlen = numel (nm);
  filler = repmat (".", 1, 63-nmlen);
  if (nmlen > 63)
    nm = ["..", nm(nmlen-60:end)];
  endif
  printf ("  %s %s", nm, filler);
endfunction

function print_pass_fail (x)

  if ((x.n_fail + x.n_skip_feature + x.n_skip_runtime + x.n_regression) > 0)
    printf (" PASS %4d/%-4d", x.n_pass, x.n_test);
    if (x.n_really_fail  > 0)
      printf ("\n%72s %3d", "FAIL ", x.n_really_fail);
    endif
    if (x.n_regression > 0)
      printf ("\n%72s %3d", "REGRESSION", x.n_regression);
    endif
    if (x.n_skip_feature > 0)
      printf ("\n%72s %3d", "(missing feature) SKIP ", x.n_skip_feature);
    endif
    if (x.n_skip_runtime > 0)
      printf ("\n%72s %3d", "(run-time condition) SKIP ", x.n_skip_runtime);
    endif
    if (x.n_xfail_bug > 0)
      printf ("\n%72s %3d", "(reported bug) XFAIL", x.n_xfail_bug);
    endif
    if (x.n_xfail > 0)
      printf ("\n%72s %3d", "(expected failure) XFAIL", x.n_xfail);
    endif
  endif
  puts ("\n");

endfunction

function retval = reduce_test_file_name (nm, builddir, srcdir)

  ## Reduce the given absolute file name to a relative path by removing one
  ## of the likely root directory prefixes.

  prefix = { builddir, fullfile(builddir, "scripts"), ...
             srcdir, fullfile(srcdir, "scripts"), ...
             srcdir, fullfile(srcdir, "test") };

  retval = nm;

  for i = 1:numel (prefix)
    tmp = strrep (nm, [prefix{i}, filesep], "");
    if (length (tmp) < length (retval))
      retval = tmp;
    endif
  endfor

endfunction

function retval = has_functions (f)

  n = length (f);
  if (n > 3 && strcmpi (f((end-2):end), ".cc"))
    fid = fopen (f);
    if (fid < 0)
      error ("__run_test_suite2__: fopen failed: %s", f);
    endif
    str = fread (fid, "*char")';
    fclose (fid);
    retval = ! isempty (regexp (str,'^(DEFUN|DEFUN_DLD)\>',
                                    'lineanchors', 'once'));
  elseif (n > 2 && strcmpi (f((end-1):end), ".m"))
    retval = true;
  else
    retval = false;
  endif

endfunction

function retval = has_tests (f)

  fid = fopen (f);
  if (fid < 0)
    error ("__run_test_suite2__: fopen failed: %s", f);
  endif

  str = fread (fid, "*char")';
  fclose (fid);
  retval = ! isempty (regexp (str,
                              '^%!(assert|error|fail|test|xtest|warning)',
                              'lineanchors', 'once'));

endfunction

function n = num_elts_matching_pattern (lst, pat)
  n = sum (! cellfun ("isempty", regexp (lst, pat, 'once')));
endfunction

function report_files_with_no_tests (with, without, typ)
  pat = ['\' typ "$"];
  n_with = num_elts_matching_pattern (with, pat);
  n_without = num_elts_matching_pattern (without, pat);
  n_tot = n_with + n_without;
  printf ("\n%d (of %d) %s files have no tests.\n", n_without, n_tot, typ);
endfunction


## No test coverage for internal function.  It is tested through calling fcn.
%!assert (1)

## Copyright (C) 2010-2019 John W. Eaton
## Copyright (C) 2019 Andrew Janke
## Copyright (C) 2019 Colin B. Macdonald
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

## Work-in-progress refactoring of runtests2 to use testify.internal 
## objects

## -*- texinfo -*-
## @deftypefn  {} {} runtests2 ()
## @deftypefnx {} {} runtests2 (@var{target})
## @deftypefnx {} {} runtests2 (@var{-<option>}, @var{arg}, @dots{})
## @deftypefnx {} {@var{success} =} runtests2 (@dots{})
## @deftypefnx {} {[@var{success}, @var{__info__}] =} runtests2 (@dots{})
## Execute built-in tests for all m-files in the specified @var{directory}.
##
## Test blocks in any C++ source files (@file{*.cc}) will also be executed
## for use with dynamically linked oct-file functions.
##
## @var{target} may be a file, directory, class, or function name. If @var{target}
## starts with a "@", it is always interpreted as a class. Directories may be
## either regular paths, or a directory that is on the Octave load path.
##
## Options:
##
##   -file <name>
##   -dir <name>
##   -class <name>        - Test a class
##   -function <name>     - Test a function
##   -pkg <name>          - Test an installed pkg package
##   -search-path         - Test everything on the Octave search path
##   -octave-builtins     - Test Octave's interpreter and built-in functions
##
## If no target is specified, operates on all directories in Octave's search
## path. (The same as -search-path.)
##
## When called with a single return value (@var{success}), return false if
## there were any unexpected test failures, otherwise return true.  An extra
## output argument returns detailed results of the test run.  The format of
## this object is undocumented and subject to change at any time; it is
## currently intended for Octave's internal use only.
##
## @seealso{rundemos, test, path}
## @end deftypefn

## Author: jwe

function [p, __info__] = runtests2_refactor (varargin)

  # Parse inputs and find tests
  opts = parse_inputs (varargin);

  # Find tests

  runner = testify.internal.MultiBistRunner;
  targets = opts.targets;
  if isempty (targets)
    targets = struct ("type", "search_path", "item", []);
  endif    
  for i = 1:numel (targets)
    t = targets(i);
    switch t.type
      case "auto"
        runner.add_target_auto (t.item);
      case "file"
        runner.add_file (t.item);
      case "dir"
        runner.add_directory (t.item);
      case "search_path"
        runner.add_stuff_on_octave_search_path;
      case "function"
        runner.add_function (t.item);
      case "class"
        runner.add_class (t.item);
      case "pkg"
        runner.add_package (t.item);
      case "installed_pkgs"
        runner.add_installed_packages;
      case "octave_builtins"
        runner.add_octave_builtins;
      otherwise
        error ("Unsupported target type: %s", t.type);
    endswitch
  endfor

  # Run tests

  t0 = tic;
  rslts = runner.run_tests;
  te = toc (t0);

  print_results_summary (rslts, te);

  if nargout >= 1
    p = rslts.n_fail == 0;
  endif
  if nargout == 2
    __info__ = rslts;
  endif
endfunction

function out = parse_inputs (args)
  out.targets = [];
  i = 1;
  while i <= numel (args)
    arg = args{i};
    switch arg
      case "-auto"
        out.targets = [out.targets target("auto", args{i+1})];
        i += 2;
      case "-file"
        out.targets = [out.targets target("file", args{i+1})];
        i += 2;
      case "-dir"
        out.targets = [out.targets target("dir", args{i+1})];
        i += 2;
      case "-class"
        out.targets = [out.targets target("class", args{i+1})];
        i += 2;
      case "-function"
        out.targets = [out.targets target("function", args{i+1})];
        i += 2;
      case "-pkg"
        out.targets = [out.targets target("pkg", args{i+1})];
        i += 2;
      case "-installed-pkgs"
        out.targets = [out.targets target("installed_pkgs", [])];
        i += 1;
      case "-search-path"
        out.targets = [out.targets target("search_path", [])];
        i += 1;
      case "-octave-builtins"
        out.targets = [out.targets target("octave_builtins", [])];
        i += 1;
      case ""
        error ("runtests2: empty string is not a valid argument");
      otherwise
        if ischar (arg)
          if arg(1) == "-"
            error ("runtests2: invalid option: %s", arg);
          endif
          if arg(1) == "@"
            out.targets = [out.targets target("class", arg(2:end))];
          else
            out.targets = [out.targets target("auto", arg)];
          endif
        elseif iscellstr (arg)
          out.targets = [out.targets target("auto", arg)];
        endif
        i += 1;
    endswitch
  endwhile
endfunction

function out = target (type, item)
  if iscellstr (item)
    out = [];
    for i = 1:numel (item)
      out = [out target(type, item{i})];
    endfor
  elseif ischar (item) || isnumeric (item)
    out.type = type;
    out.item = item;
  else
    error ("Invalid item type: %s", class (item));
  endif
endfunction

function print_results_summary (rslts, t_elapsed)
  puts ("\n");
  puts ("Summary:\n");
  puts ("\n");
  hg_id = __octave_config_info__ ("hg_id");
  printf ("  GNU Octave Version: %s (hg id: %s)\n", OCTAVE_VERSION, hg_id);
  host = testify.internal.Util.safe_hostname;
  os_name = testify.internal.Util.os_name;
  printf ("  Tests run on %s (%s) at %s\n", host, os_name, datestr (now));
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
  if (rslts.n_xfail > 0 || rslts.n_xfail_bug > 0)
    puts ("\n");
    puts ("XFAIL items are known bugs or expected failures.\n");
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

endfunction

function out = reduce_test_file_name (nm, builddir, srcdir)
  ## Reduce the given absolute file name to a relative path by removing one
  ## of the likely root directory prefixes.

  prefix = { builddir, fullfile(builddir, "scripts"), ...
             srcdir, fullfile(srcdir, "scripts"), ...
             srcdir, fullfile(srcdir, "test") };

  out = nm;

  for i = 1:numel (prefix)
    tmp = strrep (nm, [prefix{i}, filesep], "");
    if (length (tmp) < length (out))
      out = tmp;
    endif
  endfor
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

function out = chomp (str)
  out = regexprep (str, "\r?\n$", "");
endfunction

%!error runtests2 ("foo", 1)
%!error <DIRECTORY argument> runtests2 ("#_TOTALLY_/_INVALID_/_PATHNAME_#")

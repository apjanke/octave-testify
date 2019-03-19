## Copyright (C) 2010-2018 John W. Eaton
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

## -*- texinfo -*-
## @documentencoding UTF-8
## @deftypefn  {} {} test_pkgs
## @deftypefnx {} {} test_pkgs @var{pkg_name}
## @deftypefnx {} {} test_pkgs (@var{pkg_names}, @var{options})
## @deftypefnx {} {@var{success} =} test_pkgs (@dots{})
## @deftypefnx {} {[@var{nfailed}, @var{__info__}] =} test_pkgs (@dots{})
## Run tests for packages
##
## A single package can be testing by passing @var{pkg_name}.
##
## @var{pkg_names} is a list of packages to test (a cell array of strings).
## If @var{pkg_names} is empty or omitted, then all installed packages are
## tested.
##
## @var{options} (struct, cellstr) is a set of name/value pairs of options.
## Valid options:
##
## @table @asis
##
##    @item @code{all_together}  (boolean, false*)
##        If true, test packages while they are all loaded together in
##        addition to the individual package tests.
##
##    @item @code{n_iters}  (double, 1*)
##        How many times to run each package test.  This is used for
##        exposing intermittent failures.
##
##   @item @code{rand_seed}  (double, 42.0*)
##        Seed to reset rand() generator to for each test.
##
##   @item @code{doctest}  (boolean, false*)
##        Run doctest tests in addition to regular BISTs.
##        Note that if you turn this on, it'll probably spam your logs.
##
## @end table
##
## If one argout is captured, returns a logical indicating whether all tests
## passed.
##
## If two argouts are captured, the first argout is a count of the number
## of failed tests.
##
## If the second argout, @var{__info__}, is specified, it returns an
## object holding detailed results of the test run.  The format of this
## object is undocumented and subject to change at any time; it is currently
## for Octave's internal use only.
##
## @strong{Examples}
##
## Test a single package:
## @example
## @c doctest: +SKIP_IF (isempty (ver ('optim')))
## @group
## test_pkgs optim
##   @print{} Running package tests
##   @print{} ...
##   @print{} Testing package optim ...
##   @print{} ...
##   @print{} All tests passed.
## @end group
## @end example
## @c TODO: is there a package we know is installed for doctesting?
##
## Test all installed packages:
## @c doctest +SKIP
## @example
## test_pkgs
## @end example
##
## Test all packages, including loading all together to check compatibility:
## @c doctest _SKIP
## @example
## test_pkgs ([], @{'all_together', true@})
## @end example
##
## Torture test:
## @c doctest _SKIP
## @example
## test_pkgs ([], @{'all_together', true, 'n_iters', 4@})
## @end example
##
## @seealso{test, runtests}
## @end deftypefn

function nfailed = test_pkgs (pkg_names, options)

  if nargin < 1;  pkg_names = {};  endif
  if nargin < 2;  options = {};    endif

  default_opts = struct (...
    "all_together", false, ...
    "n_iters",      1, ...
    "rand_seed",    42.0, ...
    "doctest",      true);
  opts = testify.internal.Util.parse_options (options, default_opts);

  if opts.doctest
    make_sure_doctest_is_loaded;
  endif

  if (isempty (pkg_names))
    pkg_names = list_installed_packages ();
  endif
  pkg_names = cellstr (pkg_names);
  # Kludge: Don't test Testify etc, because we need it to stay loaded while running
  # the tests.
  my_impl_pkgs = {'testify', 'doctest'}
  pkg_names = setdiff (pkg_names, {'testify', 'doctest'});

  nfailed = 0;

  pkgs_with_failures = {};

  fprintf ("Running package tests\n");
  if floor (opts.rand_seed) == opts.rand_seed
    rand_seed_display = num2str (opts.rand_seed);
  else
    rand_seed_display = sprintf ("%0.16f", opts.rand_seed);
  endif
  fprintf ("Random seed is: %s\n", rand_seed_display);

  ## Test packages individually
  fprintf ("Testing packages individually...\n");
  for i = 1:numel (pkg_names)
    pkg_name = pkg_names{i};
    pkg_info = pkg ("list", pkg_name);
    pkg_info = pkg_info{1};
    fprintf ("\nTesting package %s %s\n", pkg_name, pkg_info.version);
    pkg_dir = pkg_info.dir;
    for i_iter = 1:opts.n_iters
      pkg ("load", pkg_name);
      rand ("seed", opts.rand_seed);
      nf = my_runtests (pkg_dir);
      if (nf > 0)
        pkgs_with_failures{end+1} = pkg_name;
      endif
      nfailed += nf;
      if opts.doctest
        fprintf ("Doctest tests:\n");
        [n_passed, n_tests, summary] = doctest (pkg_dir);
        n_failed = n_tests - n_passed;
        fprintf ("doctest results: n_passed=%d n_tests=%d n_failed=%d\n", ...
          n_passed, n_tests, n_failed);
        nfailed += n_failed;
      endif
      pkg ("unload", pkg_name);
    endfor
  endfor

  ## Test packages when they're all loaded together
  if (opts.all_together)
    fprintf ("\n\n\nLoading all packages together...\n");
    pkg ("load", pkg_names{:});
    for i = 1:numel (pkg_names)
      pkg_name = pkg_names{i};
      pkg_info = pkg ("list", pkg_name);
      pkg_info = pkg_info{1};
      fprintf ("\nTesting package %s %s\n", pkg_name, pkg_info.version);
      pkg_dir = pkg_info.dir;
      for i_iter = 1:opts.n_iters
        rand ("seed", opts.rand_seed);
        nf = my_runtests (pkg_dir);
        if (nf > 0)
          pkgs_with_failures{end+1} = pkg_name;
        endif
        nfailed += nf;
      endfor
    endfor
    pkg ("unload", pkg_names{:});
  endif

  fprintf ("\n");
  if (nfailed > 0)
    pkgs_with_failures = unique (pkgs_with_failures);
    fprintf ("TESTS FAILED!\n");
    fprintf ("%d failures in tests for packages: %s\n", ...
      nfailed, strjoin (pkgs_with_failures, " "));
  else
    fprintf ("All tests passed.\n");
  endif
  fprintf ("\n");

  if (nargout == 0)
    clear nfailed
  elseif (nargout == 1)
    nfailed = nfailed == 0;
  endif
endfunction

function out = list_installed_packages
  p = pkg ('list');
  if (isempty (p))
    out = {};
    return;
  endif
  out = cellfun (@(x) { x.name }, p);
end

## -*- texinfo -*-
## @deftypefn  {} {} runtests ()
## @deftypefnx {} {} runtests (@var{directory})
## Execute built-in tests for all m-files in the specified @var{directory}.
##
## Test blocks in any C++ source files (@file{*.cc}) will also be executed
## for use with dynamically linked oct-file functions.
##
## If no directory is specified, operate on all directories in Octave's search
## path for functions.
## @seealso{rundemos, test, path}
## @end deftypefn

## Author: jwe

function nfailed = my_runtests (directory)

  if (nargin == 0)
    dirs = ostrsplit (path (), pathsep ());
    do_class_dirs = true;
  elseif (nargin == 1)
    dirs = {canonicalize_file_name(directory)};
    if (isempty (dirs{1}) || ! isdir (dirs{1}))
      ## Search for directory name in path
      if (directory(end) == '/' || directory(end) == '\')
        directory(end) = [];
      endif
      fullname = dir_in_loadpath (directory);
      if (isempty (fullname))
        error ("runtests: DIRECTORY argument must be a valid pathname");
      endif
      dirs = {fullname};
    endif
    do_class_dirs = false;
  else
    print_usage ();
  endif

  nfailed = 0;
  for i = 1:numel (dirs)
    d = dirs{i};
    nfailed += run_all_tests (d, do_class_dirs);
  endfor

endfunction

function nfailed_total = run_all_tests (directory, do_class_dirs)

  nfailed_total = 0;
  flist = readdir (directory);
  dirs = {};
  no_tests = {};
  printf ("Processing files in %s:\n\n", directory);
  fflush (stdout);
  for i = 1:numel (flist)
    f = flist{i};
    if ((length (f) > 2 && strcmpi (f((end-1):end), ".m"))
        || (length (f) > 3 && strcmpi (f((end-2):end), ".cc")))
      ff = fullfile (directory, f);
      if (has_tests (ff))
        print_test_file_name (f);
        [p, n, xf, xb, sk, rtsk, rgrs] = test (ff, "quiet");
        nfailed = n - p - xf - xb - rgrs;
        nfailed_total += nfailed;
        print_pass_fail (p, n, xf, xb, sk, rtsk, rgrs);
        fflush (stdout);
      elseif (has_functions (ff))
        no_tests(end+1) = f;
      endif
    elseif (f(1) == "@")
      f = fullfile (directory, f);
      if (isdir (f))
        dirs(end+1) = f;
      endif
    endif
  endfor
  if (! isempty (no_tests))
    printf ("\nThe following files in %s have no tests:\n\n", directory);
    printf ("%s", list_in_columns (no_tests));
  endif

  ## Recurse into class directories since they are implied in the path
  if (do_class_dirs)
    for i = 1:numel (dirs)
      d = dirs{i};
      nfailed_total += run_all_tests (d, false);
    endfor
  endif

endfunction


function retval = has_functions (f)

  n = length (f);
  if (n > 3 && strcmpi (f((end-2):end), ".cc"))
    fid = fopen (f);
    if (fid < 0)
      error ("runtests: fopen failed: %s", f);
    endif
    str = fread (fid, "*char")';
    fclose (fid);
    retval = ! isempty (regexp (str,'^(?:DEFUN|DEFUN_DLD|DEFUNX)\>',
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
    error ("runtests: fopen failed: %s", f);
  endif

  str = fread (fid, "*char").';
  fclose (fid);
  retval = ! isempty (regexp (str,
                              '^%!(assert|error|fail|test|xtest|warning)',
                              'lineanchors', 'once'));

endfunction

function print_pass_fail (p, n, xf, xb, sk, rtsk, rgrs)

  if ((n + sk + rtsk + rgrs) > 0)
    printf (" PASS   %4d/%-4d", p, n);
    nfail = n - p - xf - xb - rgrs;
    if (nfail > 0)
      printf ("\n%71s %3d", "FAIL ", nfail);
    endif
    if (rgrs > 0)
      printf ("\n%71s %3d", "REGRESSION", rgrs);
    endif
    if (xb > 0)
      printf ("\n%71s %3d", "(reported bug) XFAIL", xb);
    endif
    if (xf > 0)
      printf ("\n%71s %3d", "(expected failure) XFAIL", xf);
    endif
    if (sk > 0)
      printf ("\n%71s %3d", "(missing feature) SKIP", sk);
    endif
    if (rtsk > 0)
      printf ("\n%71s %3d", "(run-time condition) SKIP", rtsk);
    endif
  endif
  puts ("\n");

endfunction

function print_test_file_name (nm)
  filler = repmat (".", 1, 60-length (nm));
  printf ("  %s %s", nm, filler);
endfunction

function make_sure_doctest_is_loaded
  w = which ("doctest");
  if isempty (w)
    error (["test_pkgs: Could not find doctest() function. " ...
      " Make sure the doctest package is installed and loaded."]);
  endif
endfunction

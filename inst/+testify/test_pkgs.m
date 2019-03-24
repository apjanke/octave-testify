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
## @deftypefnx {} {[@var{nfailed}, @var{__rslts__}] =} test_pkgs (@dots{})
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
## If the second argout, @var{__rslts__}, is captured, it returns an
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

function [nfailed, __rslts__] = test_pkgs (pkg_names, options)

  if nargin < 1;  pkg_names = {};  endif
  if nargin < 2;  options = {};    endif

  default_opts = struct (...
    "all_together", false, ...
    "n_iters",      1, ...
    "rand_seed",    42.0, ...
    "doctest",      testify.internal.Util.is_doctest_loaded);
  opts = testify.internal.Util.parse_options (options, default_opts);

  if opts.doctest
    make_sure_doctest_is_loaded;
  endif

  if (isempty (pkg_names))
    pkg_names = list_installed_packages ();
  endif
  pkg_names = cellstr (pkg_names);
  # Hack: Don't test Testify etc, because we need it to stay loaded while running
  # the tests.
  my_impl_pkgs = {'testify', 'doctest'};
  pkg_names = setdiff (pkg_names, {'testify', 'doctest'});

  nfailed = 0;

  rslts = testify.internal.BistRunResult;
  pkgs_with_failures = {};

  fprintf ("Running package tests\n");
  if floor (opts.rand_seed) == opts.rand_seed
    rand_seed_display = num2str (opts.rand_seed);
  else
    rand_seed_display = sprintf ("%0.16f", opts.rand_seed);
  endif
  fprintf ("Random seed is: %s\n", rand_seed_display);

  ## Test packages when they're all loaded together

  pkg ("load", pkg_names{:});
  for i = 1:numel (pkg_names)
    pkg_name = pkg_names{i};
    pkg_info = pkg ("list", pkg_name);
    pkg_info = pkg_info{1};
    fprintf ("\nTesting package %s %s\n", pkg_name, pkg_info.version);
    pkg_dir = pkg_info.dir;
    for i_iter = 1:opts.n_iters
      runner = test_runner_for_package (pkg_name);
      rslt = runner.run_tests;
      rslts += rslt;
      if rslt.n_fail > 0
        pkgs_with_failures{end+1} = pkg_name;
      endif
      nfailed += rslt.n_fail;
    endfor
  endfor
  pkg ("unload", pkg_names{:});

  ## Display results
  reporter = testify.internal.BistResultsReporter;
  reporter.print_results_summary (rslts);
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
  else
    nfailed = nfailed == 0;
  endif
  if nargout >= 2
    __rslts__ = rslts;
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

function runner = test_runner_for_package (pkg_name)
  runner = testify.internal.MultiBistRunner;
  runner.add_package (pkg_name);
endfunction  

function make_sure_doctest_is_loaded
  w = which ("doctest");
  if isempty (w)
    error (["test_pkgs: Could not find doctest() function. " ...
      " Make sure the doctest package is installed and loaded."]);
  endif
endfunction

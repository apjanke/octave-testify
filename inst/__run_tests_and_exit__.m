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


function __run_tests_and_exit__ (pkg_names)
  %__RUN_TESTS_AND_EXIT__ Run tests on packages and exit based on results
  %
  % __run_tests_and_exit__ (pkg_names)
  %
  % Runs BIST test suite on named packages, and then exits Octave. The process
  % exit status is 0 if all tests passed, or nonzero if any failed. This is
  % to support integration with CI test harnesses, which want to know whether
  % the test suite passed in order to report it back up to the caller and/or
  % fail the build.
  %
  % pkg_names (cellstr) is a list of the packages to test. If omitted or empty,
  % tests all installed packages.
  try
	  nfailed = __test_pkgs__ (pkg_names);
	  fprintf ("Number of failed tests: %d\n", nfailed);
	  exit (double (nfailed > 0));
  catch err
    fprintf ("Caught error while running test suite: %s", err.message);
    exit (42);
  end
endfunction



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

function install_and_test_forge_pkgs (pkgs_to_test, options)
  %INSTALL_AND_TEST_FORGE_PKGS Install and test all or selected forge packages
  %
  % testify.install_and_test_forge_pkgs (pkgs_to_test, options)
  %
  % pkgs_to_test (cellstr) is a list of names of Octave Forge packages to test.
  % If omitted or empty, tests all packages currently available on the Octave
  % Forge website.
  %
  % NOTE: Running this function will uninstall all packages except for testify
  % and doctest. This is because Octave's pkg doesn't support isolated virtual
  % environments for package installation. Don't run this on a machine that you've
  % spent significant time setting up pacakges for.
  %
  % options (cellstr or struct) controls behavior. Valid options:
  %   doctest (boolean, false*) - Whether to do doctest tests in addition to
  %       regular BIST tests.
  if nargin < 2;  options = {};    endif

  default_opts = struct (...
    "doctest",      false);
  opts = testify.internal.Util.parse_options (options, default_opts);

  if nargin < 1; pkgs_to_test = {}; endif
  pkgtester = testify.internal.ForgePkgTester;
  pkgtester.do_doctest = opts.doctest;
  if ~isempty (pkgs_to_test)
    pkgtester.pkgs_to_test = pkgs_to_test;
  endif
  pkgtester.install_and_test_forge_pkgs;  
endfunction

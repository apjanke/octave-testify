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

function install_and_test_all_forge_pkgs (pkgs_to_test)
  if nargin < 1; pkgs_to_test = {}; endif
  pkgtester = testify.internal.ForgePkgTester;
  if ~isempty (pkgs_to_test)
    pkgtester.pkgs_to_test = pkgs_to_test;
  endif
  pkgtester.install_and_test_all_forge_pkgs;  
endfunction

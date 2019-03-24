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

classdef ForgePkgInstaller
  %FORGEPKGINSTALLER Enhanced replacement for `pkg install`
  
  methods
    function out = install (this, varargin)
      %INSTALL Wrapper for `pkj -forge install`
      %
      % Returns a result code instead of throwing errors in the case of some
      % package installation failures. You need to check the return status.
      args = cellstr (varargin);
      install_args = [{'install' '-forge'} args];
      say ("%s", strjoin (install_args, ' '));
      out = pkj (install_args{:});
    endfunction
  endmethods
  
endclassdef

function say (varargin)
  fprintf ('%s: %s\n', 'testify.ForgePkgInstaller', sprintf (varargin{:}));
  testify.internal.Util.flush_diary
endfunction


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

classdef BistWorkspace < handle
  %BISTWORKSPACE A persistent workspace for BIST test code to run in
  %
  % A BistWorkspace persists a workspace independently of the Octave
  % function call stack, for re-use through multiple eval() calls. This is
  % whare "shared" variables are kept

  properties
    % The names of the variables persisted in this workspace (cellstr)
    vars = {};
    % The persisted values of the workspace variables
    workspace = struct;
  endproperties

  methods
    function this = BistWorkspace (vars)
      if nargin == 0
        return
      endif
      if ! iscellstr (vars)
        error ("BistWorkspace: vars must be a cellstr; got a %s", class (vars));
      endif
      this.add_vars (vars);
    endfunction

    function add_vars (this, vars)
      %ADD_VARS Add new variables to this workspace
      vars = cellstr (vars);
      for i = 1:numel (vars)
        if ! isvarname (vars{i})
          error ("BistWorkspace.add_vars: invalid variable name: '%s'", vars{i});
        endif
      endfor
      for i = 1:numel (vars)
        if ! ismember (vars{i}, this.vars)
          this.vars{end+1} = vars{i};
          this.workspace.(vars{i}) = [];
        endif
      endfor
    endfunction

    function wax_on (this)
      %WAX_ON Restore this's workspace to caller function's workspace
      for i = 1:numel (this.vars)
        assignin ("caller", this.vars{i}, this.workspace.(this.vars{i}));
      endfor
    endfunction

    function wax_off (this)
      %WAX_OFF Persist variables from caller function's workspace to this
      for i = 1:numel (this.vars)
        this.workspace.(this.vars{i}) = evalin ("caller", this.vars{i});
      endfor
    endfunction

    function eval (__this, __code)
      %EVAL Evaluate code in the context of the persisted workspace
      __this.wax_on;
      unwind_protect
        eval (__code);
      unwind_protect_cleanup
        __this.wax_off;
      end_unwind_protect
    endfunction
  endmethods
endclassdef
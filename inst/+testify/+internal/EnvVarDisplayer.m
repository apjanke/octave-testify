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

classdef EnvVarDisplayer
  
  properties
    secret_redaction_pattern = 'pass|token|secret'
    ugly_var_patterns = {
      '^LESS_TERMCAP'
      'LSCOLORS'
    }
  endproperties

  methods 
    function out = get_env_var_names (this)
      %GET_ENV_VAR_NAMES Get names of existing environment variables
      %
      % Gets the names of all environment variables. The returned names will be in
      % sorted asciibetical order.
      %
      % Returns a cellstr vector.
      %
      % Note: a weird thing here is that the Java-based method detects different
      % env vars than the env trick. In particular, on macOS, it picks up 
      % DYLD_FALLBACK_LIBRARY_PATH and OLDPWD that the env trick does not. I'm
      % guessing this has to due with Octave's implementation of Java and
      % system(). I do not know which one is more correct. - apjanke
      if usejava ('jvm')
        out = this.get_env_var_names_using_java;
      else
        out = this.get_env_var_names_using_env_trick;
      endif
    endfunction
  
    function out = get_env_var_names_using_java (this)
      env = javaMethod ('getenv', 'java.lang.System');
      keys = env.keySet;
      it = keys.iterator;
      out = {};
      while it.hasNext
        out{end+1} = char (it.next);
      endwhile
      out = sort (out);
    endfunction
    
    function out = get_env_var_names_using_env_trick (this)
      % As far as I can tell, there's no POSIX function to just list the environment
      % variable names. So we do a hack with calling env. This is buggy, because if
      % some of the environment variables contain multi-line values, and there is
      % an "=" character in the 2nd or later line, it will mis-detect it as and
      % environment variable.
      [status, txt] = system ('env');
      if status != 0
        error ("Failed running command 'env': exit status %d", status);
      endif
      lines = regexp(txt, '\r?\n', 'split');
      for i = 1:numel (lines)
        [ix,tok] = regexp(lines{i}, '^(\w+)=(.*)$', 'start', 'tokens');
        if isempty (ix)
          continue
        endif
        tok = tok{1};
        name = tok{1};
        val = tok{2};
        % Check against actual env var value to see if we've parsed it right
        if ! isempty (val) && isempty (getenv (name))
          % That's a false-positive caused by an embedded "=" in an env var
          continue
        endif
        out{end+1} = name;
      endfor
      out = sort (out);
    endfunction
    
    function out = display_redacted_env_vars (this)
      vars = this.get_env_var_names;
      for i_var = 1:numel (vars)
        var = vars{i_var};
        val = getenv (var);
        disp_str = val;
        for i_pat = 1:numel (this.ugly_var_patterns)
          if regexp (var, this.ugly_var_patterns{i_pat})
            disp_str = '<suppressed>';
          endif
        endfor
        if regexpi (var, this.secret_redaction_pattern)
          disp_str = '<redacted>';
        endif
        fprintf ('%s=%s\n', var, disp_str);
      endfor
    endfunction
  endmethods
endclassdef

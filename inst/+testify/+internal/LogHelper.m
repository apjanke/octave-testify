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

classdef LogHelper

  methods (Static)

    function display_system_info (fid = stdout)
      fprintf (fid, evalc("ver"));
      if ismac
        [status, sys_info] = system ("sw_vers");
        fprintf (fid, "macOS System Info:\n");
        fprintf (fid, "%s", sys_info);
        [status, xcode_info] = system ("xcodebuild -version");
        fprintf (fid, "%s", xcode_info);
      endif
      if isunix && exist ("/etc/os-release", "file")
        txt = fileread ("/etc/os-release");
        fprintf (fid, "Unix System Info (os-release):\n");
        fprintf (fid, "%s", txt);
      endif
      if ispc
        [status, sys_info] = system ("systeminfo");
        if status == 0
          fprintf (fid, "Windows System Info:\n");
          fprintf (fid, "%s", sys_info);
        endif
      endif
      fprintf (fid, "\n");
      fprintf (fid, "Environment Variables:\n");
      env_var_displayer = testify.internal.EnvVarDisplayer;
      env_var_displayer.display_redacted_env_vars (fid);
      fprintf (fid, "\n");
      if isunix
        [status, lc_info] = system ("locale");
        fprintf (fid, "Locale:\n");
        fprintf (fid, "%s", lc_info);
        fprintf (fid, "\n");
      endif
    endfunction

  endmethods

endclassdef
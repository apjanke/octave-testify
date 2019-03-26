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

classdef Util

  methods (Static)

    function out = parse_options (options, defaults)
      opts = defaults;
      if iscell (options)
        s = struct;
        for i = 1:2:numel (options)
          s.(options{i}) = options{i+1};
        endfor
        options = s;
      endif
      if (! isstruct (options))
        error ("options must be a struct or name/val cell vector");
      endif
      opt_fields = fieldnames (options);
      for i = 1:numel (opt_fields)
        opts.(opt_fields{i}) = options.(opt_fields{i});
      endfor
      out = opts;
    endfunction

    function out = safe_hostname ()
      [status, host] = system ("hostname 2>/dev/null");
      if status == 0
        out = chomp (host);
      else
        % Yes, this might happen. E.g. hostname fails under Flatpak
        out = "unknown-host";
      endif
    endfunction

    function out = os_name ()
      if ispc
        out = "Windows";
      elseif ismac
        out = "macOS";
      else
        out = "Unix";
      endif
    endfunction

    function out = shuffle (x, seed)
      orig_seed = rand ("seed");
      unwind_protect
        rand ("seed", seed);
        out = x(1:0);
        ixs_left = 1:numel(x);
        while ! isempty (ixs_left)
          ix = randi (numel (ixs_left));
          out(end+1) = x(ixs_left(ix));
          ixs_left(ix) = [];
        endwhile
      unwind_protect_cleanup
        rand ("seed", orig_seed);
      end_unwind_protect
    endfunction

    function filewrite (filename, str)
      fid = fopen2 (filename, "w");
      fprintf (fid, "%s", str);
      fclose (fid);
    endfunction

    function flush_diary ()
      [status, file] = diary;
      if status
        diary off
        diary on
      endif
    endfunction

    function out = is_doctest_loaded ()
      out = ! isempty (which ("doctest"));
    endfunction
    
    function movefile (f1, f2, varargin)
      [ok, msg, msgid] = movefile (f1, f2, varargin{:});
      if ! ok
        error ("movefile: Failed moving '%s' to '%s': %s", f1, f2, msg);
      endif
    endfunction

    function mkdir (path)
      [ok, msg] = mkdir (path);
      if ! ok
        error ("mkdir: Could not create directory %s: %s", path, msg);
      endif
    endfunction

    function out = readdir (path)
      [out, err, msg] = readdir (path);
      if err
        error ("readdir: Could not read directory '%s': %s", path, msg);
      endif
      out(ismember (out, {'.', '..'})) = [];
    endfunction

    function rm_rf (path)
      if exist (path, "dir")
        confirm_recursive_rmdir (0, "local");
        [ok, msg, msgid] = rmdir (path, "s");
        if ! ok
          error ("rm_rf: Failed deleting dir %s: %s", path, msg);
        endif
      elseif exist (path, "file")
        lastwarn("");
        delete (path);
        [w, w_id] = lastwarn;
        if ! isempty (w)
          error ("rm_rf: Failed deleting file %s: %s", path, w);
        endif
      else
        % NOP
      endif
    endfunction

  endmethods

endclassdef

function out = chomp (str)
  out = regexprep (str, "\r?\n$", "");
endfunction

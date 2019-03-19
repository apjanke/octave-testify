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

classdef MultiBistRunner < handle
  %MULTIBISTRUNNER Runs BISTs for multiple source files
  %
  % This knows how to locate multiple files that contain tests, run them using
  % BistRunner, and format output in a higher-level multi-file manner.
  % 
  % This is basically the implementation for the runtests2() function.
  %
  % TODO: To reproduce runtests2's output, we need to track tagged groups of test
  % files, not just individual files, so we can do the "Processing files in <dir>:"
  % outputs.

  properties
    % List of files to test, as { tag, path; ... }. Paths may be absolute or relative.
    files = cell (0, 2);
  endproperties

  methods
    function add_file_or_directory (this, file)
      if isfolder (file)
        this.add_directory (file);
      else
        this.add_file (file);
      endif
    endfunction

    function add_file (this, file)
      if isfolder (file)
        error ("MultiBistRunner.add_file: file is a directory: %s", file);
      endif
      this.files = [this.files; {file file}];
    endfunction

    function add_directory (this, path, recurse = true)
      if ! isfolder (path)
        error ("MultiBistRunner.add_directory: not a directory: %s", path);
      endif

      kids = setdiff (readdir (path), {".", ".."});
      for i = 1:numel (kids)
        f = fullfile (path, kids{i});
        if isfolder (f)
          if recurse
	        this.add_directory (f);
	      endif
        else
          if this.looks_like_testable_file (f);
            this.add_file (f);
          endif
        endif
      endfor
    endfunction

    function add_function (this, name)
      %TODO: Add support for namespaces. This will require doing our own path search,
      % because which() doesn't support them.

      fcn_file = which (name);
      if ! isempty (fcn_file) && endswith_any (fcn_file, '.m')
        this.files = [this.files {name fcn_file}];
      endif
    endfunction

    function add_class (this, name)
      error ("MultiBistRunner: add_class is not yet implemented.");
      % TODO: Find all the files for this class, looking for multiple @class dirs
      % all along the Octave path. Don't forget namespace support.
    endfunction

    function out = looks_like_testable_file (this, file)
      out = endswith_any (file, {'.m', '.cc', '.cc-tst'});
    endfunction

  endmethods
endclassdef

function out = endswith_any (str, endings)
  endings = cellstr (endings);
  for i = 1:numel (endings)
    pat = endings{i};
    if numel (pat) >= numel (str) && isequal (str(end-numel (pat) + 1:end), pat)
      out = true;
      return
    endif
  endfor
  out = false;
endfunction
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

  endmethods

endclassdef
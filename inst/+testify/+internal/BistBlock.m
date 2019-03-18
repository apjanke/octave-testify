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

classdef BistBlock
  %BISTBLOCK A basic BIST block from a file.
  %
  % This is the basic block of testing logic for BISTs. A BistBlock is the
  % thing represented by a single "%!test", "%!shared", or other BIST
  % block/statement.

  properties
  	% The type of block this is, e.g. "demo", "shared", "test". May be any
  	% string, including types that the BistBlock does not specifically know about.
  	type = ""
  	% The index of the block within the source file it came from. NaN for unknown.
  	index = NaN
  	% Whether this is valid. Set this flag false if there was a parsing error.
  	is_valid = true
  	% Error message for invalid blocks, to go with is_valid = false
  	error_message
  	% The unparsed contents of the block as a generic string
  	contents = ""
  	% Whether this is a test block of some sort
  	is_test = false
  	% Whether this is a test block that is expected to fail
  	is_xtest = false
  	% The code to run for blocks that have code, like "test"s or "shared"s
  	code = ""
  	% The variables defined by a "shared" block, as cellstr
  	vars = {}
  	% The name of the function defined by a "function" block
  	function_name = [];
  	% Bug ID for xtest-like blocks
  	bug_id
  	fixed_bug
  	is_warning
  	pattern
  	pat_str
  	id
  	% Runtime feature test for "testif" blocks
  	runtime_feat_test
  	% Feature line for "testif" blocks
  	feat_line
  	% Feature for "testif" blocks
  	feat
  endproperties

  methods
  	function disp (this)
  	  origWarn = warning;
  	  warning off Octave:classdef-to-struct
  	  data = builtin ("struct", this);
  	  warning (origWarn);
  	  fprintf("BistBlock:\n");
  	  disp (data);
  	endfunction
  endmethods

endclassdef
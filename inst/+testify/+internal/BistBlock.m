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
    bug_id = ""
    % Whether this identified bug has been marked as fixed
    fixed_bug = false
    is_warning = false
    % Regexp pattern for matching message in "error" and "warning" tests
    pattern = ""
    pat_str = ""
    % Expected error identifier for "error" tests
    error_id = ""
    % Runtime feature test for "testif" blocks
    runtime_feature_test = ""
    % Feature for "testif" blocks
    feature = ""
    % The whole text of the feature line for "testif" blocks (for debugging)
    feature_line = ""
  endproperties

  methods

    function this = set.feature (this, feature)
      if ! ischar (feature) && ! iscellstr (feature)
        error ("feature must be char or cellstr; got a %s", class (feature));
      endif
      this.feature = feature;
    endfunction

    function out = dispstr (this)
      lines = {};
      line0 = sprintf ("test block %d: %s", this.index, this.type);
      if ! this.is_valid
        lines{end+1} = line0;
        lines{end+1} = sprintf ("INVALID BLOCK!");
        lines{end+1} = "Contents:";
        lines{end+1} = this.contents;
        out = strjoin (lines, "\n");
        return;
      endif

      props0 = {};  % props to go on same line as "test block N: ..."
      props1 = {};  % props to go on first line after that
      props2 = {};  % props to go on second line after that
      morelines = {};  % and then the rest
      switch this.type
        case "demo"
          morelines{end+1} = this.contents;
        case "shared"
          morelines{end+1} = sprintf ("  vars: %s", strjoin (this.vars, " "));
          if ! isempty (this.code)
            morelines{end+1} = "Code:";
            morelines{end+1} = this.code;
          endif
        case "function"
          morelines{end+1} = "Code:";
          morelines{end+1} = this.code;
        case "endfunction"
          % NOP
        case {"assert", "fail"}
          props1{end+1} = sprintf("is_test=%d", this.is_test);
          props1{end+1} = sprintf("is_xtest=%d", this.is_xtest);
          if ! isempty(this.bug_id)
            props1{end+1} = sprintf("bug_id=%s", this.bug_id);
          endif
          if this.fixed_bug
            props1{end+1} = sprintf("fixed_bug=%d", this.fixed_bug);
          endif
          morelines{end+1} = "Code:";
          morelines{end+1} = this.code;
        case {"error", "warning"}
          props1{end+1} = sprintf("is_test=%d", this.is_test);
          props1{end+1} = sprintf("is_xtest=%d", this.is_xtest);
          if !isempty(this.error_id)
            props0{end+1} = sprintf("id='%s'", this.error_id);
          endif
          if !isempty(this.pattern)
            props0{end+1} = sprintf("/%s/", this.pattern);
          endif
          morelines{end+1} = "Code:";
          morelines{end+1} = this.code;
        case "testif"
          props1{end+1} = sprintf("is_test=%d", this.is_test);
          props1{end+1} = sprintf("is_xtest=%d", this.is_xtest);
          props2{end+1} = sprintf ("feature_line='%s'", this.feature_line);
          if iscellstr (this.feature)
            feat_str = ["{" strjoin(this.feature, ", ") "}"];
          else
            feat_str = this.feature;
          endif
          props2{end+1} = sprintf ("feature='%s'", feat_str);
          if !isempty(this.runtime_feature_test)
            props2{end+1} = sprintf ("  runtime_feature_test='%s'", this.runtime_feature_test);
          end
          morelines{end+1} = "Code:";
          morelines{end+1} = this.code;
        case {"test", "xtest"}
          props1{end+1} = sprintf("is_test=%d", this.is_test);
          props1{end+1} = sprintf("is_xtest=%d", this.is_xtest);
          if ! isempty(this.bug_id)
            props1{end+1} = sprintf("bug_id=%s", this.bug_id);
          endif
          if this.fixed_bug
            props1{end+1} = sprintf("fixed_bug=%d", this.fixed_bug);
          endif
          morelines{end+1} = "Code:";
          morelines{end+1} = this.code;
        case {"comment"}
          morelines{end+1} = "Contents:";
          morelines{end+1} = this.contents;
        otherwise
          props1{end+1} = sprintf("is_test=%d", this.is_test);
          props1{end+1} = sprintf("is_xtest=%d", this.is_xtest);
          morelines{end+1} = "*** <unrecognized block type> ***";
          morelines{end+1} = "Contents:";
          morelines{end+1} = this.contents;
      endswitch

      if !isempty(props0)
        line0 = [line0 " " strjoin(props0, " ")];
      endif
      lines{end+1} = line0;
      if !isempty(props1)
        lines{end+1} = ["  " strjoin(props1, " ")];
      endif
      if !isempty(props2)
        lines{end+1} = ["  " strjoin(props2, " ")];
      endif
      lines = [lines morelines];
      out = strjoin (lines, "\n");
    endfunction

    function disp (this)
      str = this.dispstr;
      disp(this.dispstr);
    endfunction

    function inspect (this)
      origWarn = warning;
      warning off Octave:classdef-to-struct
      data = builtin ("struct", this);
      warning (origWarn);
      fprintf("BistBlock:\n");
      disp (data);
    endfunction
  endmethods

endclassdef
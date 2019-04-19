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
    fixed_bug = ""
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
      lines{end+1} = sprintf ("test block %d: %s", this.index, this.type);
      if ! this.is_valid
        lines{end+1} = sprintf ("INVALID BLOCK!");
        lines{end+1} = "Contents:";
        lines{end+1} = this.contents;
        out = strjoin (lines, "\n");
        return;
      endif

      switch this.type
        case "demo"
          lines{end+1} = this.contents;
        case "shared"
          lines{end+1} = sprintf ("  vars: %s", strjoin (this.vars, " "));
          if ! isempty (this.code)
            lines{end+1} = "Code:";
            lines{end+1} = this.code;
          endif
        case "function"
          lines{end+1} = "Code:";
          lines{end+1} = this.code;
        case "endfunction"
          % NOP
        case {"assert", "fail"}
          lines{end+1} = sprintf ("  is_test=%d  is_xtest=%d", this.is_test, this.is_xtest);
          lines{end+1} = sprintf ("  bug_id=%s  fixed_bug=%s", this.bug_id, this.fixed_bug);
          lines{end+1} = "Code:";
          lines{end+1} = this.code;
        case {"error", "warning"}
          lines{end+1} = sprintf ("  is_test=%d  is_xtest=%d", this.is_test, this.is_xtest);
          lines{end+1} = sprintf ("  error_id='%s'", this.error_id);
          lines{end+1} = sprintf ("  pattern=/%s/", this.pattern);
          lines{end+1} = "Code:";
          lines{end+1} = this.code;
        case "testif"
          lines{end+1} = sprintf ("  is_test=%d  is_xtest=%d", this.is_test, this.is_xtest);
          lines{end+1} = sprintf ("  feature_line='%s'", this.feature_line);
          if iscellstr (this.feature)
            feat_str = ["{" strjoin(this.feature, ", ") "}"];
          else
            feat_str = this.feature;
          endif
          lines{end+1} = sprintf ("  feature='%s'", feat_str);
          lines{end+1} = sprintf ("  runtime_feature_test='%s'", this.runtime_feature_test);
          lines{end+1} = "Code:";
          lines{end+1} = this.code;
        case {"test", "xtest"}
          lines{end+1} = sprintf ("  is_test=%d  is_xtest=%d", this.is_test, this.is_xtest);
          lines{end+1} = sprintf ("  bug_id=%s  fixed_bug=%s", this.bug_id, this.fixed_bug);
          lines{end+1} = "Code:";
          lines{end+1} = this.code;
        case {"comment"}
          lines{end+1} = "Contents:";
          lines{end+1} = this.contents;
        otherwise
          lines{end+1} = sprintf ("  is_test=%d  is_xtest=%d", this.is_test, this.is_xtest);
          lines{end+1} = "*** <unrecognized block type> ***";
          lines{end+1} = "Contents:";
          lines{end+1} = this.contents;
      endswitch

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
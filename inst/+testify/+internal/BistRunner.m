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

classdef BistRunner < handle
  %BISTRUNNER Runs BISTs for a single source file

  properties
    % The source code file the tests are drawn from. This may be an absolute
    % or relative path.
    file
    % Optional output file to direct output to (e.g. if you're logging)
    out_file = [];
    % "normal", "quiet", "verbose"
    output_mode = "normal"
    % File handle this is writing output to. Might be stdout.
    fid = [];
  endproperties

  properties (Dependent)
    verbose
  endproperties

  methods
    function this = BistRunner (file)
      %BISTRUNNER Construct a new BistRunner
      if nargin == 0
        return
      endif
      if ! ischar (file)
        error ("BistRunner: file must be char; got a %s", class (file))
      endif
      if ! exist (file, "file")
        error ("BistRunner: file does not exist: %s", file);
      endif
      this.file = file;
    endfunction

    function set.output_mode (this, mode)
      if ! ismember (mode, {"normal", "quiet", "verbose"})
        error ("BistRunner: invalid output_mode: %s", mode);
      endif
      this.output_mode = mode;
    endfunction

    function out = get.verbose (this)
      switch this.output_mode
        case "quiet"
          out = -1;
        case "normal"
          % TODO: "batch" mode should set this to -1 here
          if ! isempty (this.out_file)
            out = 1;
          else
            out = 0;
          endif
        case "verbose"
          out = 1;
      endswitch
    endfunction

    function start_output (this)
      if isempty (this.out_file)
        this.fid = stdout;
      else
        this.fid = fopen2 (this.out_file, "w");
      endif
    endfunction

    function emit (this, fmt, varargin)
      %EMIT Emit output to this' current output
      fprintf (this.fid, fmt, varargin{:});
    endfunction

    function end_output (this)
      fclose (this.fid);
      this.fid = [];
    endfunction

    function out = run_tests (this)
      %RUN_TESTS Run the tests found in this file
      this.start_output;
      RAII.out_file = onCleanup (@() this.end_output);
      out = testify.internal.BistRunResult;
      out.files_processed{end+1} = this.file;

      test_code = this.extract_test_code;
      if isempty (test_code)
      	this.emit ("%s????? %s has no tests\n", this.file);
      	return
      endif
      test_code_blocks = this.split_test_code_into_blocks (test_code);

      if this.verbose
        fprintf (">>>>> %s\n", this.file);
      endif

      # Track leaked resources
      fid_list_orig = fopen ("all");
      base_variables_orig = [evalin("base", "who") {"ans"}];
      global_variables_orig = who ("global");

      all_success = true;

      for i_block = 1:numel (test_code_blocks)
        block_contents = test_code_blocks{i_block};
        if this.verbose > 0
          this.emit ("***** %s\n", block_contents);
        endif
        block = this.parse_test_code_block (block_contents);

        ok = true;
        msg = [];
        istest = false;
        isxtest = false;
        bug_id = "";
        fixed_bug = false;

        switch block.type
          case "shared"
            % A "shared" block declares shared variables, plus some arbitrary code
            shared_defn = this.parse_shared_block (block.code);
            % Those variables are then persisted in a workspace through
            % subsequent test executions
            code = shared_defn.code;
          case "function"
            % A "function" block dynamically defines a function. I guess it's a 
            % global function? -apj
            % TODO: Eval the function definition
            % TODO: Queue up code to clear that function
            code = "";
          case "endfunction"
            % This is a dummy block left over from closing a function block. Ignore.
            code = "";
          case { "assert", "fail" }
        endswitch

      endfor

    endfunction

    function out = extract_test_code (this)
      %EXTRACT_TEST_CODE Extracts "%!" embedded test code from file as a single block
      % Returns multi-line char vector
      [fid, msg] = fopen (this.file, "rt");
      if (fid < 0)
        error ("BistRunner: Could not open source code file for reading: %s: %s", ...
          this.file, msg);
      endif
      test_code = {};
      while (ischar (line = fgets (fid)))
        if (strncmp (line, "%!", 2))
          test_code{end+1} = line(3:end);
        endif
      endwhile
      fclose (fid);
      out = strjoin (test_code, "");
    endfunction

    function out = split_test_code_into_blocks (this, test_code)
	    out = {};
	    ix_line = find (test_code == "\n");
	    ix_block = ix_line(find (! isspace (test_code(ix_line + 1)))) + 1;
	    for i = 1:numel (ix_block) - 1
	      out{end+1} = test_code(ix_block(i):ix_block(i + 1) - 2);
	    endfor
    endfunction

    function out = parse_test_code_block (this, block)
      ix = find (! isletter (block));
      if isempty (ix)
        out.type = block;
        out.code = "";
      else
        out.type = block(1:ix(1)-1);
        out.code = block(ix(1):end);
    endfunction

    function out = parse_shared_block (code)
      # Separate initialization code from variables
      # vars are the first line; code is the remaining lines
      ix = find (code == "\n");
      if isempty (ix)
        vars = code;
        code = "";
      else
        vars = code(1:ix(1)-1);
        code = code(ix(1):end);
      endif

      # Strip comments from variables
      ix = find (vars == "%" | vars == "#");
      if ! isempty (ix)
        vars = vars(1:ix(1)-1);
      endif

      vars = regexp (vars, "\s+", "split");
      out.vars = vars;
      out.code = code;
    endfunction

    function out = parse_test_definitions (this)
      % Extract the test definitions from the file's source code
    endfunction
  endmethods

endclassdef

function out = trimleft (str)
  % Strip leading blanks from string(s)
  str = regexprep (str, "^ +", "");
endfunction
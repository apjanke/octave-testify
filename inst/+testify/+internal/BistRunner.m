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
  %
  % This is basically the implementation for the test2() function.

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
    % Whether to run demo blocks when running tests
    run_demo = false;
  endproperties

  properties (Dependent)
    verbose
  endproperties

  methods (Static)
    function file = locate_test_file (name, verbose, fid)
      # Locates file to run tests on for a name.
      # If not found, emits a diagnostic message about tests-not-found.
      #
      # inputs:
      #   name - file to search for, loosely defined. The name is the string
      #          that is passed in to the test2 function.
      #   verbose - whether to print diagnostic messages to fid when file is not found.
      #          Defaults to false.
      #   fid - file id to write progress messages to. Uses stdout if omitted.
      # outputs:
      #   file - full path to located file, including extension (charvec). Empty
      #     if file was not found.
      if nargin < 2 || isempty (verbose);  verbose = false;  endif
      if nargin < 3 || isempty (fid)
        fid = stdout;
      endif

      file = file_in_loadpath (name, "all");
      if ! isempty (file)
        return
      endif
      file = file_in_loadpath ([name ".m"], "all");
      if ! isempty (file)
        return
      endif
      file = file_in_loadpath ([name ".cc"], "all");
      if ! isempty (file)
        return
      endif
      testsdir = __octave_config_info__ ("octtestsdir");
      candidates = {
        fullfile(testsdir, name)
        fullfile(testsdir, [name "-tst"])
        fullfile(testsdir, [name ".cc-tst"])
        fullfile(testsdir, [name ".in.yy-tst"])
      };
      for i = 1:numel (candidates)
        if exist (candidates{i}, "file")
          file = candidates{i};
          break
        endif
      endfor
      if (iscell (file))
        if (isempty (file))
          file = "";
        else
          file = file{1};  # If there are duplicates, pick the first in path. 
        endif
      endif
      if ! isempty (file)
        return
      endif
      if (verbose)
        ftype = exist (name);
        if (ftype == 3)
          fprintf (fid, "%s%s source code with tests for dynamically linked function not found\n", ...
            "????? ", name);
        elseif (ftype == 5)
          fprintf (fid, "%s%s is a built-in function\n", ...
            "????? ", name);
        elseif (any (strcmp (__operators__ (), name)))
          fprintf (fid, "%s%s is an operator\n", ...
            "????? ", name);
        else
          fprintf (fid, "%s%s does not exist in path\n", ...
            "????? ", name);
        endif
        fflush (fid);
      endif    
    endfunction
  endmethods

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

    function  = extract_demo_code (this)
      test_code = this.extract_test_code;
      blocks = this.parse_test_code (test_code);
      demo_blocks_txt = {};
      demo_blocks_ix = [];
      for i = 1:numel (blocks)
        block = blocks(i);
        if isequal (block.type, "demo")
          demo_blocks_txt{end+1} = block.code;
          demo_blocks_ix(end+1) = numel (block.code) + 1;
        endif
      endfor
      out.code = strjoin (demo_blocks_txt, "");
      out.ixs = demo_blocks_ix;
    endfunction

    function out = run_tests (this)
      %RUN_TESTS Run the tests found in this file
      persistent signal_fail  = "!!!!! ";
      persistent signal_empty = "????? ";
      persistent signal_block = "***** ";
      persistent signal_file  = ">>>>> ";
      persistent signal_skip  = "----- ";

      this.start_output;
      RAII.out_file = onCleanup (@() this.end_output);
      out = testify.internal.BistRunResult;
      out.files_processed{end+1} = this.file;

      test_code = this.extract_test_code;
      if isempty (test_code)
      	this.emit ("%s????? %s has no tests\n", this.file);
      	return
      endif
      if this.verbose
        fprintf (">>>>> %s\n", this.file);
      endif
      blocks = this.parse_test_code (test_code);

      # Get initial state for tracking and cleanup
      fid_list_orig = fopen ("all");
      base_variables_orig = [evalin("base", "who") {"ans"}];
      global_variables_orig = who ("global");
      orig_wstate = warning ();

      all_success = true;

      workspace = testify.internal.BistWorkspace;
      rslt = testify.internal.BistRunResult;
      functions_to_clear = {};

      unwind_protect
        for i_block = 1:numel (blocks)
          block = blocks(i_block);
          success = true;
          msg = [];

          switch block.type

            case { "test" "assert" "fail" }
              try
                workspace.eval (code);
              catch err
                if isempty (lasterr ())
                  error ("test: empty error text, probably Ctrl-C --- aborting");
                endif
                success = false;
                if block.is_xtest
                  if isempty (block.bug_id)
                    if (block.fixed_bug)
                      rslt.n_regression += 1;
                      msg = "regression";
                    else
                      rslt.n_xfail += 1;
                      msg = "known failure";
                    endif
                  else
                    bug_id_display = block.bug_id;
                    if (all (isdigit (block.bug_id)))
                      bug_id_display = ["https://octave.org/testfailure/?" __bug_id];
                    endif
                    if (block.fixed_bug)
                      rslt.n_regression += 1;
                      msg = ["regression: " bug_id_display];
                    else
                      rslt.n_xfail_bug += 1;
                      msg = ["known bug: " bug_id_display];
                    endif
                  endif
                else
                  msg = "test failed";
                endif
                msg = [signal_fail msg "\n" lasterr()];
              end_try_catch

            case "shared"
              workspace.add_vars (block.vars);

            case "function"
              try
                eval (block.code);
                functions_to_clear{end+1} = block.function_name;
              catch err
                success = false;
                msg = [signal_fail "test failed: syntax error in function definition\n" err.message];
              end_try_catch

            case "endfunction"
              % NOP

            case "demo"
              % Each demo gets evaled in its own workspace, with no shared variables
              demo_ws = testify.internal.BistWorkspace;
              try
                demo_ws.eval (block.code);
              catch err
                success = false;
                msg = [signal_fail "demo failed\n" err.message];
              end_try_catch

            case { "assert", "fail" }

            case "error"
              try
                workspace.eval (code);
                % No error raised - that's a test failure
                success = false;
                msg = [signal_fail "no error raised."];
              catch err
                [ok, diagnostic] = this.error_matches_expected (err, block);
                if ! ok
                  success = false;
                  msg = [signal_fail "Incorrect error raised: " diagnostic];
                endif
              end_try_catch

            case "warning"

          endswitch

          if block.is_test
            rslt.n_test += 1;
            rslt.n_pass += success;
          endif
        endfor
      unwind_protect_cleanup
        # Cleanup
        for i = 1:numel (functions_to_clear)
          clear (functions_to_clear{i});
        endfor
      end_unwind_protect

      out = rslt;

    endfunction

    function [out, diagnostic] = error_matches_expected (this, err, block)
      diagnostic = [];
      if ! isempty (block.error_id)
        out = isequal (err.identifier, block.error_id);
        if ! out
          diagnostic = sprintf ("expected id %s, but got %s", block.error_id, err.identifier);
        endif
      else
        out = ! isempty (regexp (err.message, block.pattern, "once"));
        if ! out
          diagnostic = sprintf ("expected error message matching /%s/, but got '%s'", block.pattern, err.message);
        endif
      endif
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
      ## Add a dummy comment block to the end for ease of indexing.
      if (test_code(end) == "\n")
        test_code = ["\n" test_code "#"];
      else
        test_code = ["\n" test_code "\n#"];
      endif
      ## Chop it up into blocks for evaluation.
	    out = {};
	    ix_line = find (test_code == "\n");
	    ix_block = ix_line(find (! isspace (test_code(ix_line + 1)))) + 1;
	    for i = 1:numel (ix_block) - 1
	      out{end+1} = test_code(ix_block(i):ix_block(i + 1) - 2);
	    endfor
    endfunction

    function out = parse_test_code (this, test_code)
      % Parses the test code, returning BistBlock array
      block_txts = this.split_test_code_into_blocks (test_code);
      out = repmat (testify.internal.BistBlock, [0 0]);
      for i = 1:numel (block_txts)
        out(i) = this.parse_test_code_block (block_txts{i});
      end
    endfunction

    function out = parse_test_code_block (this, block)
      out = testify.internal.BistBlock;

      ix = find (! isletter (block));
      if isempty (ix)
        out.type = block;
        contents = "";
      else
        out.type = block(1:ix(1)-1);
        contents = block(ix(1):end);
      endif
      out.contents = contents;
      out.is_valid = true;
      out.error_message = "";
      out.is_test = false;

      # Type-specific parsing
      switch out.type
        case "demo"
          out.code = contents;

        case "shared"
          # Separate initialization code from variables
          # vars are the first line; code is the remaining lines
          ix = find (contents == "\n");
          if isempty (ix)
            vars = contents;
            code = "";
          else
            vars = contents(1:ix(1)-1);
            code = contents(ix(1):end);
          endif

          # Strip comments from variables line
          ix = find (vars == "%" | vars == "#");
          if ! isempty (ix)
            vars = vars(1:ix(1)-1);
          endif
          vars = regexp (vars, "\s+", "split");
          out.vars = vars;
          out.code = code;

        case "function"
          ix_fcn_name = find_function_name (contents);
          if (isempty (ix_fcn_name))
            out.is_valid = false;
            out.error_message = "missing function name";
          else
            out.function_name = contents(ix_fcn_name(1):ix_fcn_name(2));
            out.code = contents;
          endif

        case "endfunction"
          # No additional contents

        case {"assert", "fail"}
          [bug_id, rest, fixed] = this.find_bugid_in_assert (contents);
          out.is_test = true;
          out.is_xtest = ! isempty (bug_id);
          out.bug_id = bug_id;
          out.code = [out.type contents];

        case {"error", "warning"}
          out.is_test = true;
          out.is_warning = isequal (out.type, "warning");
          [pattern, id, code] = this.find_pattern (contents);
          if (id)
            pat_str = ["id=" id];
          else
            if ! strcmp (pattern, ".")
              pat_str = ["<" pattern ">"];
            else
              pat_str = ifelse (out.is_warning, "a warning", "an error");
            endif
          endif
          out.pattern = pattern;
          out.pat_str = pat_str;
          out.error_id = id;
          out.code = code;

        case "testif"
          e = regexp (contents, ".$", "lineanchors", "once");
          ## Strip any comment and bug-id from testif line before
          ## looking for features
          feat_line = strtok (contents(1:e), '#%');
          ix1 = index (feat_line, "<");
          if ix1
            tmp = feat_line(ix1+1:end);
            ix2 = index (tmp, ">");
            if (ix2)
              bug_id = tmp(1:ix2-1);
              if (strncmp (bug_id, "*", 1))
                bug_id = bug_id(2:end);
                fixed_bug = true;
              endif
              feat_line = feat_line(1:ix1-1);
            endif
          endif
          ix = index (feat_line, ";");
          if (ix)
            runtime_feat_test = feat_line(ix+1:end);
            feat_line = feat_line(1:ix-1);
          else
            runtime_feat_test = "";
          endif
          feat = regexp (feat_line, '\w+', 'match');
          feat = strrep (feat, "HAVE_", "");

        case "test"
          [bug_id, code, fixed_bug] = this.find_bugid_in_assert (contents);
          out.bug_id = bug_id;
          out.fixed_bug = fixed_bug;
          out.is_test = true;
          out.is_xtest = ! isempty (bug_id);
          out.code = code;

        case "xtest"
          [bug_id, code, fixed_bug] = this.find_bugid_in_assert (contents);
          out.is_test = true;
          out.is_xtest = true;
          out.code = code;

        case "#"
          # Comment block

        default
          # Unrecognized block type: no further parsing
          # But treat it as a test!?!?
          out.is_test = true;
          out.code = "";
      endswitch
    endfunction

    function out = find_function_name (this, def)
      pos = [];

      ## Find the end of the name.
      right = find (def == "(", 1);
      if (isempty (right))
        return;
      endif
      right = find (def(1:right-1) != " ", 1, "last");

      ## Find the beginning of the name.
      left = max ([find(def(1:right)==" ", 1, "last"), ...
                   find(def(1:right)=="=", 1, "last")]);
      if (isempty (left))
        return;
      endif
      left += 1;

      ## Return the end points of the name.
      pos = [left, right];
    endfunction

    function [bug_id, rest, fixed] = find_bugid_in_assert (this, str)
      bug_id = "";
      rest = str;
      fixed = false;

      str = trimleft (str);
      if (! isempty (str) && str(1) == "<")
        close = index (str, ">");
        if (close)
          bug_id = str(2:close-1);
          if (strncmp (bug_id, "*", 1))
            bug_id = bug_id(2:end);
            fixed = true;
          endif
          rest = str(close+1:end);
        endif
      endif
    endfunction

    function [pattern, id, rest] = find_pattern (this, str)
      pattern = ".";
      id = [];
      rest = str;
      str = trimleft (str);
      if (! isempty (str) && str(1) == "<")
        close = index (str, ">");
        if (close)
          pattern = str(2:close-1);
          rest = str(close+1:end);
        endif
      elseif (strncmp (str, "id=", 3))
        [id, rest] = strtok (str(4:end));
      endif
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
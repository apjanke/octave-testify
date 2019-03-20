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
    % File handle(s) to write detailed log output to
    log_fids = [];
    % Whether to run demo blocks when running tests
    run_demo = false;
    % If true, will abort the test run immediately upon any failure
    fail_fast = false;
    % Whether the test blocks should be shuffled.
    %  false:   no shuffle (default)
    %  true:    shuffle using a seed that BistRunner picks
    %  numeric: shuffle using this seed
    shuffle = false;
    % Whether to save workspaces for failed tests
    save_workspace_on_failure = false;
  endproperties

  properties (SetAccess = private)
    % Temp dir for BistRunner's data for a particular run (for this whole file)
    run_tmp_dir;
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
        file = file{1};
        return
      endif
      file = file_in_loadpath ([name ".m"], "all");
      if ! isempty (file)
        file = file{1};
        return
      endif
      file = file_in_loadpath ([name ".cc"], "all");
      if ! isempty (file)
        file = file{1};
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

    function emit (this, fmt, varargin)
      for fid = this.log_fids
        fprintf (fid, fmt, varargin{:});
      endfor
    endfunction

    function out = extract_demo_code (this)
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

    function out = maybe_shuffle_blocks (this, blocks)
      if this.shuffle
        if isnumeric (this.shuffle)
          shuffle_seed = this.shuffle;
        else
          shuffle_seed = now;
        endif
        this.emit ("Shuffling test blocks with rand seed %.15f\n", shuffle_seed);
        out = testify.internal.Util.shuffle (blocks, shuffle_seed);
      else
        out = blocks;
      endif
    endfunction

    function pick_run_tmp_dir (this)
      tmp_dir_base = sprintf ("bist-run-%s", datestr(now, 'yyyy-mm-dd_HH-MM-SS'));
      tmp_dir = fullfile (tempdir, "octave-testify-BistRunner", tmp_dir_base);
      mkdir (tmp_dir);
      this.run_tmp_dir = tmp_dir;
    endfunction

    function out = stashed_workspace_file (this)
      ws_dir = fullfile (this.run_tmp_dir, "workspaces");
      out = fullfile (ws_dir, "test-workspaces.mat");
    endfunction

    function stash_test_workspace (this, tag, data)
      # Stashing the workspace must be done to a file, and not to appdata or somewhere
      # else in Octave memory, to avoid keeping live references to handle objects and
      # interfering with object lifecycle and cleanup, which could affect test behavior.
      ws_file = this.stashed_workspace_file;
      mkdir (fileparts (ws_file));
      if exist (ws_file, "file")
        stash_data = load (ws_file);
      else
        stash_data = struct;
      endif
      stash_data.(tag) = data;
      save (ws_file, "-struct", "stash_data");
    endfunction

    function clear_stashed_workspace (this)
      ws_file = this.stashed_workspace_file;
      if exist (ws_file, "file")
        delete (ws_file);
      endif
    endfunction

    function out = grab_diary_state (this)
      [status, file] = diary;
      out.status = status;
      out.file = file;
    endfunction

    function restore_diary_state (this, state)
      diary (state.file);
      diary (state.status);
    endfunction

    function out = run_tests (this)
      %RUN_TESTS Run the tests found in this file
      persistent signal_fail  = "!!!!! ";
      persistent signal_empty = "????? ";
      persistent signal_block = "***** ";
      persistent signal_file  = ">>>>> ";
      persistent signal_skip  = "----- ";

      this.pick_run_tmp_dir;
      out = testify.internal.BistRunResult;
      out.files_processed{end+1} = this.file;

      test_code = this.extract_test_code;
      if isempty (test_code)
      	this.emit ("%s????? %s has no tests\n", this.file);
      	return
      endif
      this.emit (">>>>> %s\n", this.file);
      blocks = this.parse_test_code (test_code);

      blocks = this.maybe_shuffle_blocks (blocks);

      # Get initial state for tracking and cleanup
      fid_list_orig = fopen ("all");
      base_variables_orig = evalin("base", "who");
      base_variables_orig{end+1} = "ans";
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
          msg = "";

          this.emit ("%s %s (block #%d)\n%s\n", ...
            signal_block, block.type, block.index, block.code);

          if this.save_workspace_on_failure
            this.clear_stashed_workspace;
            this.stash_test_workspace ("before", workspace.workspace);
          endif
          t0 = tic;

          orig_diary_state = this.grab_diary_state;

          unwind_protect
            switch block.type

              case { "test", "xtest", "assert", "fail" }
                [success, rslt, msg] = run_test_code (this, block, workspace, rslt);

              case "testif"
                have_feature = __have_feature__ (block.feature);
                if have_feature
                  if isempty (block.runtime_feature_test) || eval (block.runtime_feature_test)
                    [success, rslt, msg] = run_test_code (this, block, workspace, rslt);
                  else
                    rslt.n_skip_runtime += 1;
                    msg = [signal_skip "skipped test (runtime test)"];
                  endif
                else
                  rslt.n_skip_feature += 1;
                  msg = [signal_skip "skipped test (missing feature)"];
                endif

              case "shared"
                workspace = testify.internal.BistWorkspace (block.vars);

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
                if this.run_demo
                  try
                    demo_ws.eval (block.code);
                  catch err
                    success = false;
                    msg = [signal_fail "demo failed\n" err.message];
                  end_try_catch
                else
                  msg = [signal_skip "demo skipped\n"];
                endif

              case "error"
                try
                  workspace.eval (block.code);
                  % No error raised - that's a test failure
                  success = false;
                  msg = [signal_fail "no error raised."];
                catch err
                  msg = "";
                  [ok, diagnostic] = this.error_matches_expected (err, block);
                  if ! ok
                    success = false;
                    msg = [signal_fail "Incorrect error raised: " diagnostic];
                  endif
                end_try_catch

              case "warning"
                lastwarn ("");
                orig_warn_state = warning ("query", "quiet");
                warning ("on", "quiet");
                unwind_protect
                  try
                    workspace.eval (block.code);
                    [warn_msg, warn_id] = lastwarn;
                    [ok, diagnostic] = this.warning_matches_expected (warn_msg, warn_id, block);
                    if ! ok
                      success = false;
                      msg = [signal_fail "Incorrect warning raised: " diagnostic];
                    endif
                  catch err
                    success = false;
                    msg = [signal_fail "error raised: " err.message];
                  end_try_catch
                unwind_protect_cleanup
                  lastwarn ("");
                  warning (orig_warn_state.state, "quiet");
                end_unwind_protect

              case "comment"
                % NOP

              otherwise
                # Unknown block type
                msg = [signal_skip "skipped test (unknown BIST block type: " block.type ")\n"];

          endswitch
          unwind_protect_cleanup
            this.restore_diary_state (orig_diary_state)
          end_unwind_protect

          te = toc (t0);
          rslt.elapsed_wall_time = te;
          this.emit ("  -> success=%d, msg=%s\n", success, msg);

          if block.is_test
            rslt.n_test += 1;
            rslt.n_pass += success;
          endif
          if success
            this.clear_stashed_workspace;
          else
            rslt = rslt.add_failed_file (this.file);
            if this.save_workspace_on_failure
              this.stash_test_workspace ("after", workspace.workspace);              
              this.emit ("\nSaved test workspace is available in: %s\n", this.stashed_workspace_file);
              fprintf ("\nSaved test workspace is available in: %s\n", this.stashed_workspace_file);
            endif
            if this.fail_fast
              break
            endif
          endif
        endfor
      unwind_protect_cleanup
        # Cleanup
        for i = 1:numel (functions_to_clear)
          clear (functions_to_clear{i});
        endfor
        warning ("off", "all");
        warning (orig_wstate);
      end_unwind_protect

      ## Verify test file did not leak resources
      if (! isempty (setdiff (fopen ("all"), fid_list_orig)))
        this.emit ("test2: test file %s leaked file descriptors\n", file);
      endif
      leaked_base_vars = setdiff (evalin ("base", "who"), base_variables_orig);
      if (! isempty (leaked_base_vars))
        this.emit ("test2: test file %s leaked variables to base workspace:%s\n",
                 this.file, sprintf (" %s", leaked_base_vars{:}));
      endif
      leaked_global_vars = setdiff (who ("global"), global_variables_orig);
      if (! isempty (leaked_global_vars))
        this.emit ("test2: test file %s leaked global variables:%s\n",
                 this.file, sprintf (" %s", leaked_global_vars{:}));
      endif

      out = rslt;

    endfunction

    function [success, rslt, msg] = run_test_code (this, block, workspace, rslt)
      persistent signal_fail  = "!!!!! ";
      msg = "";
      try
        workspace.eval (block.code);
        success = true;
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
              bug_id_display = ["https://octave.org/testfailure/?" block.bug_id];
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
          msg = sprintf ("test failed: raised error: %s", err.message);
        endif
      end_try_catch
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

    function [out, diagnostic] = warning_matches_expected (this, warn_msg, warn_id, block)
      if ! isempty (block.error_id)
        out = isequal (warn_id, block.error_id);
        if ! out
          diagnostic = sprintf ("expected id %s, but got %s", block.error_id, warn_id);
        endif
      else
        out = ! isempty (regexp (warn_msg, block.pattern, "once"));
        if ! out
          diagnostic = sprintf ("expected warning message matching /%s/, but got '%s'", block.pattern, warn_msg);
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
      for i = 1:numel (block_txts)
        out(i) = this.parse_test_code_block (block_txts{i});
        out(i).index = i;
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
            vars_line = contents;
            code = "";
          else
            vars_line = contents(1:ix(1)-1);
            code = contents(ix(1):end);
          endif

          # Strip comments from variables line
          ix = find (vars_line == "%" | vars_line == "#");
          if ! isempty (ix)
            vars_line = vars_line(1:ix(1)-1);
          endif
          vars_line = regexprep (vars_line, '\s+$', "");
          vars_line = regexprep (vars_line, '^\s+', "");

          if isempty (vars_line)
            vars = {};
          else
            vars = regexp (vars_line, '\s*,\s*', "split");
            vars = regexprep (vars, '\s+$', "");
            vars = regexprep (vars, '^\s+', "");
          endif
          out.vars = vars;
          out.code = code;

        case "function"
          ix_fcn_name = this.find_function_name (contents);
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
          out.is_test = true;
          e = regexp (contents, ".$", "lineanchors", "once");
          ## Strip any comment and bug-id from testif line before
          ## looking for features
          feat_line = strtok (contents(1:e), '#%');
          out.feature_line = feat_line;
          contents_rest = contents(e+1:end);
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
            out.runtime_feature_test = feat_line(ix+1:end);
            feat_line = feat_line(1:ix-1);
          else
            out.runtime_feature_test = "";
          endif
          feat = regexp (feat_line, '\w+', 'match');
          feat = strrep (feat, "HAVE_", "");
          out.feature = feat;
          out.code = contents_rest;

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
          out.type = "comment";

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
      out = pos;
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

    function out = print_test_results (this, rslt, file, fid)
      if nargin < 4 || isempty (fid); fid = stdout; endif

      persistent signal_empty = "????? ";
      r = rslt;
      if (r.n_test || r.n_xfail || r.n_xfail_bug || r.n_skip)
        if (r.n_xfail || r.n_xfail_bug)
          if (r.n_xfail && r.n_xfail_bug)
            fprintf (fid, "PASSES %d out of %d test%s (%d known failure%s; %d known bug%s)\n",
                    r.n_pass, r.n_test, ifelse (r.n_test > 1, "s", ""),
                    r.n_xfail, ifelse (r.n_xfail > 1, "s", ""),
                    r.n_xfail_bug, ifelse (r.n_xfail_bug > 1, "s", ""));
          elseif (r.n_xfail)
            fprintf (fid, "PASSES %d out of %d test%s (%d known failure%s)\n",
                    r.n_pass, r.n_test, ifelse (r.n_test > 1, "s", ""),
                    r.n_xfail, ifelse (r.n_xfail > 1, "s", ""));
          elseif (__xbug)
            fprintf (fid, "PASSES %d out of %d test%s (%d known bug%s)\n",
                    r.n_pass, r.n_test, ifelse (r.n_test > 1, "s", ""),
                    r.n_xfail_bug, ifelse (r.n_xfail_bug > 1, "s", ""));
          endif
        else
          fprintf (fid, "PASSES %d out of %d test%s\n", r.n_pass, r.n_test,
                 ifelse (r.n_test > 1, "s", ""));
        endif
        if (r.n_skip_feature)
          fprintf (fid, "Skipped %d test%s due to missing features\n", r.n_skip_feature,
                  ifelse (r.n_skip_feature > 1, "s", ""));
        endif
        if (r.n_skip_runtime)
          fprintf (fid, "Skipped %d test%s due to run-time conditions\n", r.n_skip_runtime,
                  ifelse (r.n_skip_runtime > 1, "s", ""));
        endif
      else
        fprintf (fid, "%s%s has no tests available\n", signal_empty, file);
      endif      
    endfunction

  endmethods

endclassdef

function out = trimleft (str)
  % Strip leading blanks from string(s)
  out = regexprep (str, "^ +", "");
endfunction
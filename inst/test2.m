## Copyright (C) 2005-2019 Paul Kienzle
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

## -*- texinfo -*-
## @deftypefn  {} {} test2 @var{name}
## @deftypefnx {} {} test2 @var{name} quiet|normal|verbose
## @deftypefnx {} {} test2 ("@var{name}", @dots{})
## @deftypefnx {} {@var{success}, @var{__rslt__} =} test2 (@dots{})
## @deftypefnx {} {[@var{n}, @var{nmax}, @var{nxfail}, @var{nbug}, @var{nskip}, @var{nrtskip}, @var{nregression}] =} test2 (@dots{})
## @deftypefnx {} {[@var{code}, @var{idx}] =} test2 ("@var{name}", "grabdemo")
## @deftypefnx {} {} test2 ([], "explain", @var{fid})
## @deftypefnx {} {} test2 ([], "explain", @var{fname})
##
## Perform built-in self-tests from the first file in the loadpath matching
## @var{name}.
##
## @code{test2} can be called in either command or functional form.  The exact
## operation of test2 is determined by a combination of mode (interactive or
## batch), reporting level (@qcode{"quiet"}, @qcode{"normal"},
## @qcode{"verbose"}), and whether a logfile or summary output variable is
## used.
##
## The default mode when @code{test2} is called from the command line is
## interactive.  In this mode, tests will be run until the first error is
## encountered, or all tests complete successfully.  In batch mode, all tests
## are run regardless of any failures, and the results are collected for
## reporting.  Tests which require user interaction, i.e., demo blocks,
## are never run in batch mode.
##
## Batch mode is enabled by either 1) specifying a logfile using the third
## argument @var{fname} or @var{fid}, or 2) requesting an output argument
## such as @var{success}, @var{n}, etc.
##
## The optional second argument determines the amount of output to generate and
## which types of tests to run.  The default value is @qcode{"normal"}.
## Requesting an output argument will suppress printing the final summary
## message and any intermediate warnings, unless verbose reporting is
## enabled.
##
## @table @asis
## @item @qcode{"quiet"}
## Print a summary message when all tests pass, or print an error with the
## results of the first bad test when a failure occurs.  Don't run tests which
## require user interaction.
##
## @item @qcode{"normal"}
## Display warning messages about skipped tests or failing xtests during test
## execution.
## Print a summary message when all tests pass, or print an error with the
## results of the first bad test when a failure occurs.  Don't run tests which
## require user interaction.
##
## @item @qcode{"verbose"}
## Display tests before execution.  Print all warning messages.  In interactive
## mode, run all tests including those which require user interaction.
## @end table
##
## The optional third input argument specifies a logfile where results of the
## tests should be written.  The logfile may be a character string
## (@var{fname}) or an open file descriptor ID (@var{fid}).  To enable batch
## processing, but still print the results to the screen, use @code{stdout} for
## @var{fid}.
##
## Arguments 2 and later are parsed as options. Valid options:
##
##   quiet
##   normal
##   verbose
##   -fail-fast        - Abort the test run immediately after any failure (default)
##   -no-fail-fast     - Do not abort the test run upon failures
##   -log-file <file>  - A file name to write result log output to
##   -log-fid <fid>    - An fid to write result log output to
##   -shuffle          - Shuffle the test block execution order
##   -save-workspace   - Save workspace data for failed test
##
## When called with output arguments (and not in @qcode{"grabdemo"} or @qcode{"explain"}
## mode), returns the following outputs:
##   @code{success} - True if all tests passed, false otherwise
##   @code{__rslt__} - An object holding results data. The format of this object
##                     is undocumented and subject to change at any time.
##   @code{__info__} - A struct or object of other info about the test run. The format
##                       of this object is undocumented and subject to change at any time.
##
## Example
##
## @example
## @group
## test2 sind
## @result{}
## PASSES 5 out of 5 tests
##
## [n, nmax] = test2 ("sind")
## @result{}
## n =  5
## nmax =  5
## @end group
## @end example
##
## Additional Calling Syntaxes
##
## If the second argument is the string @qcode{"grabdemo"}, the contents of
## any built-in demo blocks are extracted but not executed.  The text for all
## code blocks is concatenated and returned as @var{code} with @var{idx} being
## a vector of positions of the ends of each demo block.  For an easier way to
## extract demo blocks from files, @xref{XREFexample,,example}.
##
## If the second argument is @qcode{"explain"} then @var{name} is ignored and
## an explanation of the line markers used in @code{test2} output reports is
## written to the file specified by @var{fname} or @var{fid}.
##
## @seealso{test, assert, fail, demo, example, error}
## @end deftypefn

function varargout = test2 (name, varargin)

  ## Parse inputs
  if nargin < 1
    print_usage ();
  endif

  opts = parse_args (name, varargin);
  if ! isempty (opts.log_fname)
    fid = fopen2 (log_fname, "wt");
    RAII.logfile = onCleanup (@() fclose(fid));
  else
    fid = opts.fid;
  endif

  ## Special-case behaviors

  if isequal (opts.mode, "explain")
    emit_output_explanation (fid);
    return;
  endif

  ## General case

  ## Locate the file to test.

  file = testify.internal.BistRunner.locate_test_file (name, ! opts.grabdemo, fid);
  if isempty (file)
    # Failed finding file; return "false" in appropriate format
    if opts.grabdemo
      varargout = {"", -1};
    elseif nargout ==1
      varargout = {false};
    elseif nargout > 1
      varargout = {0, 0};
    endif
    return
  endif

  runner = testify.internal.BistRunner (file);
  runner.output_mode = opts.output_mode;
  runner.fail_fast = opts.fail_fast;
  runner.shuffle = opts.shuffle;
  runner.save_workspace_on_failure = opts.save_workspace;

  ## Special-case per-file behaviors

  if isequal (opts.mode, "grabdemo")
    s = runner.extract_demo_code ();
    varargout = { s.code, s.ixs };
    return
  endif
  
  runner.out_file = opts.log_fname;
  runner.run_demo = opts.rundemo;

  if ! isequal (opts.mode, "test")
    error ("Unimplemented test mode: %s", opts.mode);
  endif

  [rslt, info] = runner.run_tests;

  if nargout == 0
    runner.print_test_results (rslt);
  elseif nargout > 0
    if nargout > 2
      # Legacy return signature
      varargout = {rslt.n_fail, rslt.n_test, rslt.n_xfail, rslt.n_xfail_bug, ...
         rslt.n_skip_feature, rslt.n_skip_runtime, rslt.n_regression};
    else
      varargout = {rslt.n_fail, rslt, info};
    endif
  endif

endfunction

function out = parse_args (name, args)

  if (! isempty (name) && ! ischar (name))
    error ("test2: name must be a string; got a %s", class (name));
  endif

  mode = "test";
  output_mode = "normal";
  fail_fast = true;
  fid = [];
  log_fname = [];
  shuffle = false;
  shuffle_seed = [];
  shuffle_flag = [];
  save_workspace = false;
  
  i = 1;
  while i <= numel (args)
    arg = args{i};
    if ischar (arg)
      switch arg
        case {"grabdemo", "explain"}
          mode = arg;
          i += 1;
        case {"normal", "verbose", "quiet"}
          output_mode = arg;
          i += 1;
        case "-fail-fast"
          fail_fast = true;
          i += 1;
        case "-no-fail-fast"
          fail_fast = false;
          i += 1;
        case "-log-fid"
          fid = args{i+1};
          i += 2;
        case "-log-file"
          fid = args{i+1};
          i += 2;
        case "-shuffle"
          shuffle_flag = true;
          i += 1;
        case "-shuffle-seed"
          shuffle_seed = args{i+1};
          i += 2;
        case "-save-workspace"
          save_workspace = true;
          i += 2;
        otherwise
          error ("test2: unrecognized option: %s", arg)
      endswitch
    else
      error ("test2: unrecognized option (got a %s)", class (arg));
    endif
  endwhile

  ## Decide if error messages should be collected.
  out = struct;
  do_logfile = ! isempty (fid) || ! isempty (log_fname);
  batch = do_logfile || nargout > 0;
  cleanup = struct;
  out.fid = fid;
  out.log_fname = log_fname;

  grabdemo = false;
  rundemo = false;
  switch mode
    case "grabdemo"
      mode = "grabdemo";
      grabdemo = true;
      rundemo  = false;
      verbose  = -1;
      output_mode = "quiet";
    case "explain"
    case "test"
    otherwise
      error ("test2: unknown operation mode: '%s'", mode);
  endswitch
  switch output_mode
    case "normal"
      if (do_logfile)
        verbose = 1;
      elseif (batch)
        verbose = -1;
      else
        verbose = 0;
      endif
    case "quiet"
      verbose  = -1;
    case "verbose"
      rundemo  = ! batch;
      verbose  = 1;
    otherwise
      error ("test2: unknown output mode: '%s'", output_mode);
  endswitch

  if ! isempty (shuffle_flag)
    shuffle = shuffle_flag;
  endif
  if ! isempty (shuffle_seed)
    shuffle = shuffle_seed;
  endif

  out.name = name;
  out.mode = mode;
  out.do_logfile = do_logfile;
  out.log_fname = log_fname;
  out.grabdemo = grabdemo;
  out.rundemo = rundemo;
  out.output_mode = output_mode;
  out.verbose = verbose;
  out.fail_fast = fail_fast;
  out.shuffle_flag = shuffle_flag;
  out.shuffle_seed = shuffle_seed;
  out.shuffle = shuffle;
  out.save_workspace = save_workspace;
endfunction

function emit_output_explanation (fid)
  ## Output from test is prefixed by a "key" to quickly understand the issue.
  persistent signal_fail  = "!!!!! ";
  persistent signal_empty = "????? ";
  persistent signal_block = "***** ";
  persistent signal_file  = ">>>>> ";
  persistent signal_skip  = "----- ";

  emit (fid, "# %s new test file\n", signal_file);
  emit (fid, "# %s no tests in file\n", signal_empty);
  emit (fid, "# %s test had an unexpected result\n", signal_fail);
  emit (fid, "# %s test was skipped\n", signal_skip);
  emit (fid, "# %s code for the test\n\n", signal_block);
  emit (fid, "# Search for the unexpected results in the file\n");
  emit (fid, "# then page back to find the filename which caused it.\n");
  emit (fid, "# The result may be an unexpected failure (in which\n");
  emit (fid, "# case an error will be reported) or an unexpected\n");
  emit (fid, "# success (in which case no error will be reported).\n");  
endfunction

function emit (fid, format, varargin)
  fprintf (fid, format, varargin{:});
  fflush (fid);
endfunction

## Create struct with fieldnames the name of the input variables.
function s = vars2struct (varargin)
  for i = 1:nargin
    s.(inputname (i)) = varargin{i};
  endfor
endfunction

## Strip '.*prefix:' from '.*prefix: msg\n' and strip trailing blanks.
function msg = trimerr (msg, prefix)
  idx = index (msg, [prefix ":"]);
  if (idx > 0)
    msg(1:idx+length(prefix)) = [];
  endif
  msg = strtrim (msg);
endfunction

## Strip leading blanks from string.
function str = trimleft (str)
  idx = find (! isspace (str), 1);
  str = str(idx:end);
endfunction


## Copyright (C) 2010-2019 John W. Eaton
## Copyright (C) 2019 Andrew Janke
## Copyright (C) 2019 Colin B. Macdonald
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
## @deftypefn  {} {} runtests2 ()
## @deftypefnx {} {} runtests2 (@var{target})
## @deftypefnx {} {} runtests2 (@var{-<option>}, @var{arg}, @dots{})
## @deftypefnx {} {@var{success} =} runtests2 (@dots{})
## @deftypefnx {} {[@var{success}, @var{__info__}] =} runtests2 (@dots{})
## Execute built-in tests for all m-files in the specified @var{directory}.
##
## Test blocks in any C++ source files (@file{*.cc}) will also be executed
## for use with dynamically linked oct-file functions.
##
## @var{target} may be a file, directory, class, or function name. If @var{target}
## starts with a "@", it is always interpreted as a class. Directories may be
## either regular paths, or a directory that is on the Octave load path.
##
## Typically the type of a target is autodetected. You can also explicitly
## specify the type of a target using one of the following target specifications:
##
## Target types:
##
## @verbatim
##   -file <name>         - Run tests in a file
##   -dir <name>          - Run tests in all files in a directory
##   -class <name>        - Test a class
##   -function <name>     - Test a function
##   -pkg <name>          - Test an installed pkg (Octave Forge) package
##   -search-path         - Test everything on the Octave search path
##   -octave-builtins     - Test Octave's interpreter and built-in functions
## @end verbatim
##
## Options:
##
## @verbatim
##   -shuffle             - Shuffle file sets and file orders
##   -shuffle-seed <seed> - Shuffle file sets and file orders with given seed
##   -fail-fast           - Abort the test run upon the first test failure
##   -save-workspace      - Save test workspaces for failed tests
##   -log-file <file>     - File to write detailed test log info to
## @end verbatim
##
## If no target is specified, operates on all directories in Octave's search
## path. (The same as -search-path.)
##
## When called with a single return value (@var{success}), return false if
## there were any unexpected test failures, otherwise return true.  An extra
## output argument returns detailed results of the test run.  The format of
## this object is undocumented and subject to change at any time; it is
## currently intended for Octave's internal use only.
##
## @seealso{rundemos, test, path}
## @end deftypefn

function [p, __rslts__] = runtests2 (varargin)

  # Parse inputs and find tests

  opts = parse_inputs (varargin);

  runner = testify.internal.MultiBistRunner;
  runner.shuffle = opts.shuffle;
  runner.fail_fast = opts.fail_fast;
  runner.save_workspace_on_failure = opts.save_workspace;
  
  targets = opts.targets;
  if isempty (targets)
    targets = struct ("type", "search_path", "item", []);
  endif    
  for i = 1:numel (targets)
    t = targets(i);
    switch t.type
      case "auto"
        runner.add_target_auto (t.item);
      case "file"
        runner.add_file (t.item);
      case "dir"
        runner.add_directory (t.item);
      case "search_path"
        runner.add_stuff_on_octave_search_path;
      case "function"
        runner.add_function (t.item);
      case "class"
        runner.add_class (t.item);
      case "pkg"
        runner.add_package (t.item);
      case "installed_pkgs"
        runner.add_installed_packages;
      case "octave_builtins"
        runner.add_octave_builtins;
      otherwise
        error ("Unsupported target type: %s", t.type);
    endswitch
  endfor

  # Run tests and show results

  if ! isempty (opts.log_file)
    [log_fid] = testify.internal.Util.fopen (opts.log_file, "w");
    runner.log_fid = log_fid;
    RAII.log_fid = onCleanup (@() fclose (log_fid));
  endif

  rslts = runner.run_tests;
  
  reporter = testify.internal.BistResultsReporter;
  reporter.print_results_summary (rslts);

  # Package output

  if nargout >= 1
    p = rslts.n_fail == 0;
  endif
  if nargout >= 2
    __rslts__ = rslts;
  endif

endfunction

function out = parse_inputs (args)
  out.targets = [];
  out.fail_fast = false;
  out.save_workspace = false;
  out.log_file = [];

  i = 1;
  shuffle = false;
  shuffle_seed = [];
  shuffle_flag = [];
  while i <= numel (args)
    arg = args{i};
    switch arg
      case "-auto"
        out.targets = [out.targets target("auto", args{i+1})];
        i += 2;
      case "-file"
        out.targets = [out.targets target("file", args{i+1})];
        i += 2;
      case "-dir"
        out.targets = [out.targets target("dir", args{i+1})];
        i += 2;
      case "-class"
        out.targets = [out.targets target("class", args{i+1})];
        i += 2;
      case "-function"
        out.targets = [out.targets target("function", args{i+1})];
        i += 2;
      case "-pkg"
        out.targets = [out.targets target("pkg", args{i+1})];
        i += 2;
      case "-installed-pkgs"
        out.targets = [out.targets target("installed_pkgs", [])];
        i += 1;
      case "-search-path"
        out.targets = [out.targets target("search_path", [])];
        i += 1;
      case "-octave-builtins"
        out.targets = [out.targets target("octave_builtins", [])];
        i += 1;
      case "-shuffle"
        shuffle_flag = true;
        i += 1;
      case "-shuffle-seed"
        shuffle_seed = args{i+1};
        i += 2;
      case "-fail-fast"
        out.fail_fast = true;
        i += 1;
      case "-save-workspace"
        out.save_workspace = true;
        i += 1;
      case "-log-file"
        out.log_file = args{i+1};
        i += 2;
      case ""
        error ("runtests2: empty string is not a valid argument");
      otherwise
        if ischar (arg)
          if arg(1) == "-"
            error ("runtests2: invalid option: %s", arg);
          endif
          if arg(1) == "@"
            out.targets = [out.targets target("class", arg(2:end))];
          else
            out.targets = [out.targets target("auto", arg)];
          endif
        elseif iscellstr (arg)
          out.targets = [out.targets target("auto", arg)];
        endif
        i += 1;
    endswitch
  endwhile

  if ! isempty (shuffle_flag)
    shuffle = shuffle_flag;
  endif
  if ! isempty (shuffle_seed)
    shuffle = shuffle_seed;
  endif
  out.shuffle = shuffle;
endfunction

function out = target (type, item)
  if iscellstr (item)
    out = [];
    for i = 1:numel (item)
      out = [out target(type, item{i})];
    endfor
  elseif ischar (item) || isnumeric (item)
    out.type = type;
    out.item = item;
  else
    error ("Invalid item type: %s", class (item));
  endif
endfunction

function n = num_elts_matching_pattern (lst, pat)
  n = sum (! cellfun ("isempty", regexp (lst, pat, 'once')));
endfunction

function out = chomp (str)
  out = regexprep (str, "\r?\n$", "");
endfunction

%!error runtests2 ("foo", 1)
%!error <DIRECTORY argument> runtests2 ("#_TOTALLY_/_INVALID_/_PATHNAME_#")

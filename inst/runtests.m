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
## @deftypefn  {} {} runtests ()
## @deftypefnx {} {} runtests (@var{directory})
## @deftypefnx {} {@var{success} =} runtests (@dots{})
## @deftypefnx {} {[@var{success}, @var{__info__}] =} runtests (@dots{})
## Execute built-in tests for all m-files in the specified @var{directory}.
##
## Test blocks in any C++ source files (@file{*.cc}) will also be executed
## for use with dynamically linked oct-file functions.
##
## If no directory is specified, operate on all directories in Octave's search
## path for functions.
##
## When called with a single return value (@var{success}), return false if
## there were any unexpected test failures, otherwise return true.  An extra
## output argument returns detailed results of the test run.  The format of
## this object is undocumented and subject to change at any time; it is
## currently intended for Octave's internal use only.
##
## @seealso{rundemos, test, path}
## @end deftypefn

## Author: jwe

function [p, __info__] = runtests (directory)

  if (nargin == 0)
    dirs = ostrsplit (path (), pathsep ());
    do_class_dirs = true;
  elseif (nargin == 1)
    dirs = {canonicalize_file_name(directory)};
    if (isempty (dirs{1}) || ! isfolder (dirs{1}))
      ## Search for directory name in path
      if (directory(end) == '/' || directory(end) == '\')
        directory(end) = [];
      endif
      fullname = dir_in_loadpath (directory);
      if (isempty (fullname))
        error ("runtests: DIRECTORY argument must be a valid pathname");
      endif
      dirs = {fullname};
    endif
    do_class_dirs = false;
  else
    print_usage ();
  endif

  rslts = octave.test.internal.BistRunResult;
  for i = 1:numel (dirs)
    d = dirs{i};
    rslts += run_all_tests (d, do_class_dirs);
  endfor

  if (nargout >= 1)
    p = rslts.n_fail == 0;
  endif
  if (nargout == 2)
    __info__ = rslts;
  endif
endfunction

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


function rslts = run_all_tests (directory, do_class_dirs)

  rslts = octave.test.internal.BistRunResult;
  flist = readdir (directory);
  dirs = {};
  printf ("Processing files in %s:\n\n", directory);
  fflush (stdout);
  for i = 1:numel (flist)
    f = flist{i};
    if ((length (f) > 2 && strcmpi (f((end-1):end), ".m"))
        || (length (f) > 3 && strcmpi (f((end-2):end), ".cc")))
      ff = fullfile (directory, f);
      if (has_tests (ff))
        print_test_file_name (f);
        [~, rslt] = test (ff, "quiet");
        print_pass_fail (rslt);
        rslts += rslt;
        fflush (stdout);
      elseif (has_functions (ff))
        rslts.files_with_no_tests{end+1} = f;
      endif
    elseif (f(1) == "@")
      f = fullfile (directory, f);
      if (isfolder (f))
        dirs(end+1) = f;
      endif
    endif
  endfor
  if (! isempty (rslts.files_with_no_tests))
    printf ("\nThe following files in %s have no tests:\n\n", directory);
    printf ("%s", list_in_columns (rslts.files_with_no_tests));
  endif

  ## Recurse into class directories since they are implied in the path
  if (do_class_dirs)
    for i = 1:numel (dirs)
      rslts += run_all_tests (dirs{i}, false);
    endfor
  endif

endfunction

function retval = has_functions (f)

  n = length (f);
  if (n > 3 && strcmpi (f((end-2):end), ".cc"))
    fid = fopen (f);
    if (fid < 0)
      error ("runtests: fopen failed: %s", f);
    endif
    str = fread (fid, "*char")';
    fclose (fid);
    retval = ! isempty (regexp (str,'^(?:DEFUN|DEFUN_DLD|DEFUNX)\>',
                                    'lineanchors', 'once'));
  elseif (n > 2 && strcmpi (f((end-1):end), ".m"))
    retval = true;
  else
    retval = false;
  endif

endfunction

function retval = has_tests (f)
  fid = fopen (f);
  if (fid < 0)
    error ("runtests: fopen failed: %s", f);
  endif

  str = fread (fid, "*char").';
  fclose (fid);
  retval = ! isempty (regexp (str,
                              '^%!(assert|error|fail|test|xtest|warning)',
                              'lineanchors', 'once'));
endfunction

function print_pass_fail (r)
  if (r.n_test > 0)
    printf (" PASS   %4d/%-4d", r.n_pass, r.n_test);
    if (r.n_really_fail > 0)
      printf ("\n%71s %3d", "FAIL ", r.n_really_fail);
    endif
    if (r.n_regression > 0)
      printf ("\n%71s %3d", "REGRESSION", r.n_regression);
    endif
    if (r.n_xfail_bug > 0)
      printf ("\n%71s %3d", "(reported bug) XFAIL", n.xfail_bug);
    endif
    if (r.n_xfail > 0)
      printf ("\n%71s %3d", "(expected failure) XFAIL", r.n_xfail);
    endif
    if (r.n_skip_feature > 0)
      printf ("\n%71s %3d", "(missing feature) SKIP", r.n_skip_feature);
    endif
    if (r.n_skip_runtime > 0)
      printf ("\n%71s %3d", "(run-time condition) SKIP", r.n_skip_runtime);
    endif
  endif
  puts ("\n");
endfunction

function print_test_file_name (nm)
  filler = repmat (".", 1, 60-length (nm));
  printf ("  %s %s", nm, filler);
endfunction


%!error runtests ("foo", 1)
%!error <DIRECTORY argument> runtests ("#_TOTALLY_/_INVALID_/_PATHNAME_#")

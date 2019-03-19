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

## Work-in-progress refactoring of runtests2 to use testify.internal 
## objects

## -*- texinfo -*-
## @deftypefn  {} {} runtests2 ()
## @deftypefnx {} {} runtests2 (@var{directory})
## @deftypefnx {} {@var{success} =} runtests2 (@dots{})
## @deftypefnx {} {[@var{success}, @var{__info__}] =} runtests2 (@dots{})
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

function [p, __info__] = runtests2_refactor (directory)


  # Parse inputs and find tests

  runner = testify.internal.MultiBistRunner;
  if nargin == 0
    runner.add_stuff_on_octave_search_path;
  else
    tag = directory;
    directory = canonicalize_file_name(directory);
    if isempty (directory) || ! isfolder (directory)
      ## Search for directory name in path
      if directory(end) == '/' || directory(end) == '\'
        directory(end) = [];
      endif
      fullname = dir_in_loadpath (directory);
      if isempty (fullname)
        error ("runtests2: DIRECTORY argument must be a valid pathname");
      endif
      directory = fullname;
    endif
    runner.add_directory (directory, tag);
  endif

  # Run tests

  rslts = runner.run_tests;

  if nargout >= 1
    p = rslts.n_fail == 0;
  endif
  if nargout == 2
    __info__ = rslts;
  endif
endfunction



%!error runtests2 ("foo", 1)
%!error <DIRECTORY argument> runtests2 ("#_TOTALLY_/_INVALID_/_PATHNAME_#")

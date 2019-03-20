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

classdef BistRunResult
  %BISTRUNRESULT The aggregate result of running BIST tests on one or more files.
  
  properties
    % Count of total tests run
    n_test = 0
    % Count of tests that ran and passed
    n_pass = 0
    % Count of failures that were regressions
    n_regression = 0
    % Count of failures that were expected failures due to known, reported bugs
    n_xfail_bug = 0
    % Count of failures that were expected failures for other reasons
    n_xfail = 0
    % Count of tests that were skipped due to features that were not compiled in to this Octave
    n_skip_feature = 0
    % Count of tests that weres skipped due to run-time conditions
    n_skip_runtime = 0
    % List of files that were processed
    files_processed = {}
    % List of files that had tests (cellstr row vector)
    files_with_tests = {}
    % List of files with failed tests (cellstr row vector)
    failed_files = {}

    % Total elapsed wall time for test execution
    elapsed_wall_time = 0;
  endproperties
  
  properties (Dependent = true)
    % Count of tests that failed for any reason
    n_fail
    % Count of failures that were not xfails, skips, or regressions
    % n_really_fail = n_fail - n_skip - n_xfail - n_xfail_bug - n_regression
    n_really_fail
    % List of files that had no tests (cellstr row vector)
    files_with_no_tests
    % Count of tests that were skipped for any reason
    n_skip
  end
  
  methods
    function this = BistRunResult(varargin)
      %BISTRUNRESULT Construct a new BistRunResult
      %
      % BistRunResult ()
      % BistRunResult (npass, ntotal, nxfail, nxfailbug, nskipfeature, nskipruntime, nregression)
      % BistRunResult (npass, ntotal, nxfail, nxfailbug, nskipfeature, nskipruntime, nregression, failed_files)
      switch nargin
        case 0
          return
        case 7
          [np, n, nxf, nxb, nsk, nrtsk, nrgrs] = varargin{:};
          failed_files = {};
        case 8
          [np, n, nxf, nxb, nsk, nrtsk, nrgrs, failed_files] = varargin{:};
      endswitch
      if ! iscellstr (failed_files)
        error ('failed_files input must be a cellstr');
      endif
      this.n_test = n;
      this.n_pass = np;
      this.n_xfail = nxf;
      this.n_xfail_bug = nxb;
      this.n_skip_feature = nsk;
      this.n_skip_runtime = nrtsk;
      this.n_regression = nrgrs;
      this.failed_files = failed_files(:)';
    endfunction

    function out = get.n_fail (this)
      out = this.n_test - this.n_pass;
    endfunction
    
    function out = get.n_really_fail (this)
      out = this.n_fail - this.n_xfail - this.n_xfail_bug - this.n_regression;
    endfunction

    function out = get.n_skip (this)
      out = this.n_skip_feature + this.n_skip_runtime;
    endfunction

    function out = get.files_with_no_tests (this)
      out = setdiff (this.files_processed, this.files_with_tests);
    endfunction

    function this = add_failed_file (this, file)
      if ! ismember (file, this.failed_files)
        this.failed_files{end+1} = file;
      endif
    endfunction
    
    function out = plus(A, B)
      %PLUS Combine results
      %
      % Create a new BistRunResult that is the union/sum of its inputs. All the
      % count values are additive. The file lists are combined by setwise union.
      %
      % Returns a BistRunResult.
      klass = "testify.internal.BistRunResult";
      if ! isa (A, klass) || ! isa (B, klass)
        error ("Both inputs must be a %s; got a %s and a %s", ...
          klass, class (A), class (B));
      endif
      out = A;
      out.n_test = A.n_test + B.n_test;
      out.n_pass = A.n_pass + B.n_pass;
      out.n_regression = A.n_regression + B.n_regression;
      out.n_xfail_bug = A.n_xfail_bug + B.n_xfail_bug;
      out.n_xfail = A.n_xfail + B.n_xfail;
      out.n_skip_feature = A.n_skip_feature + B.n_skip_feature;
      out.n_skip_runtime = A.n_skip_runtime + B.n_skip_runtime;
      out.files_processed = unique([A.files_processed B.files_processed]);
      out.files_with_tests = unique([A.files_with_tests B.files_with_tests]);
      out.failed_files = unique([A.failed_files B.failed_files]);
      out.elapsed_wall_time = A.elapsed_wall_time + B.elapsed_wall_time;
    endfunction
    
    function disp (this)
      %DISP Custom display
      origWarn = warning;
      warning off Octave:classdef-to-struct
      s = builtin ('struct', this);
      fprintf ("%s:\n", class (this));
      disp (s);
      warning (origWarn);
      [txt,msg] = lastwarn;
    endfunction

    function prettyprint (this)
      %PRETTYPRINT Display human-readable representation
      disp (this);
    endfunction
  endmethods
  
endclassdef

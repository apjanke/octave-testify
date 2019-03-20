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

classdef BistResultsReporter

	properties
	  fid = stdout;
	endproperties

	methods
		function this = BistResultsReporter (fid)
		  if nargin == 0
		    return
		  endif
		endfunction

		function p (this, varargin)
		  fprintf (this.fid, varargin{:});
		endfunction

		function print_results_summary (this, rslts)
		  this.p ("\n");
		  this.p ("Summary:\n");
		  this.p ("\n");
		  hg_id = __octave_config_info__ ("hg_id");
		  this.p ("  GNU Octave Version: %s (hg id: %s)\n", OCTAVE_VERSION, hg_id);
		  host = testify.internal.Util.safe_hostname;
		  os_name = testify.internal.Util.os_name;
		  this.p ("  Tests run on %s (%s) at %s\n", host, os_name, datestr (now));
		  this.p ("  Execution time: %.0f s\n", rslts.elapsed_wall_time);
		  this.p ("\n");
		  this.p ("  %-30s %6d\n", "PASS", rslts.n_pass);
		  this.p ("  %-30s %6d\n", "FAIL", rslts.n_really_fail);
		  if (rslts.n_regression > 0)
		    this.p ("  %-30s %6d\n", "REGRESSION", rslts.n_regression);
		  endif
		  if (rslts.n_xfail_bug > 0)
		    this.p ("  %-30s %6d\n", "XFAIL (reported bug)", rslts.n_xfail_bug);
		  endif
		  if (rslts.n_xfail > 0)
		    this.p ("  %-30s %6d\n", "XFAIL (expected failure)", rslts.n_xfail);
		  endif
		  if (rslts.n_skip_feature > 0)
		    this.p ("  %-30s %6d\n", "SKIP (missing feature)", rslts.n_skip_feature);
		  endif
		  if (rslts.n_skip_runtime > 0)
		    this.p ("  %-30s %6d\n", "SKIP (run-time condition)", rslts.n_skip_runtime);
		  endif
		  if ! isempty (rslts.failed_files)
		    this.p ("\n");
		    this.p ("  Failed tests:\n");
		    for i = 1:numel (rslts.failed_files)
		      this.p ("     %s\n", rslts.failed_files{i});
		    endfor
		  endif
		  this.p ("\n");
		  if (rslts.n_xfail > 0 || rslts.n_xfail_bug > 0)
		    this.p ("\n");
		    this.p ("XFAIL items are known bugs or expected failures.\n");
		    this.p ("\nPlease help improve Octave by contributing fixes for them.\n");
		  endif
		  if (rslts.n_skip_feature > 0 || rslts.n_skip_runtime > 0)
		    this.p ("\n");
		    this.p ("Tests are often skipped because required features were\n");
		    this.p ("disabled or were not present when Octave was built.\n");
		    this.p ("The configure script should have printed a summary\n");
		    this.p ("indicating which dependencies were not found.\n");
		  endif

		  ## Weed out deprecated, legacy, and private functions
		  weed_pat = '\<deprecated\>|\<legacy\>|\<private\>';
		  files_with_tests = rslts.files_with_tests;
		  weed_idx = cellfun (@isempty, regexp (files_with_tests, weed_pat, 'once'));
		  files_with_tests = files_with_tests(weed_idx);
		  files_with_no_tests = rslts.files_with_no_tests;
		  weed_idx = cellfun (@isempty, regexp (files_with_no_tests, weed_pat, 'once'));
		  files_with_no_tests = files_with_no_tests(weed_idx);

		  ## TODO: Maybe include a section about files without tests here.

		endfunction

	endmethods

endclassdef


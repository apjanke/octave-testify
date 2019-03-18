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

classdef ForgePkgTester < handle
  %FORGEPKGTESTER Tests installation and BISTs of Forge packages
  %
  % This is a single-use object: create it and run one set of tests on it. If 
  % you want to run another test cycle, create a new object.
  
  properties (Constant)
    known_bad_pkgs_test_mac = {
      % Crashes Octave in test
      "control"
      % Crashes Octave in test
      "octproj"
      % Crashes Octave in test
      "quaternion"
    }';
    known_bad_pkgs_test_windows = {
      % Seems to crash Octave
      "control"
    };
    known_bad_pkgs_test_linux = {
      % Sometimes segfaults Octave in test
      "control"
      % Crashes Octave in test
      "level-set"
    };
    my_impl_pkgs  = {
      "testify"
      "doctest"
    }';
  endproperties

  properties
    ## User-settable properties
    % If true, run doctest tests on packages in addition to regular BISTs
    do_doctest = false;
  endproperties

  properties
    % Packages that fail bad enough in install to crash octave or junk up the tests
    known_bad_pkgs_install = {
      % Messes up the path somehow so the log is spammed with "load-path" warnings
      "fuzzy-logic-toolkit"
    };
    % Packages that fail bad enough in tests to crash octave
    known_bad_pkgs_test = {};
    % Pkgtool to do all Forge queries through
    pkgtool = testify.internal.ForgePkgTool.instance
    % Temp dir to hold output files
    output_dir
    % Subdir undir output_dir for the package build logs
    build_log_dir
    % Temp dir to run stuff in
    tmp_run_dir
    % The effective list of packages to test
    pkgs_to_test = {};
  endproperties
  
  properties
    ## Working/transient properties
    % Order to install packages and dependencies in
    install_order
    deps_installed_ok = {};
    dep_install_failures = {};
    skipped_pkgs_install = {};
    skipped_pkgs_test = {};
    tested_pkgs = {};
    install_failures = {};
    install_dependency_failures = {};
    test_passes = {};
    test_failures = {};
    test_elapsed_time = NaN;
    error_pkgs = {};
    file_droppings = {};
  endproperties
  
  properties (Dependent)
    % All packages installed as tested pkg or as dependency
    all_installed_pkgs
  endproperties
  
  methods
    function this = ForgePkgTester
      if ispc
        this.known_bad_pkgs_test = testify.internal.ForgePkgTester.known_bad_pkgs_test_windows;
      elseif ismac
        this.known_bad_pkgs_test = testify.internal.ForgePkgTester.known_bad_pkgs_test_mac;
      else        
        this.known_bad_pkgs_test = testify.internal.ForgePkgTester.known_bad_pkgs_test_linux;
      endif
      timestamp = datestr(now, "yyyy-mm-dd_HH-MM-SS");
      output_dir_base_name = ["octave-testify-ForgePkgTester-" timestamp];
      if isunix && ! ismac
        % Need to write to ~ to make results readily available under Flatpak
        forge_tester_out_dir = fullfile (getenv ("HOME"), "octave", "testify", "forge-tester");
        group_tmp_dir = forge_tester_out_dir;
      else
        tmp_dir_parent = "octave-testify-ForgePkgTester";
        group_tmp_dir = fullfile (tempdir, tmp_dir_parent);
      endif
      mkdir (group_tmp_dir);
      this.output_dir = fullfile (group_tmp_dir, output_dir_base_name);
      this.build_log_dir = fullfile (this.output_dir, "build-logs");
      this.tmp_run_dir = fullfile (tempdir, [output_dir_base_name "-run"]);
    endfunction
    
    function out = get.all_installed_pkgs (this)
      out = [this.tested_pkgs this.deps_installed_ok];
    endfunction

    function install_and_test_forge_pkgs (this)
      if (this.do_doctest)
        pkg ("load", "doctest");
      endif
      mkdir (this.output_dir);
      mkdir (this.build_log_dir);
      if isempty (this.pkgs_to_test)
        qualifier = "all";
        forge_pkgs = this.pkgtool.all_current_valid_forge_pkgs;
        this.pkgs_to_test = setdiff (forge_pkgs, this.known_bad_pkgs_install);
      else
        qualifier = "selected";
      endif
      log_file = fullfile (this.output_dir, "test_forge_pkgs.log");
      % Display log file at start so user can follow along in editor
      fprintf ("Log file: %s\n", log_file);
      fprintf ("\n");
      diary (log_file);
      diary on
      this.display_log_header;
      t0 = tic;
      unwind_protect
        say ("Testing %s Forge packages", qualifier);
        % Force ordering for consistency
        this.pkgs_to_test = sort (this.pkgs_to_test);
        say ("Testing packages: %s", strjoin(this.pkgs_to_test, " "));
        fprintf ("\n");
        % Compute safe install order
        this.install_order = this.pkgtool.install_order_with_deps (this.pkgs_to_test);
        say ("Install order (with deps): %s", strjoin(this.install_order, " "));
        fprintf ("\n");
        this.pkgtool.uninstall_all_pkgs_except (this.my_impl_pkgs);
        for i_pkg = 1:numel (this.install_order)
          pkg = this.install_order{i_pkg};
          if ismember (pkg, this.pkgs_to_test)
            this.install_and_test_forge_pkg (pkg);
          else
            % It's just a dependency
            this.install_dependency (pkg);
          endif
          flush_diary
        endfor
        this.pkgtool.uninstall_all_pkgs_except (this.my_impl_pkgs);
      unwind_protect_cleanup
        this.test_elapsed_time = toc (t0);
        this.display_results;
        diary off
        % Display log file again at end so it"s easy to find when test run finishes
        fprintf ("Log file: %s\n", log_file);
        fprintf ("\n");
      end_unwind_protect
    endfunction
    
    function out = find_file_droppings (this)
      d = dir;
      d([1 2]) = [];
      if isempty (d)
        out = {};
      else
        out = { d.name };
      endif
    endfunction

    function install_dependency (this, pkg_name)
      try
        t0 = tic;
        say ("Installing dependency: %s", pkg_name);
        this.pkgtool.pkg ("install", "-forge", pkg_name);
        te = toc (t0);
        say ("Package installed (dependency): %s. Elapsed time: %.1f s", pkg_name, te);
        this.deps_installed_ok{end+1} = pkg_name;
      catch err
        say ("Package install failure (dependency): %s: %s\n", pkg_name, err.message);
        this.dep_install_failures{end+1} = pkg_name;
      end_try_catch
    endfunction

    function install_and_test_forge_pkg (this, pkg_name)
      if exist (this.tmp_run_dir, "dir");
        rm_rf (this.tmp_run_dir);
      endif
      mkdir (this.tmp_run_dir);
      orig_pwd = pwd;
      unwind_protect
        cd (this.tmp_run_dir);
        try
          this = install_and_test_forge_pkg_unsafe (this, pkg_name);
        catch err
          % Internal error
          this.error_pkgs{end+1} = pkg_name;
        end_try_catch
      unwind_protect_cleanup
        this.tested_pkgs{end+1} = pkg_name;
        file_droppings = this.find_file_droppings;
        if ! isempty (file_droppings)
          fprintf ("\n");
          fprintf ("File droppings were left by %s:\n", pkg_name);
          for i = 1:numel (file_droppings)
            fprintf ("  %s\n", file_droppings{i});
          endfor
          fprintf ("\n");
        endif
        cd (orig_pwd);
        rm_rf (this.tmp_run_dir);
      end_unwind_protect
    endfunction
  
    function this = install_and_test_forge_pkg_unsafe (this, pkg_name)
      fprintf ("\n");
      pkg_ver = this.pkgtool.current_version_for_pkg (pkg_name);
      say ("Doing Forge package %s %s", pkg_name, pkg_ver);
      if ismember (pkg_name, this.known_bad_pkgs_install)
        say ("Skipping install of known-bad package %s", pkg_name);
        this.skipped_pkgs_install{end+1} = pkg_name;
        return
      endif
      % Check dependencies
      deps = this.pkgtool.recursive_dependencies_for_package (pkg_name);
      if ! isempty (deps)
        [tf, loc] = ismember (deps, this.all_installed_pkgs);
        if ! all (tf)
          % Uh oh, some dep didn't install
          [tf, loc] = ismember (deps, this.dep_install_failures);
          if any (tf)
            say ("Skipping package %s because of dependency install failures: %s", ...
              pkg_name, strjoin (deps(tf), " "));
          else
            say ("Skipping package %s because dependencies are missing for unknown reason: %s", ...
              pkg_name, strjoin (deps, " "));
          endif
          this.install_dependency_failures{end+1} = pkg_name;
          return
        endif
      endif
      % Install
      try
        say ("Installing Forge package %s", pkg_name);
        flush_diary
        installer = testify.internal.ForgePkgInstaller;
        t0 = tic;
        rslt = installer.install (pkg_name);
        te = toc (t0);
        pkg_build_log_dir = fullfile (this.build_log_dir, pkg_name);
        for i = 1:numel (rslt.log_dirs)
          contents = my_readdir (rslt.log_dirs{i});
          if isempty (contents)
            continue
          endif
          if ! exist (pkg_build_log_dir, "dir")
            mkdir (pkg_build_log_dir);
          endif
          copyfile (rslt.log_dirs{i}, pkg_build_log_dir);
        endfor
        if ! rslt.success
          error ("Package installation failed: %s. Error: %s", ...
            pkg_name, rslt.error_message);
        endif
        say ("Package installed: %s. Elapsed time: %.1f s", pkg_name, te);
      catch err
        say ("Error while installing package %s: %s", ...
          pkg_name, err.message);
        this.install_failures{end+1} = pkg_name;
        return;
      end_try_catch
      if ismember (pkg_name, this.known_bad_pkgs_test)
        say ("Skipping test of known-bad package %s", pkg_name);
        this.skipped_pkgs_test{end+1} = pkg_name;
        return
      endif
      % Test
      say ("Testing Forge package %s", pkg_name);
      nfailed = __test_pkgs__ (pkg_name, {"doctest", this.do_doctest});
      if nfailed > 0
        this.test_failures{end+1} = pkg_name;
      else
        this.test_passes{end+1} = pkg_name;
      endif
      flush_diary
    endfunction
    
    function out = my_safe_hostname (this)
      [status, host] = system ("hostname 2>/dev/null");
      if status == 0
        out = chomp (host);
      else
        % Yes, this might happen. E.g. hostname fails under Flatpak
        out = "unknown-host";
      endif
    endfunction

    function display_log_header (this)
      host = this.my_safe_hostname;
      fprintf ("Tests run on %s at %s\n", host, datestr (now));
      ver
      if ismac
        [status, sys_info] = system ("sw_vers");
        fprintf ("macOS System Info:\n");
        fprintf ("%s", sys_info);
        [status, xcode_info] = system ("xcodebuild -version");
        fprintf ("%s", xcode_info);
      endif
      if isunix && exist ("/etc/os-release", "file")
        txt = fileread ("/etc/os-release");
        fprintf ("Unix System Info (os-release):\n");
        fprintf ("%s", txt);
      endif
      if ispc
        [status, sys_info] = system ("systeminfo");
        if status == 0
          fprintf ("Windows System Info:\n");
          fprintf ("%s", sys_info);
        endif
      endif
      fprintf ("\n");
      fprintf ("Environment Variables:\n");
      env_var_displayer = testify.internal.EnvVarDisplayer;
      env_var_displayer.display_redacted_env_vars;
      fprintf ("\n");
      if isunix
        [status, lc_info] = system ("locale");
        fprintf ("Locale:\n");
        fprintf ("%s", lc_info);
        fprintf ("\n");
      endif
    endfunction

    function display_results (this)
      function print_pkgs_one_per_line (pkg_names)
        for i = 1:numel (pkg_names)
          fprintf ("  %s\n", pkg_names{i});
        endfor
      endfunction
      fprintf ("\n");
      fprintf ("\n");
      fprintf ("========  PACKAGE INSTALL AND TEST RESULTS  ========\n");
      fprintf ("\n");
      fprintf ("Tested %d packages in %s\n", ...
        numel (this.tested_pkgs), seconds_to_mmss (this.test_elapsed_time));
      fprintf ("Packages tested (%d): %s\n", numel (this.tested_pkgs), ...
        strjoin(this.tested_pkgs, " "));
      fprintf ("\n");
      if ! isempty (this.test_passes)
        fprintf ("Packages passed (%d):\n", numel (this.test_passes));
        fprintf ("  %s\n", strjoin (this.test_passes, " "));
        fprintf ("\n");
      endif
      if ! isempty (this.skipped_pkgs_install)
        fprintf ("Skipped known-bad packages (%d):\n", numel (this.skipped_pkgs_install));
        print_pkgs_one_per_line (this.skipped_pkgs_install);
        fprintf ("\n");
      endif
      if ! isempty (this.skipped_pkgs_test)
        fprintf ("Skipped tests on known-bad packages (%d):\n", numel (this.skipped_pkgs_test));
        print_pkgs_one_per_line (this.skipped_pkgs_test);
        fprintf ("\n");
      endif
      if isempty (this.install_failures) && isempty (this.install_dependency_failures);
        fprintf ("All packages installed OK.\n");
      else
        if ! isempty (this.install_dependency_failures)
          fprintf ("Packages with failed dependency installations (%d):\n", numel (this.install_dependency_failures));
          print_pkgs_one_per_line (this.install_dependency_failures);
          fprintf ("\n");
        endif
        if ! isempty (this.install_failures)
          fprintf ("Failed package installations (%d):\n", numel (this.install_failures));
          print_pkgs_one_per_line (this.install_failures);
          fprintf ("\n");
        endif
      endif
      if ! isempty (this.dep_install_failures)
        fprintf ("Failed dependency installations (%d):\n", numel (this.dep_install_failures));
        print_pkgs_one_per_line (this.dep_install_failures);
      endif
      if isempty (this.test_failures)
        fprintf ("All packages passed tests OK.\n");
      else
        fprintf ("Failed package tests (%d):\n", numel (this.test_failures));
        print_pkgs_one_per_line (this.test_failures);
      endif
      fprintf ("\n");
      if ! isempty (this.error_pkgs)
        fprintf ("Internal errors occurred for these packages:\n");
        print_pkgs_one_per_line (this.error_pkgs);
        fprintf ("\n");
      endif
    endfunction
  endmethods

endclassdef

function out = my_readdir (dir)
  out = readdir (dir);
  out(ismember (out, {"." ".."})) = [];
endfunction

function say (varargin)
  fprintf ("%s: %s\n", "testify.ForgePkgTester", sprintf (varargin{:}));
  flush_diary
endfunction

function flush_diary
  if diary
    diary off
    diary on
  endif
endfunction

function out = chomp (str)
  out = regexprep (str, "\r?\n$", "");
endfunction

function rm_rf (file)
  system (sprintf ('rm -rf "%s"', file));
endfunction

function out = seconds_to_mmss (sec)
  minutes = floor (sec / 60);
  seconds = round (sec - (minutes * 60));
  out = sprintf ("%02d:%02d", minutes, seconds);
endfunction

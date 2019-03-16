classdef ForgePkgTester
  %FORGEPKGTESTER Tests installation and BISTs of Forge packages
  %
  % This is a single-use object: create it and run one set of tests on it. If 
  % you want to run another test cycle, create a new object.
  
  properties (Constant)
    known_bad_pkgs_test_mac = {'control', 'octproj', 'quaternion'};
    known_bad_pkgs_test_windows = {};
    known_bad_pkgs_test_linux = {};
  endproperties

  properties
    pkgtool
    % Temp dir to hold output files
    tmp_dir
    build_log_dir
    % Temp dir to run stuff in
    tmp_run_dir
    % Overrides the list of packages to test
    pkgs_to_test = {};
    % Packages that fail bad enough in install to crash octave or junk up the tests
    known_bad_pkgs_install = {
      % Messes up the path somehow so the log is spammed with "load-path" warnings
      "fuzzy-logic-toolkit"
    };
    % Packages that fail bad enough in tests to crash octave
    known_bad_pkgs_test = {};
    skipped_pkgs_install = {};
    skipped_pkgs_test = {};
    tested_pkgs = {};
    install_failures = {};
    install_dependency_failures = {};
    test_failures = {};
    test_elapsed_time = NaN;
    error_pkgs = {};
    file_droppings = {};
  endproperties
  
  methods
    function this = ForgePkgTester
      if ispc
        this.known_bad_pkgs_test = testify.ForgePkgTester.known_bad_pkgs_test_windows;
      elseif ismac
        this.known_bad_pkgs_test = testify.ForgePkgTester.known_bad_pkgs_test_mac;
      else        
        this.known_bad_pkgs_test = testify.ForgePkgTester.known_bad_pkgs_test_linux;
      endif
      timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
      tmp_dir_name = ['octave-testify-ForgePkgTester-' timestamp];
      tmp_dir_parent = 'octave-testify-ForgePkgTester';
      group_tmp_dir = fullfile (tempdir, tmp_dir_parent);
      mkdir (group_tmp_dir);
      this.tmp_dir = fullfile (group_tmp_dir, tmp_dir_name);
      this.build_log_dir = fullfile (this.tmp_dir, 'build-logs');
      this.tmp_run_dir = fullfile (tempdir, [tmp_dir_name '-run']);
      this.pkgtool = testify.ForgePkgTool;
    endfunction

    function install_and_test_all_forge_pkgs (this)
      mkdir (this.tmp_dir);
      mkdir (this.build_log_dir);
      if isempty (this.pkgs_to_test)
        qualifier = 'all';
        forge_pkgs = pkg ('-forge', 'list');
        this.pkgs_to_test = setdiff (forge_pkgs, this.known_bad_pkgs_install);
      else
        qualifier = 'selected';
      endif
      log_file = fullfile (this.tmp_dir, 'test_all_forge_pkgs.log');
      % Display log file at start so user can follow along in editor
      fprintf ('Log file: %s\n', log_file);
      fprintf ('\n');
      diary (log_file);
      diary on
      this.display_log_header;
      t0 = tic;
      unwind_protect
        say ('Testing %s Forge packages', qualifier);
        pkgs_to_test = this.pkgs_to_test;
        % Sort for consistency
        pkgs_to_test = sort (pkgs_to_test);
        say ('Testing packages: %s', strjoin(pkgs_to_test, ' '));
        fprintf('\n');
        for i_pkg = 1:numel (pkgs_to_test)
          this = this.install_and_test_forge_pkg (pkgs_to_test{i_pkg});
          this.pkgtool.uninstall_all_pkgs_except ('testify');
          flush_diary
        endfor
      unwind_protect_cleanup
        this.test_elapsed_time = toc (t0);
        this.display_results;
        diary off
        % Display log file again at end so it's easy to find when test run finishes
        fprintf ('Log file: %s\n', log_file);
        fprintf ('\n');
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

    function this = install_and_test_forge_pkg (this, pkg_name)
      if exist (this.tmp_run_dir, 'dir');
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
        try
          file_droppings = this.find_file_droppings;
          if ! isempty (file_droppings)
            fprintf ('\n');
            fprintf ('File droppings were left by %s:\n', pkg_name);
            for i = 1:numel (file_droppings)
              fprintf ('  %s\n', file_droppings{i});
            endfor
            fprintf ('\n');
          endif
        catch err
          fprintf ('Error while detecting file droppings: %s\n', err.message);
        end_try_catch
        cd (orig_pwd);
        rm_rf (this.tmp_run_dir);
      end_unwind_protect
    endfunction
  
    function this = install_and_test_forge_pkg_unsafe (this, pkg_name)
      fprintf ('\n');
      pkg_ver = this.pkgtool.current_version_for_pkg (pkg_name);
      say ('Doing Forge package %s %s', pkg_name, pkg_ver);
      if ismember (pkg_name, this.known_bad_pkgs_install)
        say ('Skipping install of known-bad package %s', pkg_name);
        this.skipped_pkgs_install{end+1} = pkg_name;
        return
      endif
      deps = this.pkgtool.recursive_dependencies_for_package (pkg_name);
      this.pkgtool.uninstall_all_pkgs_except ({'testify'});
      if ! isempty (deps)
        try
          t0 = tic;
          say ('Installing dependencies for %s: %s', pkg_name, strjoin (deps, ' '));
          this.pkgtool.pkg ('install', '-forge', deps{:});
          te = toc (t0);
          say ('Package installed (dependencies): %s. Elapsed time: %.1f s', pkg_name, te);
        catch err
          say ('Error while installing package dependencies for %s: %s', ...
            pkg_name, err.message);
          this.install_dependency_failures{end+1} = pkg_name;
          return;
        end_try_catch
      endif
      try
        say ('Installing Forge package %s', pkg_name);
        flush_diary
        installer = testify.ForgePkgInstaller;
        t0 = tic;
        rslt = installer.install (pkg_name);
        te = toc (t0);
        pkg_build_log_dir = fullfile (this.build_log_dir, pkg_name);
        for i = 1:numel (rslt.log_dirs)
          contents = my_readdir (rslt.log_dirs{i});
          if isempty (contents)
            continue
          endif
          if ! exist (pkg_build_log_dir, 'dir')
            mkdir (pkg_build_log_dir);
          endif
          copyfile (rslt.log_dirs{i}, pkg_build_log_dir);
        endfor
        if ! rslt.success
          error ('Package installation failed: %s. Error: %s', ...
            pkg_name, rslt.error_message);
        endif
        say ('Package installed: %s. Elapsed time: %.1f s', pkg_name, te);
      catch err
        say ('Error while installing package %s: %s', ...
          pkg_name, err.message);
        this.install_failures{end+1} = pkg_name;
        return;
      end_try_catch
      if ismember (pkg_name, this.known_bad_pkgs_test)
        say ('Skipping test of known-bad package %s', pkg_name);
        this.skipped_pkgs_test{end+1} = pkg_name;
        return
      endif
      say ('Testing Forge package %s', pkg_name);
      try
        nfailed = __test_pkgs__ (pkg_name);
        if nfailed > 0
          this.test_failures{end+1} = pkg_name;
        endif
      catch err
        say ('Error while testing package %s: %s', ...
          pkg_name, err.message);
        this.test_failures{end+1} = pkg_name;
        return;        
      end_try_catch
      flush_diary
    endfunction
    
    function display_log_header (this)
      [status, host] = system ('hostname');
      host = chomp (host);
      fprintf ('Tests run on %s at %s\n', host, datestr (now));
      ver
      if ismac
        [status, sys_info] = system ('sw_vers');
        fprintf ('macOS System Info:\n');
        fprintf ('%s', sys_info);
        [status, xcode_info] = system ('xcodebuild -version');
        fprintf ('%s', xcode_info);
      endif
      fprintf ('\n');
      fprintf ('Environment Variables:\n');
      env_var_displayer = testify.EnvVarDisplayer;
      env_var_displayer.display_redacted_env_vars;
      fprintf ('\n');
      if isunix
        [status, lc_info] = system ('locale');
        fprintf ('Locale:\n');
        fprintf ('%s', lc_info);
        fprintf ('\n');
      endif
    endfunction

    function display_results (this)
      function print_pkgs_one_per_line (pkg_names)
        for i = 1:numel (pkg_names)
          fprintf ('  %s\n', pkg_names{i});
        endfor
      endfunction
      fprintf ('\n');
      fprintf ('\n');
      fprintf ('========  PACKAGE INSTALL AND TEST RESULTS  ========\n');
      fprintf ('\n');
      fprintf ('Tested %d packages in %.1f s\n', ...
        numel (this.tested_pkgs), this.test_elapsed_time);
      fprintf ('Packages tested: %s\n', strjoin(this.tested_pkgs, ' '));
      fprintf ('\n');
      if ! isempty (this.skipped_pkgs_install)
        fprintf ('Skipped known-bad packages:\n');
        print_pkgs_one_per_line (this.skipped_pkgs_install);
        fprintf ('\n');
      endif
      if ! isempty (this.skipped_pkgs_test)
        fprintf ('Skipped tests on known-bad packages:\n');
        print_pkgs_one_per_line (this.skipped_pkgs_test);
        fprintf ('\n');
      endif
      if isempty (this.install_failures) && isempty (this.install_dependency_failures);
        fprintf ('All packages installed OK.\n');
      else
        if ! isempty (this.install_dependency_failures)
          fprintf ('Packages with failed dependency installations:\n');
          print_pkgs_one_per_line (this.install_dependency_failures);
          fprintf ('\n');
        endif
        if ! isempty (this.install_failures)
          fprintf ('Failed package installations:\n');
          print_pkgs_one_per_line (this.install_failures);
          fprintf ('\n');
        endif
      endif
      if isempty (this.test_failures)
        fprintf ('All packages passed tests OK.\n');
      else
        fprintf ('Failed package tests:\n');
        print_pkgs_one_per_line (this.test_failures);
      endif
      fprintf ('\n');
      if ! isempty (this.error_pkgs)
        fprintf ('Internal errors occurred for these packages:\n');
        print_pkgs_one_per_line (this.error_pkgs);
        fprintf ('\n');
      endif
    endfunction
  endmethods

endclassdef

function out = my_readdir (dir)
  out = readdir (dir);
  out(ismember (out, {'.' '..'})) = [];
endfunction

function say (varargin)
  fprintf ('%s: %s\n', 'testify.ForgePkgTester', sprintf (varargin{:}));
  flush_diary
endfunction

function flush_diary
  if diary
    diary off
    diary on
  endif
endfunction

function out = chomp (str)
  out = regexprep (str, '\r?\n$', '');
endfunction

function rm_rf (file)
  system (sprintf ('rm -rf "%s"', file));
endfunction

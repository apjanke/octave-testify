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

classdef ForgePkgTool < handle
  
  properties
    tmp_dir = fullfile (tempdir, "octave-testify-ForgePkgTool");
    download_cache_dir = fullfile (testify.internal.Util.testify_data_dir, ...
      "download-cache", "octave-forge");
    dependency_cache = cell (0, 2);
    known_bogus_forge_pkgs = { 
      % Shows up in pkg -forge list but is not actually on Forge
      "odepkg"
      % Depends on nonexistent package "odepkg"
      "ocs"
      };
    forge = packajoozle.internal.OctaveForgeClient;
  endproperties
  
  methods (Static)
    function out = instance
      %INSTANCE A shared persistent instance, useful for caching
      persistent val
      if isempty (val)
        val = testify.internal.ForgePkgTool;
      endif
      out = val;
    endfunction
  endmethods

  methods
    function this = ForgePkgTool ()
      [ok, msg] = mkdir (this.download_cache_dir);
      if ! ok
        error ('ForgePkgTool: Could not create cache dir %s: %s', ...
          this.download_cache_dir, msg);
      endif
    endfunction

    function pkj (this, varargin)
      say ("%s %s", "pkj", strjoin (varargin, " "));
      pkj (varargin{:});
    endfunction
    
    function out = tmpdir (this)
      if ! exist (this.tmp_dir, "dir")
        mkdir (this.tmp_dir);
      endif
      out = this.tmp_dir;
    endfunction

    function uninstall_all_pkgs_except (this, exclusions)
      exclusions = cellstr (exclusions);
      pkg_list = pkj ("list");
      installed_pkgs = cellfun(@(s) { s.name }, pkg_list);
      to_uninstall = setdiff (installed_pkgs, exclusions);
      if ! isempty (to_uninstall)
        this.pkj ("unload", to_uninstall{:});
        this.pkj ("uninstall", to_uninstall{:});
      end
    endfunction
    
    function out = recursive_dependencies_for_package (this, pkg_name)
      direct_deps = this.direct_dependencies_for_package (pkg_name);
      out = direct_deps;
      for i = 1:numel (direct_deps)
        out = [out this.recursive_dependencies_for_package(direct_deps{i})];
      endfor
      out = unique (out);
    endfunction

    function out = direct_dependencies_for_package (this, pkg_name)
      pkgver = packajoozle.internal.PkgVer (pkg_name, ...
        this.forge.get_current_pkg_version (pkg_name));
      descr = this.forge.get_package_description_meta (pkgver);
      if isempty (descr.depends)
        deps = {};
      else
        deps = cellfun(@(s) {s.package}, descr.depends);
      endif
      deps = setdiff (deps, {"octave"});
      out = deps;
    endfunction
    
    function out = all_current_valid_forge_pkgs (this)
      listed = pkj ("-forge", "list");
      out = setdiff (listed, this.known_bogus_forge_pkgs);
    endfunction

    function out = current_version_for_pkg (this, pkg_name)
      out = this.forge.get_current_pkg_version (pkg_name);
    endfunction

    function out = install_order_with_deps (this, pkgs)
      pkgman = packajoozle.internal.PkgManager;
      resolver = packajoozle.internal.DependencyResolver (pkgman.forge);
      vers = cell (size (pkgs));
      pkgvers = cell (size (pkgs));
      for i = 1:numel (pkgs)
        vers{i} = this.forge.get_current_pkg_version (pkgs{i});
        pkgvers{i} = packajoozle.internal.PkgVer (pkgs{i}, vers{i});
      endfor
      pkgvers = packajoozle.internal.Util.objcatc (pkgvers);
      res = resolver.resolve_deps (pkgvers);
      out = {res.resolved.name};
    endfunction
    
  endmethods
endclassdef

function say (varargin)
  fprintf ('%s: %s\n', 'testify.ForgePkgTool', sprintf (varargin{:}));
  testify.internal.Util.flush_diary
endfunction

function rm_rf (file)
  testify.internal.Util.rm_rf (file);
endfunction

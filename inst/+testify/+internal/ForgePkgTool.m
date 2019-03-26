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
    tmp_dir = tempname (tempdir, "octave/testify/ForgePkgTool/run-");
    download_cache_dir = fullfile (testify.internal.Util.testify_data_dir, ...
      "download-cache", "octave-forge");
    dependency_cache = cell (0, 2);
    known_bogus_forge_pkgs = { 
      % Shows up in pkg -forge list but is not actually on Forge
      "odepkg"
      % Depends on nonexistent package "odepkg"
      "ocs"
      };
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

    function pkg (this, varargin)
      say ("%s %s", "pkg", strjoin (varargin, " "));
      pkg (varargin{:});
    endfunction
    
    function out = tmpdir (this)
      if ! exist (this.tmp_dir, "dir")
        mkdir (this.tmp_dir);
      endif
      out = this.tmp_dir;
    endfunction

    function uninstall_all_pkgs_except (this, exclusions)
      exclusions = cellstr (exclusions);
      pkg_list = pkg ("list");
      installed_pkgs = cellfun(@(s) { s.name }, pkg_list);
      to_uninstall = setdiff (installed_pkgs, exclusions);
      if ! isempty (to_uninstall)
        this.pkg ("unload", to_uninstall{:});
        this.pkg ("uninstall", to_uninstall{:});
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

    function out = basename (this, file)
      ix = find (file == filesep, 1, "last");
      if isempty (ix)
        out = file;
      else
        out = file(ix+1:end);
      endif
    endfunction

    function out = download_pkg_file (this, pkg_name)
      [url, local_file] = this.get_forge_download (pkg_name);
      local_basename = this.basename (local_file);
      cached_file = fullfile (this.download_cache_dir, local_basename);
      out = cached_file;
      if exist (cached_file, "file")
        return
      endif
      say ("Downloading %s from %s to %s", pkg_name, url, cached_file);
      urlwrite (url, cached_file);
    endfunction

    function clear_download_cache (this)
      rm_rf (this.download_cache_dir);
      mkdir (this.download_cache_dir);
    endfunction
  
    function out = direct_dependencies_for_package (this, pkg_name)
      ## Check cache
      [tf, loc] = ismember (pkg_name, this.dependency_cache(:,1));
      if tf
        # say ("dep cache hit: %s", pkg_name);
        out = this.dependency_cache{loc,2};
        return
      endif
      ## Cache miss: get from Forge
      # say ("dep cache miss: %s", pkg_name);
      local_file = this.download_pkg_file (pkg_name);
      tgz = local_file;
      extract_dir = tempname;
      mkdir (extract_dir);
      ## Uncompress the package.
      [~, base_name, ext] = fileparts (tgz);
      if (strcmpi (ext, ".zip"))
        func_uncompress = @unzip;
      else
        func_uncompress = @untar;
        % Handle double ".tar.gz" file extension
        base_name = regexprep (base_name, "\.tar$", "");
      endif
      func_uncompress (tgz, extract_dir);
      ## Get the name of the directories produced by tar.
      [dirlist, err, msg] = readdir (extract_dir);
      if (err)
        error ("couldn't read directory produced by tar: %s", msg);
      endif
      if (length (dirlist) > 3)
        error ("bundles of packages are not allowed");
      endif
      pkg_src_dir = dirlist{3};
      
      description_file = fullfile (extract_dir, pkg_src_dir, "DESCRIPTION");
      descr = this.get_description (description_file);
      if isempty (descr.depends)
        deps = {};
      else
        deps = cellfun(@(s) {s.package}, descr.depends);
      endif
      deps = setdiff (deps, {"octave"});
      out = deps;
      this.dependency_cache = [this.dependency_cache; {pkg_name deps}];
    endfunction
    
    function out = all_current_valid_forge_pkgs (this)
      listed = pkg ("-forge", "list");
      out = setdiff (listed, this.known_bogus_forge_pkgs);
    endfunction

    function out = current_version_for_pkg (this, pkg_name)
      [out, url] = this.get_forge_pkg (pkg_name);
    endfunction
    
    function out = install_order_with_deps (this, pkgs)
      %ORDER_DEPS Calculate an in-dependency-order ordering for package installs
      %
      % out = order_deps (this, pkgs)
      %
      % pkgs (cellstr) is a list of names of Octave Forge packages to install.
      %
      % Returns a struct with fields:
      %   prereqs - List of other packages to install before the input pkgs. Order
      %             is not significant.
      %   install_order - Order in which pkgs should be installed. Order is
      %             significant.
      pkgs = cellstr (pkgs);
      requested = pkgs;
      install_order = {};
      path = {};

      function step (pkg_name)
        # fprintf ("\n");
        # fprintf ("step: %s\n", pkg_name);
        # fprintf ("path: %s\n", strjoin (path, " "));
        # fprintf ("install_order: %s\n", strjoin (install_order, " "));
        # fprintf ("requested: %s\n", strjoin (requested, " "));       
        if ismember (pkg_name, install_order)
          # fprintf ("already in install order: %s. skipping.\n", pkg_name);
          return
        endif
        if ismember (pkg_name, path)
          error ("ForgePkgTool: Oh, crap! Dependency cycle detected: %s:", ...
            strjoin ([path {pkg_name}], " -> "));
        endif
        path{end+1} = pkg_name;
        deps = this.direct_dependencies_for_package (pkg_name);
        for i = 1:numel (deps)
          dep = deps{i};
          # fprintf ("dep %d: %s\n", i, dep);
          if ismember (dep, install_order)
            continue
          endif
          step (dep);
        endfor
        [tf, loc] = ismember (pkg_name, requested);
        requested(loc(tf)) = [];
        install_order{end+1} = pkg_name;
        path(end) = [];
      endfunction

      while ! isempty (requested)
        [next_pkg, requested] = deal (requested{1}, requested(2:end));
        # fprintf ("requested is not empty. next_pkg = %s\n", next_pkg);
        step (next_pkg);
      endwhile
      out = install_order;
    endfunction
  endmethods

  methods  
    % Methods grabbed from Octave's pkg/private

    function [url, local_file] = get_forge_download (this, name)
      [ver, url] = this.get_forge_pkg (name);
      base_file = [name "-" ver ".tar.gz"];
      local_file = fullfile (this.tmpdir, base_file);      
    endfunction
  
    function [ver, url] = get_forge_pkg (this, name)

      ## Verify that name is valid.
      if (! (ischar (name) && rows (name) == 1 && ndims (name) == 2))
        error ("get_forge_pkg: package NAME must be a string");
      elseif (! all (isalnum (name) | name == "-" | name == "." | name == "_"))
        error ("get_forge_pkg: invalid package NAME: %s", name);
      endif

      name = tolower (name);

      ## Try to download package's index page.
      [html, succ] = urlread (sprintf ("https://packages.octave.org/%s/index.html",
                                       name));
      if (succ)
        ## Remove blanks for simpler matching.
        html(isspace(html)) = [];
        ## Good.  Let's grep for the version.
        pat = "<tdclass=""package_table"">PackageVersion:</td><td>([\\d.]*)</td>";
        t = regexp (html, pat, "tokens");
        if (isempty (t) || isempty (t{1}))
          error ("get_forge_pkg: could not read version number from package's page");
        else
          ver = t{1}{1};
          if (nargout > 1)
            ## Build download string.
            pkg_file = sprintf ("%s-%s.tar.gz", name, ver);
            url = ["https://packages.octave.org/download/" pkg_file];
            ## Verify that the package string exists on the page.
            if (isempty (strfind (html, pkg_file)))
              warning ("get_forge_pkg: download URL not verified");
            endif
          endif
        endif
      else
        ## Try get the list of all packages.
        [html, succ] = urlread ("https://packages.octave.org/list_packages.php");
        if (! succ)
          error ("get_forge_pkg: could not read URL, please verify internet connection");
        endif
        t = strsplit (html);
        if (any (strcmp (t, name)))
          error ("get_forge_pkg: package NAME exists, but index page not available");
        endif
        ## Try a simplistic method to determine similar names.
        function d = fdist (x)
          len1 = length (name);
          len2 = length (x);
          if (len1 <= len2)
            d = sum (abs (name(1:len1) - x(1:len1))) + sum (x(len1+1:end));
          else
            d = sum (abs (name(1:len2) - x(1:len2))) + sum (name(len2+1:end));
          endif
        endfunction
        dist = cellfun ("fdist", t);
        [~, i] = min (dist);
        error ("get_forge_pkg: package not found: ""%s"".  Maybe you meant ""%s?""",
               name, t{i});
      endif

    endfunction

    function desc = get_description (this, filename)

      [fid, msg] = fopen (filename, "r");
      if (fid == -1)
        error ("the DESCRIPTION file %s could not be read: %s", filename, msg);
      endif

      desc = struct ();

      line = fgetl (fid);
      while (line != -1)
        if (line(1) == "#")
          ## Comments, do nothing.
        elseif (isspace (line(1)))
          ## Continuation lines
          if (exist ("keyword", "var") && isfield (desc, keyword))
            desc.(keyword) = [desc.(keyword) " " deblank(line)];
          endif
        else
          ## Keyword/value pair
          colon = find (line == ":");
          if (length (colon) == 0)
            warning ("pkg: skipping invalid line in DESCRIPTION file %s", filename);
          else
            colon = colon(1);
            keyword = tolower (strtrim (line(1:colon-1)));
            value = strtrim (line (colon+1:end));
            if (length (value) == 0)
                fclose (fid);
                error ("The keyword '%s' of the package '%s' has an empty value",
                        keyword, desc.name);
            endif
            if (isfield (desc, keyword))
              warning ('pkg: duplicate keyword "%s" in DESCRIPTION, ignoring',
                       keyword);
            else
              desc.(keyword) = value;
            endif
          endif
        endif
        line = fgetl (fid);
      endwhile
      fclose (fid);

      ## Make sure all is okay.
      needed_fields = {"name", "version", "date", "title", ...
                       "author", "maintainer", "description"};
      for f = needed_fields
        if (! isfield (desc, f{1}))
          error ("description is missing needed field %s", f{1});
        endif
      endfor

      if (! this.is_valid_pkg_version_string (desc.version))
        error ("invalid version string '%s'", desc.version);
      endif

      if (isfield (desc, "depends"))
        desc.depends = this.fix_depends (desc.depends);
      else
        desc.depends = "";
      endif
      desc.name = tolower (desc.name);

    endfunction


    ## Make sure the depends field is of the right format.
    ## This function returns a cell of structures with the following fields:
    ##   package, version, operator
    function deps_cell = fix_depends (this, depends)

      deps = strtrim (ostrsplit (tolower (depends), ","));
      deps_cell = cell (1, length (deps));
      dep_pat = ...
      '\s*(?<name>[-\w]+)\s*(\(\s*(?<op>[<>=]+)\s*(?<ver>\d+\.\d+(\.\d+)*)\s*\))*\s*';

      ## For each dependency.
      for i = 1:length (deps)
        dep = deps{i};
        [start, nm] = regexp (dep, dep_pat, 'start', 'names');
        ## Is the dependency specified
        ## in the correct format?
        if (! isempty (start))
          package = tolower (strtrim (nm.name));
          ## Does the dependency specify a version
          ## Example: package(>= version).
          if (! isempty (nm.ver))
            operator = nm.op;
            if (! any (strcmp (operator, {">", ">=", "<=", "<", "=="})))
              error ("unsupported operator: %s", operator);
            endif
            if (! this.is_valid_pkg_version_string (nm.ver))
              error ("invalid dependency version string '%s'", nm.ver);
            endif
          else
            ## If no version is specified for the dependency
            ## we say that the version should be greater than
            ## or equal to "0.0.0".
            package = tolower (strtrim (dep));
            operator = ">=";
            nm.ver  = "0.0.0";
          endif
          deps_cell{i} = struct ("package", package,
                                 "operator", operator,
                                 "version", nm.ver);
        else
          error ("incorrect syntax for dependency '%s' in the DESCRIPTION file\n",
                 dep);
        endif
      endfor

    endfunction

    function valid = is_valid_pkg_version_string (this, str)
      ## We are limiting ourselves to this set of characters because the
      ## version will appear on the filepath.  The portable character, according to
      ## http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_278
      ## is [A-Za-z0-9\.\_\-].  However, this is very limited.  We specially
      ## want to support a "+" so we can support "pkgname-2.1.0+" during
      ## development.  So we use Debian's character set for version strings
      ## https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version
      ## with the exception of ":" (colon) because that's the PATH separator.
      ##
      ## Debian does not include "_" because it is used to separate the name,
      ## version, and arch in their deb files.  While the actual filenames are
      ## never parsed to get that information, it is important to have a unique
      ## separator character to prevent filename clashes.  For example, if we
      ## used hyhen as separator, "signal-2-1-rc1" could be "signal-2" version
      ## "1-rc1" or "signal" version "2-1-rc1".  A package file for both must be
      ## able to co-exist in the same directory, e.g., during package install or
      ## in a flat level package repository.
      valid = numel (regexp (str, '[^0-9a-zA-Z\.\+\-\~]')) == 0;
    endfunction
  endmethods

endclassdef

function say (varargin)
  fprintf ('%s: %s\n', 'testify.ForgePkgTool', sprintf (varargin{:}));
  flush_diary
endfunction

function flush_diary
  if diary
    diary off
    diary on
  endif
endfunction

function rm_rf (file)
  system (sprintf ('rm -rf "%s"', file));
endfunction

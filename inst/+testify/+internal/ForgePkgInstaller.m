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

classdef ForgePkgInstaller
  %FORGEPKGINSTALLER Enhanced replacement for `pkg install`
  
  % The implementation code here was grabbed from the "default" development
  % branch for Octave 6.0 as of changeset 26929:3e6aa7c7bbbb on March 16,
  % 2019. It may not be compatible with other versions of Octave.
  
  methods
    function out = install (this, varargin)
      %INSTALL Replacement for `pkg -forge install`
      %
      % This is a replacement for `pkg -forge install` that does the same thing, except
      % it also:
      %   * Captures build logs
      args = cellstr (varargin);
      install_args = [{'install' '-forge'} args];
      say (strjoin (install_args, ' '));
      result = pkg_install (install_args{:});
      out = result;
    endfunction
  endmethods
  
endclassdef

function say (varargin)
  fprintf ('%s: %s\n', 'testify.ForgePkgInstaller', sprintf (varargin{:}));
  flush_diary
endfunction

function flush_diary
  if diary
    diary off
    diary on
  endif
endfunction

function spew (out_file, txt)
  [fid, msg] = fopen (out_file, 'w');
  if fid < 0
    error ('Failed opening file for writing:\n  File: %s\n  Error: %s', ...
      out_file, msg);
  endif
  fwrite (fid, txt);
  fclose (fid);
endfunction

% ======================================================
%
% Code copied from Octave's pkg/pkg.m

function out = pkg_install (varargin)
  % Parse inputs
  ## Installation prefix (FIXME: what should these be on windows?)
  persistent user_prefix = false;
  persistent prefix = false;
  persistent archprefix = -1;
  % I had to hack this to make it work with Octave.app -apjanke
  persistent local_list = pkg ('local_list');
  persistent global_list = pkg ('global_list');

  ## If user is superuser set global_istall to true
  ## FIXME: is it OK to set this always true on windows?
  global_install = ((ispc () && ! isunix ()) || (geteuid () == 0));

  if (isbool (prefix))
    [prefix, archprefix] = default_prefix (global_install);
    prefix = tilde_expand (prefix);
    archprefix = tilde_expand (archprefix);
  endif

  mlock ();

  confirm_recursive_rmdir (false, "local");

  # valid actions in alphabetical order
  available_actions = {"build", "describe", "global_list",  "install", ...
                       "list", "load", "local_list", "prefix", "rebuild", ...
                       "uninstall", "unload", "update"};

  ## Parse input arguments
  if (isempty (varargin) || ! iscellstr (varargin))
    print_usage ();
  endif
  files = {};
  deps = true;
  action = "none";
  verbose = false;
  octave_forge = false;
  for i = 1:numel (varargin)
    switch (varargin{i})
      case "-nodeps"
        deps = false;
      case "-verbose"
        verbose = true;
        ## Send verbose output to pager immediately.  Change setting locally.
        page_output_immediately (true, "local");
      case "-forge"
        if (! __octave_config_info__ ("CURL_LIBS"))
          error ("pkg: can't download from Octave Forge without the cURL library");
        endif
        octave_forge = true;
      case "-local"
        global_install = false;
        if (! user_prefix)
          [prefix, archprefix] = default_prefix (global_install);
        endif
      case "-global"
        global_install = true;
        if (! user_prefix)
          [prefix, archprefix] = default_prefix (global_install);
        endif
      case available_actions
        if (! strcmp (action, "none"))
          error ("pkg: more than one action specified");
        endif
        action = varargin{i};
      otherwise
        files{end+1} = varargin{i};
    endswitch
  endfor

  if ! isequal (action, "install")
    error ("This implementation only supports the 'install' action; not '%s'", action);
  endif
  if ! octave_forge
    error ("This implementation only supports -forge actions");
  endif

  % Take action  
  if (isempty (files))
    error ("pkg: install action requires at least one filename");
  endif

  local_files = {};
  tmp_dir = tempname ();
  unwind_protect
    [urls, local_files] = cellfun ("get_forge_download", files,
                                   "uniformoutput", false);
    [files, succ] = cellfun ("urlwrite", urls, local_files,
                             "uniformoutput", false);
    succ = [succ{:}];
    if (! all (succ))
      i = find (! succ, 1);
      error ("pkg: could not download file %s from url %s",
             local_files{i}, urls{i});
    endif
    rslt = install_private_impl (files, deps, prefix, archprefix, verbose, local_list,
             global_list, global_install);
    out.log_dirs = rslt.log_dirs;
    out.success = rslt.success;
    out.error_message = rslt.error_message;
    out.exception = rslt.exception;
  unwind_protect_cleanup
    cellfun ("unlink", local_files);
    if (exist (tmp_dir, "file"))
      rmdir (tmp_dir, "s");
    endif
  end_unwind_protect
endfunction

% ======================================================
%
% Functions copied from Octave's pkg/private/install.m


function out = install_private_impl (files, handle_deps, prefix, archprefix, verbose,
                  local_list, global_list, global_install)
  % INSTALL_PRIVATE_IMPL
  %
  % Returns struct with fields:
  %   success (boolean)
  %   log_dirs (cellstr)
  %   error_message (char)
  %   exception (MException)
  %
  % log_dirs is populated and valid even if success is false.
  %
  % May still throw an error in some cases for lower-level or early errors.

  out = struct;
  out.success = true;
  out.log_dirs = {};
  out.error_message = '';
  out.exception = [];

  ## Check that the directory in prefix exist.  If it doesn't: create it!
  if (! isfolder (prefix))
    warning ("creating installation directory %s", prefix);
    [status, msg] = mkdir (prefix);
    if (status != 1)
      error ("could not create installation directory: %s", msg);
    endif
  endif

  ## Get the list of installed packages.
  [local_packages, global_packages] = installed_packages (local_list,
                                                          global_list);

  installed_pkgs_lst = {local_packages{:}, global_packages{:}};

  if (global_install)
    packages = global_packages;
  else
    packages = local_packages;
  endif

  ## Uncompress the packages and read the DESCRIPTION files.
  tmpdirs = packdirs = descriptions = {};
  try
    ## Warn about non existent files.
    for i = 1:length (files)
      if (isempty (glob (files{i})))
        warning ("file %s does not exist", files{i});
      endif
    endfor

    ## Unpack the package files and read the DESCRIPTION files.
    files = glob (files);
    packages_to_uninstall = [];
    for i = 1:length (files)
      tgz = files{i};

      if (exist (tgz, "file"))
        ## Create a temporary directory.
        tmpdir = tempname ();
        tmpdirs{end+1} = tmpdir;
        if (verbose)
          printf ("mkdir (%s)\n", tmpdir);
        endif
        [status, msg] = mkdir (tmpdir);
        if (status != 1)
          error ("couldn't create temporary directory: %s", msg);
        endif

        ## Uncompress the package.
        [~, ~, ext] = fileparts (tgz);
        if (strcmpi (ext, ".zip"))
          func_uncompress = @unzip;
        else
          func_uncompress = @untar;
        endif
        if (verbose)
          printf ("%s (%s, %s)\n", func2str (func_uncompress), tgz, tmpdir);
        endif
        func_uncompress (tgz, tmpdir);

        ## Get the name of the directories produced by tar.
        [dirlist, err, msg] = readdir (tmpdir);
        if (err)
          error ("couldn't read directory produced by tar: %s", msg);
        endif

        if (length (dirlist) > 3)
          error ("bundles of packages are not allowed");
        endif
      endif

      ## The filename pointed to an uncompressed package to begin with.
      if (isfolder (tgz))
        dirlist = {".", "..", tgz};
      endif

      if (exist (tgz, "file") || isfolder (tgz))
        ## The two first entries of dirlist are "." and "..".
        if (exist (tgz, "file"))
          packdir = fullfile (tmpdir, dirlist{3});
        else
          packdir = fullfile (pwd (), dirlist{3});
        endif
        packdirs{end+1} = packdir;

        ## Make sure the package contains necessary files.
        verify_directory (packdir);

        ## Read the DESCRIPTION file.
        filename = fullfile (packdir, "DESCRIPTION");
        desc = get_description (filename);

        ## Set default installation directory.
        desc.dir = fullfile (prefix, [desc.name "-" desc.version]);

        ## Set default architectire dependent installation directory.
        desc.archprefix = fullfile (archprefix, [desc.name "-" desc.version]);

        ## Save desc.
        descriptions{end+1} = desc;

        ## Are any of the new packages already installed?
        ## If so we'll remove the old version.
        for j = 1:length (packages)
          if (strcmp (packages{j}.name, desc.name))
            packages_to_uninstall(end+1) = j;
          endif
        endfor
      endif
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Check dependencies.
  if (handle_deps)
    ok = true;
    error_text = "";
    for i = 1:length (descriptions)
      desc = descriptions{i};
      idx2 = setdiff (1:length (descriptions), i);
      if (global_install)
        ## Global installation is not allowed to have dependencies on locally
        ## installed packages.
        idx1 = setdiff (1:length (global_packages), packages_to_uninstall);
        pseudo_installed_packages = {global_packages{idx1}, ...
                                     descriptions{idx2}};
      else
        idx1 = setdiff (1:length (local_packages), packages_to_uninstall);
        pseudo_installed_packages = {local_packages{idx1}, ...
                                     global_packages{:}, ...
                                     descriptions{idx2}};
      endif
      bad_deps = get_unsatisfied_deps (desc, pseudo_installed_packages);
      ## Are there any unsatisfied dependencies?
      if (! isempty (bad_deps))
        ok = false;
        for i = 1:length (bad_deps)
          dep = bad_deps{i};
          error_text = [error_text " " desc.name " needs " ...
                        dep.package " " dep.operator " " dep.version "\n"];
        endfor
      endif
    endfor

    ## Did we find any unsatisfied dependencies?
    if (! ok)
      error ("the following dependencies were unsatisfied:\n  %s", error_text);
    endif
  endif

  ## Prepare each package for installation.
  try
    for i = 1:length (descriptions)
      desc = descriptions{i};
      pdir = packdirs{i};
      prepare_installation (desc, pdir);
      rslt = configure_make (desc, pdir, verbose);
      out.log_dirs{end+1} = rslt.log_dir;
      if ! rslt.success
        out.success = false;
        out.error_message = rslt.error_message;
        out.exception = rslt.exception;
        return;
      endif
      copy_built_files (desc, pdir, verbose);
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Uninstall the packages that will be replaced.
  try
    for i = packages_to_uninstall
      if (global_install)
        uninstall ({global_packages{i}.name}, false, verbose, local_list,
                   global_list, global_install);
      else
        uninstall ({local_packages{i}.name}, false, verbose, local_list,
                   global_list, global_install);
      endif
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      rmdir (tmpdirs{i}, "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Install each package.
  try
    for i = 1:length (descriptions)
      desc = descriptions{i};
      pdir = packdirs{i};
      copy_files (desc, pdir, global_install);
      create_pkgadddel (desc, pdir, "PKG_ADD", global_install);
      create_pkgadddel (desc, pdir, "PKG_DEL", global_install);
      finish_installation (desc, pdir, global_install);
      generate_lookfor_cache (desc);
    endfor
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      rmdir (tmpdirs{i}, "s");
    endfor
    for i = 1:length (descriptions)
      rmdir (descriptions{i}.dir, "s");
      rmdir (getarchdir (descriptions{i}), "s");
    endfor
    rethrow (lasterror ());
  end_try_catch

  ## Check if the installed directory is empty.  If it is remove it
  ## from the list.
  for i = length (descriptions):-1:1
    if (dirempty (descriptions{i}.dir, {"packinfo", "doc"})
        && dirempty (getarchdir (descriptions{i})))
      warning ("package %s is empty\n", descriptions{i}.name);
      rmdir (descriptions{i}.dir, "s");
      rmdir (getarchdir (descriptions{i}), "s");
      descriptions(i) = [];
    endif
  endfor

  ## Add the packages to the package list.
  try
    if (global_install)
      idx = setdiff (1:length (global_packages), packages_to_uninstall);
      global_packages = save_order ({global_packages{idx}, descriptions{:}});
      save (global_list, "global_packages");
      installed_pkgs_lst = {local_packages{:}, global_packages{:}};
    else
      idx = setdiff (1:length (local_packages), packages_to_uninstall);
      local_packages = save_order ({local_packages{idx}, descriptions{:}});
      save (local_list, "local_packages");
      installed_pkgs_lst = {local_packages{:}, global_packages{:}};
    endif
  catch
    ## Something went wrong, delete tmpdirs.
    for i = 1:length (tmpdirs)
      rmdir (tmpdirs{i}, "s");
    endfor
    for i = 1:length (descriptions)
      rmdir (descriptions{i}.dir, "s");
    endfor
    if (global_install)
      printf ("error: couldn't append to %s\n", global_list);
    else
      printf ("error: couldn't append to %s\n", local_list);
    endif
    rethrow (lasterror ());
  end_try_catch

  ## All is well, let's clean up.
  for i = 1:length (tmpdirs)
    [status, msg] = rmdir (tmpdirs{i}, "s");
    if (status != 1 && isfolder (tmpdirs{i}))
      warning ("couldn't clean up after my self: %s\n", msg);
    endif
  endfor

  ## If there is a NEWS file, mention it.
  ## Check if desc exists too because it's possible to get to this point
  ## without creating it such as giving an invalid filename for the package
  if (exist ("desc", "var")
      && exist (fullfile (desc.dir, "packinfo", "NEWS"), "file"))
    printf (["For information about changes from previous versions " ...
             "of the %s package, run 'news %s'.\n"],
            desc.name, desc.name);
  endif

endfunction


function pkg = extract_pkg (nm, pat)

  fid = fopen (nm, "rt");
  pkg = "";
  if (fid >= 0)
    while (! feof (fid))
      ln = fgetl (fid);
      if (ln > 0)
        t = regexp (ln, pat, "tokens");
        if (! isempty (t))
          pkg = [pkg "\n" t{1}{1}];
        endif
      endif
    endwhile
    if (! isempty (pkg))
      pkg = [pkg "\n"];
    endif
    fclose (fid);
  endif

endfunction


## Make sure the package contains the essential files.
function verify_directory (dir)

  needed_files = {"COPYING", "DESCRIPTION"};
  for f = needed_files
    if (! exist (fullfile (dir, f{1}), "file"))
      error ("package is missing file: %s", f{1});
    endif
  endfor

endfunction


function prepare_installation (desc, packdir)

  ## Is there a pre_install to call?
  if (exist (fullfile (packdir, "pre_install.m"), "file"))
    wd = pwd ();
    try
      cd (packdir);
      pre_install (desc);
      cd (wd);
    catch
      cd (wd);
      rethrow (lasterror ());
    end_try_catch
  endif

  ## If the directory "inst" doesn't exist, we create it.
  inst_dir = fullfile (packdir, "inst");
  if (! isfolder (inst_dir))
    [status, msg] = mkdir (inst_dir);
    if (status != 1)
      rmdir (desc.dir, "s");
      error ("the 'inst' directory did not exist and could not be created: %s",
             msg);
    endif
  endif

endfunction


function copy_built_files (desc, packdir, verbose)

  src = fullfile (packdir, "src");
  if (! isfolder (src))
    return
  endif

  ## Copy files to "inst" and "inst/arch" (this is instead of 'make install').
  files = fullfile (src, "FILES");
  instdir = fullfile (packdir, "inst");
  archdir = fullfile (packdir, "inst", getarch ());

  ## Get filenames.
  if (exist (files, "file"))
    [fid, msg] = fopen (files, "r");
    if (fid < 0)
      error ("couldn't open %s: %s", files, msg);
    endif
    filenames = char (fread (fid))';
    fclose (fid);
    if (filenames(end) == "\n")
      filenames(end) = [];
    endif
    filenames = strtrim (ostrsplit (filenames, "\n"));
    delete_idx = [];
    for i = 1:length (filenames)
      if (! all (isspace (filenames{i})))
        filenames{i} = fullfile (src, filenames{i});
      else
        delete_idx(end+1) = i;
      endif
    endfor
    filenames(delete_idx) = [];
  else
    m = dir (fullfile (src, "*.m"));
    oct = dir (fullfile (src, "*.oct"));
    mex = dir (fullfile (src, "*.mex"));

    filenames = cellfun (@(x) fullfile (src, x),
                         {m.name, oct.name, mex.name},
                         "uniformoutput", false);
  endif

  ## Split into architecture dependent and independent files.
  if (isempty (filenames))
    idx = [];
  else
    idx = cellfun ("is_architecture_dependent", filenames);
  endif
  archdependent = filenames(idx);
  archindependent = filenames(! idx);

  ## Copy the files.
  if (! all (isspace ([filenames{:}])))
      if (! isfolder (instdir))
        mkdir (instdir);
      endif
      if (! all (isspace ([archindependent{:}])))
        if (verbose)
          printf ("copyfile");
          printf (" %s", archindependent{:});
          printf ("%s\n", instdir);
        endif
        [status, output] = copyfile (archindependent, instdir);
        if (status != 1)
          rmdir (desc.dir, "s");
          error ("Couldn't copy files from 'src' to 'inst': %s", output);
        endif
      endif
      if (! all (isspace ([archdependent{:}])))
        if (verbose)
          printf ("copyfile");
          printf (" %s", archdependent{:});
          printf (" %s\n", archdir);
        endif
        if (! isfolder (archdir))
          mkdir (archdir);
        endif
        [status, output] = copyfile (archdependent, archdir);
        if (status != 1)
          rmdir (desc.dir, "s");
          error ("Couldn't copy files from 'src' to 'inst': %s", output);
        endif
      endif
  endif

endfunction


function dep = is_architecture_dependent (nm)
  persistent archdepsuffix = {".oct",".mex",".a",".lib",".so",".so.*",".dll","dylib"};

  dep = false;
  for i = 1 : length (archdepsuffix)
    ext = archdepsuffix{i};
    if (ext(end) == "*")
      isglob = true;
      ext(end) = [];
    else
      isglob = false;
    endif
    pos = strfind (nm, ext);
    if (pos)
      if (! isglob && (length (nm) - pos(end) != length (ext) - 1))
        continue;
      endif
      dep = true;
      break;
    endif
  endfor

endfunction


function copy_files (desc, packdir, global_install)

  ## Create the installation directory.
  if (! isfolder (desc.dir))
    [status, output] = mkdir (desc.dir);
    if (status != 1)
      error ("couldn't create installation directory %s : %s",
      desc.dir, output);
    endif
  endif

  octfiledir = getarchdir (desc);

  ## Copy the files from "inst" to installdir.
  instdir = fullfile (packdir, "inst");
  if (! dirempty (instdir))
    [status, output] = copyfile (fullfile (instdir, "*"), desc.dir);
    if (status != 1)
      rmdir (desc.dir, "s");
      error ("couldn't copy files to the installation directory");
    endif
    if (isfolder (fullfile (desc.dir, getarch ()))
        && ! strcmp (canonicalize_file_name (fullfile (desc.dir, getarch ())),
                     canonicalize_file_name (octfiledir)))
      if (! isfolder (octfiledir))
        ## Can be required to create up to three levels of dirs.
        octm1 = fileparts (octfiledir);
        if (! isfolder (octm1))
          octm2 = fileparts (octm1);
          if (! isfolder (octm2))
            octm3 = fileparts (octm2);
            if (! isfolder (octm3))
              [status, output] = mkdir (octm3);
              if (status != 1)
                rmdir (desc.dir, "s");
                error ("couldn't create installation directory %s : %s",
                       octm3, output);
              endif
            endif
            [status, output] = mkdir (octm2);
            if (status != 1)
              rmdir (desc.dir, "s");
              error ("couldn't create installation directory %s : %s",
                     octm2, output);
            endif
          endif
          [status, output] = mkdir (octm1);
          if (status != 1)
            rmdir (desc.dir, "s");
            error ("couldn't create installation directory %s : %s",
                   octm1, output);
          endif
        endif
        [status, output] = mkdir (octfiledir);
        if (status != 1)
          rmdir (desc.dir, "s");
          error ("couldn't create installation directory %s : %s",
          octfiledir, output);
        endif
      endif
      [status, output] = movefile (fullfile (desc.dir, getarch (), "*"),
                                   octfiledir);
      rmdir (fullfile (desc.dir, getarch ()), "s");

      if (status != 1)
        rmdir (desc.dir, "s");
        rmdir (octfiledir, "s");
        error ("couldn't copy files to the installation directory");
      endif
    endif

  endif

  ## Create the "packinfo" directory.
  packinfo = fullfile (desc.dir, "packinfo");
  [status, msg] = mkdir (packinfo);
  if (status != 1)
    rmdir (desc.dir, "s");
    rmdir (octfiledir, "s");
    error ("couldn't create packinfo directory: %s", msg);
  endif

  packinfo_copy_file ("DESCRIPTION", "required", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("COPYING", "required", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("CITATION", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("NEWS", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("ONEWS", "optional", packdir, packinfo, desc, octfiledir);
  packinfo_copy_file ("ChangeLog", "optional", packdir, packinfo, desc, octfiledir);

  ## Is there an INDEX file to copy or should we generate one?
  index_file = fullfile (packdir, "INDEX");
  if (exist (index_file, "file"))
    packinfo_copy_file ("INDEX", "required", packdir, packinfo, desc, octfiledir);
  else
    try
      write_index (desc, fullfile (packdir, "inst"),
                   fullfile (packinfo, "INDEX"), global_install);
    catch
      rmdir (desc.dir, "s");
      rmdir (octfiledir, "s");
      rethrow (lasterror ());
    end_try_catch
  endif

  ## Is there an 'on_uninstall.m' to install?
  packinfo_copy_file ("on_uninstall.m", "optional", packdir, packinfo, desc, octfiledir);

  ## Is there a doc/ directory that needs to be installed?
  docdir = fullfile (packdir, "doc");
  if (isfolder (docdir) && ! dirempty (docdir))
    [status, output] = copyfile (docdir, desc.dir);
  endif

  ## Is there a bin/ directory that needs to be installed?
  ## FIXME: Need to treat architecture dependent files in bin/
  bindir = fullfile (packdir, "bin");
  if (isfolder (bindir) && ! dirempty (bindir))
    [status, output] = copyfile (bindir, desc.dir);
  endif

endfunction


function packinfo_copy_file (filename, requirement, packdir, packinfo, desc, octfiledir)

  filepath = fullfile (packdir, filename);
  if (! exist (filepath, "file") && strcmpi (requirement, "optional"))
    ## do nothing, it's still OK
  else
    [status, output] = copyfile (filepath, packinfo);
    if (status != 1)
      rmdir (desc.dir, "s");
      rmdir (octfiledir, "s");
      error ("Couldn't copy %s file: %s", filename, output);
    endif
  endif

endfunction


## Create an INDEX file for a package that doesn't provide one.
##   'desc'  describes the package.
##   'dir'   is the 'inst' directory in temporary directory.
##   'index_file' is the name (including path) of resulting INDEX file.
function write_index (desc, dir, index_file, global_install)

  ## Get names of functions in dir
  [files, err, msg] = readdir (dir);
  if (err)
    error ("couldn't read directory %s: %s", dir, msg);
  endif

  ## Get classes in dir
  class_idx = find (strncmp (files, '@', 1));
  for k = 1:length (class_idx)
    class_name = files {class_idx(k)};
    class_dir = fullfile (dir, class_name);
    if (isfolder (class_dir))
      [files2, err, msg] = readdir (class_dir);
      if (err)
        error ("couldn't read directory %s: %s", class_dir, msg);
      endif
      files2 = strcat (class_name, filesep (), files2);
      files = [files; files2];
    endif
  endfor

  ## Check for architecture dependent files.
  tmpdir = getarchdir (desc);
  if (isfolder (tmpdir))
    [files2, err, msg] = readdir (tmpdir);
    if (err)
      error ("couldn't read directory %s: %s", tmpdir, msg);
    endif
    files = [files; files2];
  endif

  functions = {};
  for i = 1:length (files)
    file = files{i};
    lf = length (file);
    if (lf > 2 && strcmp (file(end-1:end), ".m"))
      functions{end+1} = file(1:end-2);
    elseif (lf > 4 && strcmp (file(end-3:end), ".oct"))
      functions{end+1} = file(1:end-4);
    endif
  endfor

  ## Does desc have a categories field?
  if (! isfield (desc, "categories"))
    error ("the DESCRIPTION file must have a Categories field, when no INDEX file is given");
  endif
  categories = strtrim (strsplit (desc.categories, ","));
  if (length (categories) < 1)
    error ("the Category field is empty");
  endif

  ## Write INDEX.
  fid = fopen (index_file, "w");
  if (fid == -1)
    error ("couldn't open %s for writing", index_file);
  endif
  fprintf (fid, "%s >> %s\n", desc.name, desc.title);
  fprintf (fid, "%s\n", categories{1});
  fprintf (fid, "  %s\n", functions{:});
  fclose (fid);

endfunction


function create_pkgadddel (desc, packdir, nm, global_install)

  instpkg = fullfile (desc.dir, nm);
  instfid = fopen (instpkg, "at"); # append to support PKG_ADD at inst/
  ## If it is exists, most of the PKG_* file should go into the
  ## architecture dependent directory so that the autoload/mfilename
  ## commands work as expected.  The only part that doesn't is the
  ## part in the main directory.
  archdir = fullfile (getarchprefix (desc, global_install),
                      [desc.name "-" desc.version], getarch ());
  if (isfolder (getarchdir (desc, global_install)))
    archpkg = fullfile (getarchdir (desc, global_install), nm);
    archfid = fopen (archpkg, "at");
  else
    archpkg = instpkg;
    archfid = instfid;
  endif

  if (archfid >= 0 && instfid >= 0)
    ## Search all dot-m files for PKG commands.
    lst = glob (fullfile (packdir, "inst", "*.m"));
    for i = 1:length (lst)
      nam = lst{i};
      fwrite (instfid, extract_pkg (nam, ['^[#%][#%]* *' nm ': *(.*)$']));
    endfor

    ## Search all C++ source files for PKG commands.
    cc_lst = glob (fullfile (packdir, "src", "*.cc"));
    cpp_lst = glob (fullfile (packdir, "src", "*.cpp"));
    cxx_lst = glob (fullfile (packdir, "src", "*.cxx"));
    lst = [cc_lst; cpp_lst; cxx_lst];
    for i = 1:length (lst)
      nam = lst{i};
      fwrite (archfid, extract_pkg (nam, ['^//* *' nm ': *(.*)$']));
      fwrite (archfid, extract_pkg (nam, ['^/\** *' nm ': *(.*) *\*/$']));
    endfor

    ## Add developer included PKG commands.
    packdirnm = fullfile (packdir, nm);
    if (exist (packdirnm, "file"))
      fid = fopen (packdirnm, "rt");
      if (fid >= 0)
        while (! feof (fid))
          ln = fgets (fid);
          if (ln > 0)
            fwrite (archfid, ln);
          endif
        endwhile
        fclose (fid);
      endif
    endif

    ## If the files is empty remove it.
    fclose (instfid);
    t = dir (instpkg);
    if (t.bytes <= 0)
      unlink (instpkg);
    endif

    if (instfid != archfid)
      fclose (archfid);
      t = dir (archpkg);
      if (t.bytes <= 0)
        unlink (archpkg);
      endif
    endif
  endif

endfunction


function archprefix = getarchprefix (desc, global_install)

  if (global_install)
    [~, archprefix] = default_prefix (global_install, desc);
  else
    archprefix = desc.dir;
  endif

endfunction


function finish_installation (desc, packdir, global_install)

  ## Is there a post-install to call?
  if (exist (fullfile (packdir, "post_install.m"), "file"))
    wd = pwd ();
    try
      cd (packdir);
      post_install (desc);
      cd (wd);
    catch
      cd (wd);
      rmdir (desc.dir, "s");
      rmdir (getarchdir (desc), "s");
      rethrow (lasterror ());
    end_try_catch
  endif

endfunction


function generate_lookfor_cache (desc)

  dirs = strtrim (ostrsplit (genpath (desc.dir), pathsep ()));
  for i = 1 : length (dirs)
    doc_cache_create (fullfile (dirs{i}, "doc-cache"), dirs{i});
  endfor

endfunction

% ======================================================
%
% Other functions copied from Octave's pkg/private


function out = configure_make (desc, packdir, verbose)
  % Returns struct with fields:
  %  success (boolean)
  %  log_dir (char)
  %  error_message (char)
  %  exception (MException or [])
  %
  % log_dir will still be populated and valid even if success is false.

  timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
  tmp_dir_name = ['octave-testify-ForgePkgInstaller-' timestamp];
  log_dir = fullfile (tempdir, tmp_dir_name);
  mkdir (log_dir);
  out.log_dir = log_dir;
  out.success = true;
  out.error_message = '';
  out.exception = [];
  
  try
    ## Perform ./configure, make, make install in "src".
    if (isfolder (fullfile (packdir, "src")))
      src = fullfile (packdir, "src");
      octave_bindir = __octave_config_info__ ("bindir");
      ver = version ();
      ext = __octave_config_info__ ("EXEEXT");
      mkoctfile_program = fullfile (octave_bindir, ...
                                    sprintf ("mkoctfile-%s%s", ver, ext));
      octave_config_program = fullfile (octave_bindir, ...
                                        sprintf ("octave-config-%s%s", ver, ext));
      if (ispc () && ! isunix ())
        octave_binary = fullfile (octave_bindir, sprintf ("octave-%s.bat", ver));
      else
        octave_binary = fullfile (octave_bindir, sprintf ("octave-%s%s", ver, ext));
      endif

      if (! exist (mkoctfile_program, "file"))
        __gripe_missing_component__ ("pkg", "mkoctfile");
      endif
      if (! exist (octave_config_program, "file"))
        __gripe_missing_component__ ("pkg", "octave-config");
      endif
      if (! exist (octave_binary, "file"))
        __gripe_missing_component__ ("pkg", "octave");
      endif

      if (verbose)
        mkoctfile_program = [mkoctfile_program " --verbose"];
      endif

      cenv = {"MKOCTFILE"; mkoctfile_program;
              "OCTAVE_CONFIG"; octave_config_program;
              "OCTAVE"; octave_binary};
      scenv = sprintf ("%s='%s' ", cenv{:});

      ## Configure.
      if (exist (fullfile (src, "configure"), "file"))
        flags = "";
        if (isempty (getenv ("CC")))
          flags = [flags ' CC="' mkoctfile("-p", "CC") '"'];
        endif
        if (isempty (getenv ("CXX")))
          flags = [flags ' CXX="' mkoctfile("-p", "CXX") '"'];
        endif
        if (isempty (getenv ("AR")))
          flags = [flags ' AR="' mkoctfile("-p", "AR") '"'];
        endif
        if (isempty (getenv ("RANLIB")))
          flags = [flags ' RANLIB="' mkoctfile("-p", "RANLIB") '"'];
        endif
        cmd = ["cd '" src "'; " scenv "./configure " flags];
        [status, output] = shell (cmd, verbose);
        spew (fullfile (log_dir, 'configure.log'), output);
        if (status != 0)
          rmdir (desc.dir, "s");
          disp (output);
          error ("pkg: error running the configure script for %s.", desc.name);
        endif
      endif

      ## Make.
      if (ispc ())
        jobs = 1;
      else
        jobs = nproc ("overridable");
      endif

      if (exist (fullfile (src, "Makefile"), "file"))
        [status, output] = shell (sprintf ("%s make --jobs %i --directory '%s'",
                                           scenv, jobs, src), verbose);
        spew (fullfile (log_dir, 'make.log'), output);
        if (status != 0)
          rmdir (desc.dir, "s");
          disp (output);
          error ("pkg: error running `make' for the %s package.", desc.name);
        endif
      endif
    endif
  catch err
    out.success = false;
    out.error_message = err.message;
    out.exception = err;
  end_try_catch
endfunction

## Executes a shell command.
## In the end it calls system(), but in the case of MS Windows it will first
## check if sh.exe works.
##
## If VERBOSE is true, it will prints the output to STDOUT in real time and
## the second output argument will be an empty string.  Otherwise, it will
## contain the output of the execeuted command.
function [status, output] = shell (cmd, verbose)
  persistent have_sh;

  cmd = strrep (cmd, '\', '/');
  if (ispc () && ! isunix ())
    if (isempty (have_sh))
      if (system ('sh.exe -c "exit"'))
        have_sh = false;
      else
        have_sh = true;
      endif
    endif
    if (have_sh)
      cmd = ['sh.exe -c "' cmd '"'];
    else
      error ("pkg: unable to find the command shell.");
    endif
  endif
  if isunix
    cmd = [cmd ' 2>&1'];
  endif
  ## TODO: Figure out how to capture stderr on Windows
  [status, output] = system (cmd);
endfunction


function [prefix, archprefix] = default_prefix (global_install, desc)
  if (global_install)
    prefix = fullfile (OCTAVE_HOME (), "share", "octave", "packages");
    if (nargin == 2)
      archprefix = fullfile (__octave_config_info__ ("libdir"), "octave",
                             "packages", [desc.name "-" desc.version]);
    else
      archprefix = fullfile (__octave_config_info__ ("libdir"), "octave",
                             "packages");
    endif
  else
    % This is hacked to respect 'pkg prefix'; I dunno why it's not working internally.
    [prefix, archprefix] = pkg ('prefix');
  endif
endfunction

function [url, local_file] = get_forge_download (name)
  [ver, url] = get_forge_pkg (name);
  local_file = [name "-" ver ".tar.gz"];
endfunction

function [ver, url] = get_forge_pkg (name)

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

function [out1, out2] = installed_packages (local_list, global_list, pkgname = {})

  ## Get the list of installed packages.
  try
    local_packages = load (local_list).local_packages;
  catch
    local_packages = {};
  end_try_catch
  try
    global_packages = load (global_list).global_packages;
  catch
    global_packages = {};
  end_try_catch
  installed_pkgs_lst = {local_packages{:}, global_packages{:}};

  ## Eliminate duplicates in the installed package list.
  ## Locally installed packages take precedence.
  installed_names = cellfun (@(x) x.name, installed_pkgs_lst,
                             "uniformoutput", false);
  [~, idx] = unique (installed_names, "first");
  installed_names = installed_names(idx);
  installed_pkgs_lst = installed_pkgs_lst(idx);

  ## Check whether info on a particular package was requested
  if (! isempty (pkgname))
    idx = find (strcmp (pkgname{1}, installed_names));
    if (isempty (idx))
      installed_names = {};
      installed_pkgs_lst = {};
    else
      installed_names = installed_names(idx);
      installed_pkgs_lst = installed_pkgs_lst(idx);
    endif
  endif

  ## Now check if the package is loaded.
  ## FIXME: Couldn't dir_in_loadpath() be used here?
  tmppath = strrep (path (), '\', '/');
  for i = 1:numel (installed_pkgs_lst)
    if (strfind (tmppath, strrep (installed_pkgs_lst{i}.dir, '\', '/')))
      installed_pkgs_lst{i}.loaded = true;
    else
      installed_pkgs_lst{i}.loaded = false;
    endif
  endfor
  for i = 1:numel (local_packages)
    if (strfind (tmppath, strrep (local_packages{i}.dir, '\', '/')))
      local_packages{i}.loaded = true;
    else
      local_packages{i}.loaded = false;
    endif
  endfor
  for i = 1:numel (global_packages)
    if (strfind (tmppath, strrep (global_packages{i}.dir, '\', '/')))
      global_packages{i}.loaded = true;
    else
      global_packages{i}.loaded = false;
    endif
  endfor

  ## Should we return something?
  if (nargout == 1)
    out1 = installed_pkgs_lst;
  elseif (nargout > 1)
    out1 = local_packages;
    out2 = global_packages;
  else
    ## Don't return anything, instead we'll print something.
    num_packages = numel (installed_pkgs_lst);
    if (num_packages == 0)
      if (isempty (pkgname))
        printf ("no packages installed.\n");
      else
        printf ("package %s is not installed.\n", pkgname{1});
      endif
      return;
    endif

    ## Compute the maximal lengths of name, version, and dir.
    h1 = "Package Name";
    h2 = "Version";
    h3 = "Installation directory";
    max_name_length = max ([length(h1), cellfun(@length, installed_names)]);
    version_lengths = cellfun (@(x) length (x.version), installed_pkgs_lst);
    max_version_length = max ([length(h2), version_lengths]);
    ncols = terminal_size ()(2);
    max_dir_length = ncols - max_name_length - max_version_length - 7;
    if (max_dir_length < 20)
      max_dir_length = Inf;
    endif

    h1 = postpad (h1, max_name_length + 1, " ");
    h2 = postpad (h2, max_version_length, " ");;

    ## Print a header.
    header = sprintf ("%s | %s | %s\n", h1, h2, h3);
    printf (header);
    tmp = sprintf (repmat ("-", 1, length (header) - 1));
    tmp(length(h1)+2) = "+";
    tmp(length(h1)+length(h2)+5) = "+";
    printf ("%s\n", tmp);

    ## Print the packages.
    format = sprintf ("%%%ds %%1s| %%%ds | %%s\n",
                      max_name_length, max_version_length);
    for i = 1:num_packages
      cur_name = installed_pkgs_lst{i}.name;
      cur_version = installed_pkgs_lst{i}.version;
      cur_dir = installed_pkgs_lst{i}.dir;
      if (length (cur_dir) > max_dir_length)
        first_char = length (cur_dir) - max_dir_length + 4;
        first_filesep = strfind (cur_dir(first_char:end), filesep ());
        if (! isempty (first_filesep))
          cur_dir = ["..." cur_dir((first_char + first_filesep(1) - 1):end)];
        else
          cur_dir = ["..." cur_dir(first_char:end)];
        endif
      endif
      if (installed_pkgs_lst{i}.loaded)
        cur_loaded = "*";
      else
        cur_loaded = " ";
      endif
      printf (format, cur_name, cur_loaded, cur_version, cur_dir);
    endfor
  endif

endfunction

## Parse the DESCRIPTION file.
function desc = get_description (filename)

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
        warning ("pkg: skipping invalid line in DESCRIPTION file");
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

  if (! is_valid_pkg_version_string (desc.version))
    error ("invalid version string '%s'", desc.version);
  endif

  if (isfield (desc, "depends"))
    desc.depends = fix_depends (desc.depends);
  else
    desc.depends = "";
  endif
  desc.name = tolower (desc.name);

endfunction


## Make sure the depends field is of the right format.
## This function returns a cell of structures with the following fields:
##   package, version, operator
function deps_cell = fix_depends (depends)

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
        if (! is_valid_pkg_version_string (nm.ver))
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

function valid = is_valid_pkg_version_string (str)
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

function bad_deps = get_unsatisfied_deps (desc, installed_pkgs_lst)

  bad_deps = {};

  ## For each dependency.
  for i = 1:length (desc.depends)
    dep = desc.depends{i};

    ## Is the current dependency Octave?
    if (strcmp (dep.package, "octave"))
      if (! compare_versions (OCTAVE_VERSION, dep.version, dep.operator))
        bad_deps{end+1} = dep;
      endif
      ## Is the current dependency not Octave?
    else
      ok = false;
      for i = 1:length (installed_pkgs_lst)
        cur_name = installed_pkgs_lst{i}.name;
        cur_version = installed_pkgs_lst{i}.version;
        if (strcmp (dep.package, cur_name)
            && compare_versions (cur_version, dep.version, dep.operator))
          ok = true;
          break;
        endif
      endfor
      if (! ok)
        bad_deps{end+1} = dep;
      endif
    endif
  endfor
endfunction

function arch = getarch ()
  persistent _arch = [__octave_config_info__("canonical_host_type"), "-", ...
                      __octave_config_info__("api_version")];

  arch = _arch;
endfunction

function archdir = getarchdir (desc)
  archdir = fullfile (desc.archprefix, getarch ());
endfunction

function emp = dirempty (nm, ign)
  if (isfolder (nm))
    if (nargin < 2)
      ign = {".", ".."};
    else
      ign = [{".", ".."}, ign];
    endif
    l = dir (nm);
    for i = 1:length (l)
      found = false;
      for j = 1:length (ign)
        if (strcmp (l(i).name, ign{j}))
          found = true;
          break;
        endif
      endfor
      if (! found)
        emp = false;
        return;
      endif
    endfor
    emp = true;
  else
    emp = true;
  endif
endfunction

function newdesc = save_order (desc)

  newdesc = {};
  for i = 1 : length (desc)
    deps = desc{i}.depends;
    if (isempty (deps)
        || (length (deps) == 1 && strcmp (deps{1}.package, "octave")))
      newdesc{end + 1} = desc{i};
    else
      tmpdesc = {};
      for k = 1 : length (deps)
        for j = 1 : length (desc)
          if (strcmp (desc{j}.name, deps{k}.package))
            tmpdesc{end+1} = desc{j};
            break;
          endif
        endfor
      endfor
      if (! isempty (tmpdesc))
        newdesc = {newdesc{:}, save_order(tmpdesc){:}, desc{i}};
      else
        newdesc{end+1} = desc{i};
      endif
    endif
  endfor

  ## Eliminate the duplicates.
  idx = [];
  for i = 1 : length (newdesc)
    for j = (i + 1) : length (newdesc)
      if (strcmp (newdesc{i}.name, newdesc{j}.name))
        idx(end + 1) = j;
      endif
    endfor
  endfor
  newdesc(idx) = [];

endfunction

function uninstall (pkgnames, handle_deps, verbose, local_list,
                    global_list, global_install)

  ## Get the list of installed packages.
  [local_packages, global_packages] = installed_packages(local_list,
                                                         global_list);
  if (global_install)
    installed_pkgs_lst = {local_packages{:}, global_packages{:}};
  else
    installed_pkgs_lst = local_packages;
  endif

  num_packages = length (installed_pkgs_lst);
  delete_idx = [];
  for i = 1:num_packages
    cur_name = installed_pkgs_lst{i}.name;
    if (any (strcmp (cur_name, pkgnames)))
      delete_idx(end+1) = i;
    endif
  endfor

  ## Are all the packages that should be uninstalled already installed?
  if (length (delete_idx) != length (pkgnames))
    if (global_install)
      ## Try again for a locally installed package.
      installed_pkgs_lst = local_packages;

      num_packages = length (installed_pkgs_lst);
      delete_idx = [];
      for i = 1:num_packages
        cur_name = installed_pkgs_lst{i}.name;
        if (any (strcmp (cur_name, pkgnames)))
          delete_idx(end+1) = i;
        endif
      endfor
      if (length (delete_idx) != length (pkgnames))
        ## FIXME: We should have a better error message.
        warning ("some of the packages you want to uninstall are not installed");
      endif
    else
      ## FIXME: We should have a better error message.
      warning ("some of the packages you want to uninstall are not installed");
    endif
  endif

  if (isempty (delete_idx))
    warning ("no packages will be uninstalled");
  else

    ## Compute the packages that will remain installed.
    idx = setdiff (1:num_packages, delete_idx);
    remaining_packages = {installed_pkgs_lst{idx}};

    ## Check dependencies.
    if (handle_deps)
      error_text = "";
      for i = 1:length (remaining_packages)
        desc = remaining_packages{i};
        bad_deps = get_unsatisfied_deps (desc, remaining_packages);

        ## Will the uninstallation break any dependencies?
        if (! isempty (bad_deps))
          for i = 1:length (bad_deps)
            dep = bad_deps{i};
            error_text = [error_text " " desc.name " needs " ...
                          dep.package " " dep.operator " " dep.version "\n"];
          endfor
        endif
      endfor

      if (! isempty (error_text))
        error ("the following dependencies where unsatisfied:\n  %s", error_text);
      endif
    endif

    ## Delete the directories containing the packages.
    for i = delete_idx
      desc = installed_pkgs_lst{i};
      ## If an 'on_uninstall.m' exist, call it!
      if (exist (fullfile (desc.dir, "packinfo", "on_uninstall.m"), "file"))
        wd = pwd ();
        cd (fullfile (desc.dir, "packinfo"));
        on_uninstall (desc);
        cd (wd);
      endif
      ## Do the actual deletion.
      if (desc.loaded)
        rmpath (desc.dir);
        if (isfolder (getarchdir (desc)))
          rmpath (getarchdir (desc));
        endif
      endif
      if (isfolder (desc.dir))
        [status, msg] = rmdir (desc.dir, "s");
        if (status != 1 && isfolder (desc.dir))
          error ("couldn't delete directory %s: %s", desc.dir, msg);
        endif
        [status, msg] = rmdir (getarchdir (desc), "s");
        if (status != 1 && isfolder (getarchdir (desc)))
          error ("couldn't delete directory %s: %s", getarchdir (desc), msg);
        endif
        if (dirempty (desc.archprefix))
          rmdir (desc.archprefix, "s");
        endif
      else
        warning ("directory %s previously lost", desc.dir);
      endif
    endfor

    ## Write a new ~/.octave_packages.
    if (global_install)
      if (length (remaining_packages) == 0)
        unlink (global_list);
      else
        global_packages = save_order (remaining_packages);
        save (global_list, "global_packages");
      endif
    else
      if (length (remaining_packages) == 0)
        unlink (local_list);
      else
        local_packages = save_order (remaining_packages);
        save (local_list, "local_packages");
      endif
    endif
  endif

endfunction

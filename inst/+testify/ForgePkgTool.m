classdef ForgePkgTool
  
  methods
    function pkg (this, varargin)
      say ('%s %s\n', 'pkg', strjoin (varargin, ' '));
      pkg (varargin{:});
    endfunction

    function uninstall_all_pkgs_except (this, exclusions)
      exclusions = cellstr (exclusions);
      pkg_list = pkg ('list');
      installed_pkgs = cellfun(@(s) { s.name }, pkg_list);
      to_uninstall = setdiff (installed_pkgs, exclusions);
      for i = 1:numel (to_uninstall)
        this.pkg ('unload', to_uninstall{i});
      endfor
      if ! isempty (to_uninstall)
        this.pkg ('uninstall', to_uninstall{:});
      end
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

classdef Util

  methods (Static)

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

  endmethods

endclassdef
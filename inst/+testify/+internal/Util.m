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

    function out = u_strlen (str)
      %U_STRLEN Unicode string length of UTF-8 string
      str = cellstr (str);
      out = NaN (size (str));
      for i = 1:numel (str)
        out(i) = numel (unique (unicode_idx (str{i})));
      endfor
    endfunction

    endmethods

endclassdef
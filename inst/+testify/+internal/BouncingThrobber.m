classdef BouncingThrobber < testify.internal.Throbber
  %BOUNCINGTHROBBER A Throbber that bounces a character back and forth
  
  properties
    left_end = "["
    right_end = "]"
    character = "-"
    field_size = 8;
  endproperties
  
  properties (Access = private)
    
  endproperties
    
  methods
    function this = BouncingThrobber (character)
      if nargin == 0
        return
      endif
      if ! ischar (character)
        error ("BouncingThrobber: character must be char; got a %s", class (character));
      endif
      % Character may actually be non-scalar, because it is a UTF-8 sequence that
      % encodes a single character
      if u_strlen (character) != 1
        error ("BouncingThrobber: character must be 1 Unicode character; got %d", ...
          u_strlen (character));
      endif
    endfunction
  endmethods
endclassdef

function out = u_strlen (str)
  out = testify.internal.Util.u_strlen (str);
endfunction

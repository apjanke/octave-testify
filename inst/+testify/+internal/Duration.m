classdef Duration
  %DURATION A duration of time
  %
  % This is just a dumb holder of a duration of time as a count of seconds,
  % used to produce a nicer-formatted display. It does not support arithmetic
  % or interaction with datetimes.
  
  properties
    seconds = 0
  endproperties
  
  methods

    function this = Duration(seconds)
      if nargin == 0
        return
      endif
      if ! isscalar (seconds) || ! isnumeric (seconds)
        error ('seconds must be a scalar numeric');
      endif
      this.seconds = double(seconds);
    endfunction

    function disp (this)
      disp (dispstr (this));
    endfunction

    function out = dispstr (this)
      if isscalar (this)
        strs = dispstrs (this);
        out = strs{1};
      else
        out = sprintf ("%s %s", size2str (size (this)), class (this));
      endif
    endfunction

    function out = dispstrs (this)
      out = cell (size (this));
      for i = 1:numel (this)
        out{i} = format_seconds_as_hhmmss(this(i).seconds);
      endfor
    endfunction

    function out = char (this)
      if ! isscalar (this)
        error ("%s: char() only works on scalar %s objects; this is %s", ...
          class (this), class (this), size2str (size (this)));
      endif
      strs = dispstrs (this);
      out = strs{1};
    endfunction

  endmethods
  
endclassdef

function out = format_seconds_as_hhmmss(s_in)
  s = s_in;
  hours = floor(s / (60 * 60));
  s = s - (hours * 60 * 60);
  minutes = floor(s / 60);
  s = s - (minutes * 60);
  seconds = floor(s);
  s = s - seconds;
  out = sprintf("%02d:%02d:%02d", hours, minutes, seconds);
endfunction
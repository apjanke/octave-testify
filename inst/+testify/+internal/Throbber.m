classdef Throbber < handle
  %THROBBER An interactive progress indicator that displays an animated doohicky
  
  % Notes:
  %
  % This source file is encoded in UTF-8.
  %
  % This is a work in progress. Not all the throbber styles work.
  %
  % Some of the styles cause CLI Octave to hang, in octave-default. Looks like
  % it's a pause() bug: https://savannah.gnu.org/bugs/index.php?55940.
  %
  % TODO: Should use sleep() instead of pause(), because "pause off" may have
  % happened, and because of that bug.
  %
  % TODO: I think we need wcwidth(3) or UCHAR_EAST_ASIAN_WIDTH property detection
  % support to use multi-column Unicode chars correctly. For now, we'll just
  % hardcode sequence widths where needed.
  %   http://man7.org/linux/man-pages/man3/wcwidth.3.html
  %   https://stackoverflow.com/questions/15631168/validate-japanese-character-in-active-record-callback/15651264#15651264
  %   https://www.cl.cam.ac.uk/~mgk25/ucs/wcwidth.c
  %   http://www.icu-project.org/apiref/icu4c/uchar_8h.html#a3376f0d34bb23c54671859f1978b4226
  
  properties (Constant)
    styles = {
      "A"     {{ "-" "\\" "|" "/" }}
      "B"     {{ "[-]" "[\\]" "[|]" "[/]" }}
      "C"     {{ "[-    ]" "[ -   ]" "[  -  ]" "[   - ]" "[    -]" ...
                "[   - ]" "[  -  ]" "[ -   ]" }}
      "box_spin_1" {{ "─" "┐" "│" "┘" "─" "└" "│" "┌" }}
      "box_spin_2" {{ "├" "┬" "┤" "┴" "┣" "┳" "┫" "┻" }}
      "box_spin_3" {{ "├" "┬" "┤" "┴" ...
                             "┼" "┽" "╃" "╇" "╋" ...
                             "┣" "┳" "┫" "┻" ...
                             "╋" "╈" "╅" "┽" "┼"
                             }}
      "box_spin_4" {{ "┽" "╀" "┾" "╁" }}
      "arrow_spin_1" {{"←" "↖" "↑" "↗" "→" "↘" "↓" "↙"}}
      "dominoes" {{"🀱" "🀲"	"🀳"	"🀴"	"🀵"	"🀶"	"🀷"	"🀸"	"🀹"	"🀺"	"🀻"	"🀼"	"🀽"	"🀾"	"🀿" ...
                   "🁀" "🁁"	"🁂"	"🁃"	"🁄"	"🁅"	"🁆"	"🁇"	"🁈"	"🁉"	"🁊"	"🁋"	"🁌"	"🁍"	"🁎"	"🁏" ...
                   "🁐" "🁑"	"🁒"	"🁓"	"🁔"	"🁕"	"🁖"	"🁗"	"🁘"	"🁙"	"🁚"	"🁛"	"🁜"	"🁝"	"🁞"	"🁟" ...
                   "🁠" "🁡" ...
                   "🁣" "🁤" "🁥" "🁦" "🁧" "🁨" "🁩" "🁪" "🁫" "🁬" "🁭" "🁮" "🁯" ...
                   "🁰" "🁱" "🁲" "🁳" "🁴" "🁵" "🁶" "🁷" "🁸" "🁹" "🁺" "🁻" "🁼" "🁽" "🁾" "🁿" ...
                   "🂀" "🂁" "🂂" "🂃" "🂄" "🂅" "🂆" "🂇" "🂈" "🂉" "🂊" "🂋" "🂌" "🂍" "🂎" "🂏" ...
                   "🂐" "🂑" "🂒" "🂓"}, 2}
      "cards"    {{"🂡" "🂢" "🂣" "🂤" "🂥" "🂦" "🂧" "🂨" "🂩" "🂪" "🂫" "🂬" "🂭" "🂮" ...
                   "🂱" "🂲" "🂳" "🂴" "🂵" "🂶" "🂷" "🂸" "🂹" "🂺" "🂻" "🂼" "🂽" "🂾" ...
                   "🃁" "🃂" "🃃" "🃄" "🃅" "🃆" "🃇" "🃈" "🃉" "🃊" "🃋" "🃌" "🃍" "🃎" ...
                   "🃑" "🃒" "🃓" "🃔" "🃕" "🃖" "🃗" "🃘" "🃙" "🃚" "🃛" "🃜" "🃝" "🃞" ...
                   "🃟" "🃏"}, 2}
      "smileys"  {{"😀" "😁" "😂" "😃" "😄" "😅" "😆" "😇" "😈" "😉" "😊" "😋" "😌" "😍" "😎" "😏" ...
                   "😐" "😑" "😒" "😓" "😔" "😕" "😖" "😗" "😘" "😙" "😚" "😛" "😜" "😝" "😞" "😟" ...
                   "😠" "😡" "😢" "😣" "😤" "😥" "😦" "😧" "😨" "😩" "😪" "😫" "😬" "😭" "😮" "😯" ...
                   "😰" "😱" "😲" "😳" "😴" "😵" "😶" "😷" "🙁" "🙂" "🙃" "🙄"}, 2}
      "smiley_cats" {{"😸" "😹" "😺" "😻" "😼" "😽" "😾" "😿" "🙀"}, 2}
      "see_no_evil" {{"🙈" "🙉" "🙊"}, 2}
      "pattycake" {{"🙏", "🙌"}, 2}
      "gestures" {{"🙍" "🙋" "🙎" "🙆" "🙎" "🙅"}, 2}
      "clocks" {{ "🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚" "🕛" }, 2}
      % Doesn't work right: either it doesn't erase chars left behind to the right of sequence,
      % or, if we normalize it, advances across the screen.
      "hmm"   {{ "hmm" "hmmm" "hmmmm" "hmmmmm" "hmmmmmm" "hmmmmmmm" "hmmmmmm" ...
                "hmmmmm" "hmmmm" "hmmm" "hmm" }}
    }
    default_style = "A";
  endproperties
  
  properties
    sequence = [];
    n_cols = [];
  endproperties
  
  properties (Access = private)
    index = [];
  endproperties
  
  methods (Static)
    function out = get_throbber (style)
      if nargin < 1; style = testify.internal.Throbber.default_style; endif
      if isequal (style, "random")
        ix = randi (size (testify.internal.Throbber.styles, 1));
        style = testify.internal.Throbber.styles{ix, 1};
      endif
      if iscellstr (style)
        out = testify.internal.Throbber (style);
      elseif isequal (style, "null")
        out = testify.internal.NullThrobber;
      elseif ischar (style)
        [tf, loc] = ismember (style, testify.internal.Throbber.styles(:,1));
        if ~tf
          error ("Throbber: undefined style: '%s'", style);
        endif
        style_defn = testify.internal.Throbber.styles{loc,2};
        out = testify.internal.Throbber (style_defn{:});
      endif
    endfunction
    
    function demo_all ()
      styles = testify.internal.Throbber.styles(:,1);
      for i = 1:numel (styles)
        fprintf ("Demoing %s:\n", styles{i});
        thr = testify.internal.Throbber.get_throbber (styles{i});
        thr.demo;
      endfor
    endfunction
  endmethods
  
  methods
    function this = Throbber (sequence, n_cols)
      %THROBBER Construct a new Throbber
      %
      % this = Throbber (sequence, n_cols)
      %
      % sequence (cellstr) is a list of the steps in the throbber's animation.
      %
      % n_cols (double) is the number of fixed-width terminal display columns
      % the sequence takes up. If omitted, it is inferred from sequence.
      if nargin == 0
        style = testify.internal.Throbber.default_style;
        [tf, loc] = ismember (style, testify.internal.Throbber.styles(:, 1));
        style_defn = testify.internal.Throbber.styles{loc, 2};
        [sequence, n_cols]
      elseif nargin == 1
        n_cols = [];
      endif
      sequence = this.normalize_sequence (sequence);
      if isempty (n_cols)
        n_cols = sum (u_strlen (sequence{1}));
      endif
      this.sequence = sequence;
      this.n_cols = n_cols;
    endfunction
    
    function set.sequence (this, sequence)
      if ! iscellstr (sequence)
        error ("Throbber: sequence must be a cellstr; got a %s", class (sequence));
      endif
      sequence = sequence(:)';
      this.sequence = sequence;
    endfunction
    
    function demo (this)
      fprintf ("Doing stuff...");
      this.start;
      unwind_protect
        for i = 1:30
          sleep (0.4);
          this.step;
        endfor
      unwind_protect_cleanup
        this.stop;
        fprintf ("done\n");
      end_unwind_protect
    endfunction
    
    function start (this)
      if ! isempty (this.index)
        error ("Throbber: already started; cannot call start()");
      endif
      this.index = 1;
      fprintf ("%s", this.emission_sequence);
    endfunction
    
    function step (this)
      if isempty (this.index)
        error ("Throbber: not started; cannot call step()");
      endif
      output = this.deletion_sequence;
      this.index = this.index + 1;
      if this.index > numel (this.sequence)
        this.index = 1;
      endif
      % Combine deletion and rewriting an a single print to avoid flashing
      output = [output this.emission_sequence];
      fprintf ("%s", output);
    endfunction
    
    function stop (this)
      if isempty (this.index)
        error ("Throbber: not started; cannot call stop()");
      endif
      output = [this.deletion_sequence repmat(" ", [1 this.n_cols]) this.deletion_sequence];
      fprintf ("%s", output);
      this.index = [];
    endfunction
  endmethods
  
  methods (Access = private)
    function out = normalize_sequence (this, seq)
      out = seq;
      lens = u_strlen (seq);
      n_lens = numel (unique (lens));
      if n_lens > 1
        max_len = max (lens);
        for i = 1:numel (seq)
          len = lens(i);
          if len < max_len
            out{i} = [seq{i} repmat(" ", [1 max_len - len])];
          endif
        endfor
      endif
    endfunction

    function out = deletion_sequence (this)
      backspace = char (8);
      out = repmat (backspace, [1 this.n_cols]);
    endfunction
    
    function out = emission_sequence (this)
      out = this.sequence{this.index};
    endfunction
  endmethods
endclassdef

function out = u_strlen (str)
  out = testify.internal.Util.u_strlen (str);
endfunction

function sleep (seconds)
  if usejava ('jvm')
    javaMethod ('sleep', 'java.lang.Thread', round (seconds * 1000));
  else
    pause (seconds);
  endif
endfunction

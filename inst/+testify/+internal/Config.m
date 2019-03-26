## Copyright (C) 2019 Andrew Janke
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; If not, see <http://www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn {Class Constructor} {obj =} Config ()
##
## Config data for Testify
##
## Common config data and operations.
##
## @end deftypefn

## Author:  Andrew Janke

classdef Config

  methods (Static)

    function out = testify_data_dir ()
      # TODO: This is probably wrong for Windows
      out = fullfile (getenv("HOME"), "octave", "testify");
    endfunction

  endmethods

endclassdef
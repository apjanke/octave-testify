## Copyrignt (C) 2019 Andrew Janke
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

## -*- texinfo -*-
##
## @deftp {Class} TestCase
##
## A TestCase is the means by which a test is written in the @code{matlab.unittest}
## framework. To create a test, derive a subclass from @code{TestCase}
##
## @end deftp

classdef TestCase < handle, matlab.unittest.qualifications.Assertable, ...
  matlab.unittest.qualifications.Assumable, matlab.unittest.qualifications.FatalAssertable, ...
  matlab.unittest.qualifications.Verifiable
  
  events
    VerificationFailed
    VerificationPassed
    AssertionFailed
    AssertionPassed
    FatalAssertionFailed
    FatalAssertionPassed
    AssumptionFailed
    AssumptionPassed
    ExceptionThrown
    DiagnosticLogged
  endevents
  
  methods (Static)
    function out = forInteractiveUse
      
    endfunction
    
    
  endmethods

  methods
    function addTeardown
      
    endfunction
    
    function onFailure
      
    endfunction
    
    function applyFixture
      
    endfunction
    
    function out = getSharedTestFixtures(this)
      
    endfunction
    
    function log (this)
      
    endfunction
    
    function run (this)
      
    endfunction
  endmethods
endclassdef

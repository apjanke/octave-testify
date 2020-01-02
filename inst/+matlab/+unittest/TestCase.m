classdef TestCase < matlab.unittest.qualifications.Assertable ...
  & matlab.unittest.qualifications.Assumable ...
  & matlab.unittest.qualifications.FatalAssertable ...
  & matlab.unittest.qualifications.Verifiable
  % Base class for all matlab.unittest test classes
  %
  % This is the mechanism by which users write tests in the Unit Testing framework.
  % Your test case classes inherit from this class.
  
  properties
    
  endproperties
  
  methods
    function out = run(this, testMethod)
      % Run this test case
      %
      % out = run(this, testMethod)
      %
      % testMethod is the name of the test method to run.
      %
      % Returns a matlab.unittest.TestResult holding the results of the test run.
      UNIMPLEMENTED_TODO
    endfunction
  endmethods
  
endclassdef

classdef TestResult
  % The results of running a test suite
  
  properties
    % Name of the TestSuite that ran
    Name
    % Logical value showing if the test passed
    Passed
    % Logical value showing if the test failed
    Failed
    % Logical value showing if test did not run to completion
    Incomplete
    % Time elapsed during test
    Duration
    % Configuration-specific data for the test result
    Details
  endproperties
  
  methods
    function out = table(this)
      % Convert this array to a table
      %
      % For this to work, it requires an Octave table implementation, such as 
      % the Tablicious package.
      UNIMPLEMENTED_TODO
    endfunction
  endmethods
endclassdef

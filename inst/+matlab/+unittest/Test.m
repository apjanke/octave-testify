classdef Test < matlab.unittest.TestSuite
  % Specification of a single test method
  
  properties
    % Name of the test
    Name
    % Name of the test method (or other procedure) the test runs
    ProcedureName
    % Name of the test class for a TestCase, or empty for other types of tests.
    TestClass = ''
    % Path to the folder that contains the file defining the test content. For 
    % tests defined in packages, this is the base folder above the top-level
    % package folder (that is, the path element where the test code can be found)
    BaseFolder
    % Parameters required for the test, as cell row vector
    Parameterization = {}
    % Fixtures required for the test, as cell row vector
    SharedTestFixtures
    % Tags applied to the test, as a cell row vector
    Tags = {}
  endproperties
endclassdef

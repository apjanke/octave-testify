Testify – New test/BIST functions for GNU Octave
================================================

This is a collection of new BIST (Built-In Self-Test) related functions for Octave.

These override and replace some of Octave's current test functions.
This is intentional - this package started out as just a patch to Octave's `__run_test_suite__`.
The goal here is to prototype something that might be a step forward for Octave's current testing functionality.

The goals of Testify's new test functions are:
* Richer abstractions for representing test results
* Nicer output format
  * Including summary results that make it easier to copy-paste meaningful test failure reports to the octave-maintainers list
* Convenience functions for testing packages and related code units
* Integration with CI (“continuous integration”) platforms/harnesses

Functions in this package shadow Octave-provided functions. This is intentional.

### Non-Goals

Testify does _not_ implement [Matlab's unit test framework](https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html), or attempt to be compatible with it.
This is just a “richer” way of doing Octave's current BIST tests, using its existing data model.

## Installation and Use

Do not install this using `pkg`!
Because Testify's functions load and unload packages as part of the testing protocol, it won't work to have Testify installed as a package itself.

Instead, just download Testify somewhere and then add its `inst/` directory to your Octave path using `addpath()`.
It needs to go at the front of your path, because it shadows Octave's own test functions.
(You don't need to do anything special - by default, `addpath()` puts the new paths at the front.
Just don't use the the `-end` or `1` options to it.)

Then, call one of Testify's functions:

* `__run_test_suite__` - just like Octave's regular `__run_test_suite__`, but with (IMHO) nicer output.
* `__test_pkgs__` – a new function for running tests on installed `pkg` packages.

## What's In Here

Conceptually, all the code in `inst` here could drop right in to `scripts/testfun/` in the `octave` hg repo.
It's all in the root namespace, expected to shadow existing core Octave code.

#### Externally Visible

<dl>
<dt>`__run_test_suite__`</dt>
<dd>A replacement for Octave's current `__run_test_suite__`.
Nothing much new here; just internal changes to support the `TestSuiteResults` abstraction.</dd>
</dl>

#### Internal Changes

<dl>
<dt>TestSuiteResults</dt>
<dd>An object that collects the various counters and lists associated with BIST run results.
This is a replacement for the current technique of managing a half dozen primitive variables in parallel.
</dd>
</dl>

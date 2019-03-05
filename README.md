Testify – New test/BIST functions for GNU Octave
================================================

This is a collection of new and enhanced BIST (Built-In Self-Test) related functions for Octave.

These override and replace some of Octave’s current test functions.
This is intentional - this package started out as just a patch to Octave’s `__run_test_suite__`.
The goal here is to prototype something that might be a step forward for Octave’s current testing functionality.

The goals of Testify’s new test functions are:
* Richer abstractions for representing test results
* Nicer output format
  * Including summary results that make it easier to copy-paste meaningful test failure reports to the octave-maintainers list
* Convenience functions for testing packages and related code units
* Integration with CI (“continuous integration”) platforms/harnesses

Functions in this package shadow Octave-provided functions. This is intentional.

### Non-Goals

Testify does _not_ implement [Matlab's unit test framework](https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html), or attempt to be compatible with it.
This is just a “richer” way of doing Octave's current BIST tests, using its existing data model.

If you _are_ interested in seeing a clone of xUnit or Matlab’s unit test framework, go [add a comment on Issue #5](https://github.com/apjanke/octave-testify/issues/5) to indicate your interest.
If enough people want it, I’ll try to make it happen.

## Installation and usage

### Quick start

To get started using or testing this project, install it using Octave’s `pkg` function:

```
pkg install https://github.com/apjanke/octave-testify/releases/download/v0.1.0/testify-0.1.0.tar.gz
pkg load testify
```

### Installation for development

* Clone the repo.
  * `git clone https://github.com/apjanke/octave-testify`
* Run `make dist` in a shell.
* Install the resulting `target/testify-X.Y.Z.tar.gz` package file by running `pkg install /path/to/repo/octave-testify/target/testify-X.Y.Z.tar.gz` in Octave.
* Lather, rinse, and repeat each time you make changes to any of the source code.

### Usage

Then, call one of Testify’s functions:

* `__run_test_suite__` - just like Octave's regular `__run_test_suite__`, but with (IMHO) nicer output.
* `__test_pkgs__` – a new function for running tests on installed `pkg` packages.

## What's In Here

Conceptually, all the code in `inst` here could drop right in to `scripts/testfun/` in the `octave` hg repo.
It's all in the root namespace, expected to shadow existing core Octave code.

#### Externally Visible

<dl>
<dt><code>__run_test_suite__</code></dt>
<dd>A replacement for Octave’s current <code>__run_test_suite__</code>.
Nothing much new here; just internal changes to support the <code>BistRunResult</code> abstraction.</dd>
<dt><code>__test_pkgs__</code></dt>
<dd>A function for running tests on a `pkg` package of Octave code.</dd>
<dt><code>__run_tests_and_exit__</code></dt>
<dd>A function for running tests and using `octave`’s exit status to indicate success or failure.
For use in Continuous Integration or automated testing environments.</dd>
</dl>

#### Internal Changes

<dl>
<dt><code>BistRunResult</code></dt>
<dd>An object that collects the various counters and lists associated with BIST run results.
This is a replacement for the current technique of managing a half dozen primitive variables in parallel.
</dd>
</dl>

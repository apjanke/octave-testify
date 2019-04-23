Testify Developer Notes
=======================

# References

##  Octave issues and mailing list discussions

There's been a lot of discussion about test enhancements on the Savannah issue tracker and the [Octave Maintainers mailing list](http://lists.gnu.org/archive/html/octave-maintainers/).
Make sure to check them out before diving in to this code.

###  Savannah issues

* [bug #41298: pkg install: automatically extract %!tests and install both extracted and fixed test files](https://savannah.gnu.org/bugs/?41298)
* [bug #41215: Request for a "pkg test" feature](https://savannah.gnu.org/bugs/?41215)
* [bug #55522: Add failure summary to \__run_test_suite__ output?](https://savannah.gnu.org/bugs/index.php?55522)
* [bug #54832: \__run_test_suite__ fails with nested directories](https://savannah.gnu.org/bugs/index.php?54832)
* [bug #47424: Cannot run "test function" for builtin functions](https://savannah.gnu.org/bugs/index.php?47424)
* [bug #46353: test function does not work with namespaces](https://savannah.gnu.org/bugs/index.php?46353)
* [bug #44303: resolve duplication / merge runtests and \__run_test_suite__](https://savannah.gnu.org/bugs/index.php?44303)
* [bug #41298: pkg install: automatically extract %!tests and install both extracted and fixed test files](https://savannah.gnu.org/bugs/index.php?41298)
* [bug #38776: Tests in private functions cannot be tested directly](https://savannah.gnu.org/bugs/index.php?38776)
* [bug #55250: test suite severely overcounts "files with no tests"](https://savannah.gnu.org/bugs/index.php?55250)
* [bug #54718: \__run_test_suite__ doesn't preserve start or working directory](https://savannah.gnu.org/bugs/index.php?54718)
* [bug #54173: Intermittent hang in test suite when run from Qt GUI on macOS](https://savannah.gnu.org/bugs/index.php?54173)
* [bug #53875: Test suite fails with non-ASCII characters if system code page is not UTF-8](https://savannah.gnu.org/bugs/index.php?53875)
* [https://savannah.gnu.org/bugs/index.php?54561](https://savannah.gnu.org/bugs/index.php?54561)

###  Mailing list threads

* [Hardening BIST tests – 2/8/2019](http://lists.gnu.org/archive/html/octave-maintainers/2019-02/msg00095.html)
* [Figures popping up during running of test suite? – 8/2/2018](http://lists.gnu.org/archive/html/octave-maintainers/2018-08/msg00010.html)
* [run BISTs for all installed packages – 1/21/2019](http://lists.gnu.org/archive/html/octave-maintainers/2019-01/msg00209.html)
* [Removing XFAILs from test suite summary – 4/11/2018](http://lists.gnu.org/archive/html/octave-maintainers/2018-04/msg00111.html)
* [Test suite regressions vs expected failures – 8/16/2017](http://lists.gnu.org/archive/html/octave-maintainers/2017-08/msg00111.html)
* [Marking bugs as fixed in the test suite – 7/7/2017](https://lists.gnu.org/archive/html/octave-maintainers/2017-07/msg00040.html)
* [Initialization files for test suite – 2/8/2019](http://lists.gnu.org/archive/html/octave-maintainers/2019-02/msg00093.html)
* [Re: --norc option and test suite – 2/7/2019](http://lists.gnu.org/archive/html/octave-maintainers/2019-02/msg00073.html)
* [BuildBots no longer run make check? – 6/1/2018](http://lists.gnu.org/archive/html/octave-maintainers/2018-06/msg00006.html)
* [Improving BISTs that are known to fail with LLVM libc++ – 4/14/2018](http://lists.gnu.org/archive/html/octave-maintainers/2018-04/msg00152.html)
* [xtest vs test – 7/2/2016](http://lists.gnu.org/archive/html/octave-maintainers/2016-07/msg00023.html)
* [test suites for packages – 10/15/2014](http://lists.gnu.org/archive/html/octave-maintainers/2014-10/msg00068.html)
* [Matlab compatibility of assert (was: Re: assert () taking long time) – 9/24/2013](http://lists.gnu.org/archive/html/octave-maintainers/2013-09/msg00299.html)

## Other packages

The [Debian `dh-octave`](https://packages.debian.org/sid/dh-octave) package (for “debhelper-octave”) has its own method for running all tests in a source package at build time and in a CI environment.

There's an [`octave-doctest` project](https://github.com/catch22/octave-doctest) for embedding tests/demos in Matlab-style helptext.

Mike Miller is working on [`octave-test-suite` on GitLab](https://gitlab.com/mtmiller/octave-test-suite) which is focused on testing the interaction between the `octave` command and the external system.

# Release Checklist

* Update release in `DESCRIPTION`
* Update download instructions version in `README.md`
* `git commit`
* Do `make dist` to make sure that it works
* `git tag v<version>`
* `git push; git push --tags`
* Create GitHub release
  * Draft a release from the `v<version>` tag
  * Note it as pre-release
  * Upload the dist file resulting from that `make dist` you did
* Update release in `DESCRIPTION` to `<version>+` to open development on next release
* `git commit -a; git push`

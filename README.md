# Find executable

D library for finding executable files using PATH environment variable.

[![Build Status](https://github.com/FreeSlave/findexecutable/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/FreeSlave/findexecutable/actions/workflows/ci.yml)

Originally this was a part of [standardpaths](https://github.com/FreeSlave/standardpaths) library. But I found need in this kind of functionality in my other projects that don't depend on standardpaths.

[Online documentation](https://freeslave.github.io/findexecutable/findexecutable.html)

## Examples

### [Find executable](examples/find.d)

Takes the name of executable as command line argument and searches PATH environment variable for retrieving absolute path to file. On Windows it also tries all known executable extensions.

    dub examples/find.d whoami dub dmd

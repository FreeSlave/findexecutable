# Find executable

D library for finding executable files using PATH environment variable.

Originally this was a part of [standardpaths](https://github.com/MyLittleRobo/standardpaths) library. But I found need in this kind of functionality in my other libraries that don't depend on standardpaths.

## Examples

### [Find executable](examples/findexecutable/source/app.d)

Takes the name of executable as command line argument and searches PATH environment variable for retrieving absolute path to file. On Windows it also tries all known executable extensions.

    dub run :findexecutable --build=release -- whoami dub dmd
    

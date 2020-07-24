/**
 * Searching for executable files in system paths.
 * Authors: 
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2016
 */

module findexecutable;

private {
    import std.algorithm : canFind, splitter, filter, map;
    import std.path;
    import std.process : environment;
    import std.range;

    version(Windows) {
        import std.uni : toLower;
    }
    version(Posix) {
        import std.string : toStringz;
    }
}

version(Windows) {
    private enum pathVarSeparator = ';';
    private enum defaultExts = ".exe;.com;.bat;.cmd";
} else version(Posix) {
    private enum pathVarSeparator = ':';
}

version(unittest) {
    import std.algorithm : equal;
    
    private struct EnvGuard
    {
        this(string env) {
            envVar = env;
            envValue = environment.get(env);
        }

        ~this() {
            if (envValue is null) {
                environment.remove(envVar);
            } else {
                environment[envVar] = envValue;
            }
        }

        string envVar;
        string envValue;
    }
}

/**
 * Default executable extensions for the current system.
 * 
 * On Windows this functions examines $(B PATHEXT) environment variable to get the list of executables extensions. 
 * Fallbacks to .exe;.com;.bat;.cmd if $(B PATHEXT) does not list .exe extension.
 * On other systems it always returns empty range.
 * Note: This function does not cache its result
 */
@trusted auto executableExtensions() nothrow
{
    version(Windows) {
        static bool filenamesEqual(string first, string second) nothrow {
            try {
                return filenameCmp(first, second) == 0;
            } catch(Exception e) {
                return false;
            }
        }

        static auto splitValues(string pathExt) {
            return pathExt.splitter(pathVarSeparator);
        }

        try {
            auto pathExts = splitValues(environment.get("PATHEXT").toLower());
            if (canFind!(filenamesEqual)(pathExts, ".exe") == false) {
                return splitValues(defaultExts);
            } else {
                return pathExts;
            }
        } catch(Exception e) {
            return splitValues(defaultExts);
        }

    } else {
        return (string[]).init;
    }
}

///
unittest
{
    version(Windows) {
        auto guard = EnvGuard("PATHEXT");
        environment["PATHEXT"] = ".exe;.bat;.cmd";
        assert(equal(executableExtensions(), [".exe", ".bat", ".cmd"]));
        environment["PATHEXT"] = "";
        assert(equal(executableExtensions(), defaultExts.splitter(pathVarSeparator)));
    } else {
        assert(executableExtensions().empty);
    }
}

private bool isExecutable(Exts)(string filePath, Exts exts) nothrow {
    try {
        version(Posix) {
            import core.sys.posix.unistd;
            return access(toStringz(filePath), X_OK) == 0;
        } else version(Windows) {
            //Use GetEffectiveRightsFromAclW?

            string extension = filePath.extension;
            foreach(ext; exts) {
                if (filenameCmp(extension, ext) == 0)
                    return true;
            }
            return false;

        } else {
            static assert(false, "Unsupported platform");
        }
    } catch(Exception e) {
        return false;
    }
}

private string checkExecutable(Exts)(string filePath, Exts exts) nothrow {
    import std.file : isFile;
    try {
        if (filePath.isFile && isExecutable(filePath, exts)) {
            return buildNormalizedPath(filePath);
        } else {
            return null;
        }
    }
    catch(Exception e) {
        return null;
    }
}

/**
 * System paths where executable files can be found.
 * Returns: Range of non-empty paths as determined by $(B PATH) environment variable.
 * Note: This function does not cache its result
 */
@trusted auto binPaths() nothrow
{
    import std.exception : collectException;
    import std.utf : byCodeUnit;
    string pathVar;
    collectException(environment.get("PATH"), pathVar);
    return splitter(pathVar.byCodeUnit, pathVarSeparator).map!(p => p.source).filter!(p => p.length != 0);
}

///
unittest
{
    auto pathGuard = EnvGuard("PATH");
    version(Windows) {
        environment["PATH"] = ".;C:\\Windows\\system32;C:\\Program Files";
        assert(equal(binPaths(), [".", "C:\\Windows\\system32", "C:\\Program Files"]));
    } else {
        environment["PATH"] = ".:/usr/apps:/usr/local/apps:";
        assert(equal(binPaths(), [".", "/usr/apps", "/usr/local/apps"]));
    }
}

/**
 * Find executable by fileName in the paths.
 * Returns: Absolute path to the existing executable file or an empty string if not found.
 * Params:
 *  fileName = Name of executable to search. Should be base name or absolute path. Relative paths will not work.
 *       If it's an absolute path, this function does not try to append extensions.
 *  paths = Range of directories where executable should be searched.
 *  extensions = Range of extensions to append during searching if fileName does not have extension.
 * Note: Currently it does not check if current user really have permission to execute the file on Windows.
 * See_Also: $(D binPaths), $(D executableExtensions)
 */
string findExecutable(Paths, Exts)(string fileName, Paths paths, Exts extensions) 
if (isInputRange!Paths && is(ElementType!Paths : string) && isInputRange!Exts && is(ElementType!Exts : string))
{
    try {
        if (fileName.isAbsolute()) {
            return checkExecutable(fileName, extensions);
        } else if (fileName == fileName.baseName) {
            string toReturn;
            foreach(string path; paths) {
                if (path.empty) {
                    continue;
                }

                string candidate = buildPath(absolutePath(path), fileName);

                if (candidate.extension.empty && !extensions.empty) {
                    foreach(exeExtension; extensions) {
                        toReturn = checkExecutable(setExtension(candidate, exeExtension), extensions);
                        if (toReturn.length) {
                            return toReturn;
                        }
                    }
                }

                toReturn = checkExecutable(candidate, extensions);
                if (toReturn.length) {
                    return toReturn;
                }
            }
        }
    } catch (Exception e) {

    }
    return null;
}

/**
 * ditto, but on Windows when fileName extension is omitted, executable extensions are appended during search.
 * See_Also: $(D binPaths), $(D executableExtensions)
 */
string findExecutable(Paths)(string fileName, Paths paths) 
if (isInputRange!Paths && is(ElementType!Paths : string))
{
    return findExecutable(fileName, paths, executableExtensions());
}

/**
 * ditto, but searches in system paths, determined by $(B PATH) environment variable.
 * On Windows when fileName extension is omitted, executable extensions are appended during search.
 * See_Also: $(D binPaths), $(D executableExtensions)
 */
@trusted string findExecutable(string fileName) nothrow {
    try {
        return findExecutable(fileName, binPaths(), executableExtensions());
    } catch(Exception e) {
        return null;
    }
}

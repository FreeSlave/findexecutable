import std.stdio;
import findexecutable;

void main(string[] args)
{
    if (args.length > 1) {
        foreach(fileName; args[1..$]) {
            string candidate = findExecutable(fileName);
            if (candidate.length) {
                writeln(candidate);
            } else {
                writefln("Could not find %s", fileName);
            }
        }
    } else {
        writefln("Usage: %s <file name>...", args[0]);
    }
}

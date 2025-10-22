module changelog_d;
enum codePackageLink = "https://code.dlang.org/packages/changelog-d";
enum contributeAt = "https://github.com/MrcSnm/changelog-d";
enum changelogdVersion = "v1.1.1";

struct CommitInfo
{
    string hash;
    string tag;
    string desc;
}

struct ChangelogReport
{
    string from;
    string to;
    CommitInfo[][string] keysDescription;
}

struct ChangelogConfig
{

    ///allowDuplicates = If it is allowed to have duplicate commit messages
    bool allowDuplicates;
    ///allowMege = If it is allowed to have merge branch commit messages
    bool allowMerge;
    ///skips the merge PR formatting hot link
    bool skipMergePRFormatting;
    string remote = "origin";
}


bool parseChangelog(string gitLog, out ChangelogReport out_Changelog, out string out_Error, string from, string to, ChangelogConfig cfg)
{
    import std.algorithm.searching:countUntil;
    import std.string:strip;
    import std.string:lineSplitter, startsWith;
    import std.uni: toLowerInPlace;
    CommitInfo[][string] report;

    alias ReportEntries = bool[string];
    ReportEntries[string] duplicateChecker;

    foreach(string v; lineSplitter(gitLog.strip))
    {
        string commitHash = v[0..7];
        //Jump whitespace
        v = v[8..$];
        string tag;
        if(v.length != 0)
        {
            if(v[0] == '(')
            {
                ptrdiff_t space = countUntil(v, "tag: ");
                ptrdiff_t tagEnd = countUntil(v, ") ");
                if(space != -1 && tagEnd == -1)
                {
                    out_Error = "Unexpected format for tags while reading "~v;
                    return false;
                }
                if(space < tagEnd)
                {
                    tag = v[space+"tag: ".length..tagEnd];
                    v = v[tagEnd+2..$];
                }

            }
        }
        ptrdiff_t keyEnd = countUntil(v, ":");
        string key = "Untagged";
        if(keyEnd != -1 && countUntil(v[0..keyEnd], " ") == -1)
        {
            char[] temp = cast(char[])v[0..keyEnd].dup;
            toLowerInPlace(temp);
            key = cast(string)temp;
            keyEnd++;
        }
        else
            keyEnd = 0;
        string desc = v[keyEnd..$];
        bool isDuplicate = true;
        if(!(key in duplicateChecker) || !(desc in duplicateChecker[key]))
        {
            isDuplicate = false;
            duplicateChecker[key][desc] = true;
        }
        bool isMerge = desc.startsWith("Merge branch ");
        bool shouldAppend = (cfg.allowDuplicates && isDuplicate) || !isDuplicate;
        shouldAppend = shouldAppend && ((isMerge && cfg.allowMerge) || !isMerge);

        if(shouldAppend)
            report[key]~= CommitInfo(commitHash, tag, desc);
    }
    if(report is null)
    {
        out_Error~= "gitLog is completely empty";
        return false;
    }
    out_Changelog = ChangelogReport(from, to, report);
    return true;
}

/**
 *
 * Params:
 *   report = The report to format
 *   workingDir = Working dir where git describe will be executed if includeFoot is true.
 *   includeFooter = Whether it should include the footer. Please keep it as it might get more people to help on that project
 * Returns:
 */
string formatChangelog(const ChangelogReport report, const ChangelogConfig cfg, string workingDir = null, bool includeFooter = true)
{
    import std.process;
    import std.string:capitalize, strip, startsWith;
    import std.conv:to;
    import std.algorithm:countUntil;
    import std.path;
    import std.format;
    import std.file;
    enum mergePr = "Merge pull request ";
    string output;
    {
        auto repoName = executeShell("git rev-parse --show-toplevel", null, Config.none, size_t.max, workingDir);
        if(repoName.status == 0)
            output~= "# Changelog for "~baseName(repoName.output.strip)~" "~report.to;
    }
    string baseRepo;
    if(!cfg.skipMergePRFormatting)
    {
        auto repoRemote = executeShell("git remote get-url "~cfg.remote, null, Config.none, size_t.max, workingDir);
        if(repoRemote.status != 0)
            throw new Exception("git remote get-url "~cfg.remote~" returned non zero: "~repoRemote.output);
        baseRepo = repoRemote.output;
    }

    static string getRepoNameInOrigin(string repo)
    {
        if(repo.startsWith("git@github.com"))
            return repo["git@github.com:".length..$-5]; //Removes .git
        else if(repo.startsWith("https://github.com/"))
            return repo["https://github.com/".length..$-5]; //Removes .git
        return repo;
    }

    //Parse the #9999 [number] to generate a issue link
    static string addIssuesLink(string desc, string baseRepo, string repoInOrigin)
    {
        import std.ascii:isDigit;
        if(!baseRepo)
            return desc;
        string finalDesc = null;
        long idx = -1;
        do
        {
            idx = countUntil(desc, "#");
            if(idx != -1)
            {
                finalDesc~= desc[0..idx];
                desc = desc[idx+1..$];
                ///next non digit
                idx = countUntil!((ch => !ch.isDigit))(desc);
                if(idx != -1)
                {
                    finalDesc~= format("[#%s](https://github.com/%s/pull/%s)", desc[0..idx], repoInOrigin, desc[0..idx]);
                    desc = desc[idx..$];
                }
                else
                    finalDesc~= "#";
            }
        } while(idx != -1);
        if(finalDesc)
        {
            finalDesc~= desc;
            desc = finalDesc;
        }
        return desc;
    }
    bool isGithub = baseRepo.countUntil("github.com") != -1;
    string repoInOrigin = isGithub ? getRepoNameInOrigin(baseRepo) : null;

    foreach(string key, const CommitInfo[] value; report.keysDescription)
    {
        if(output !is null)
            output~= "\n\n";
        output~= "## "~key.capitalize;
        foreach(v; value)
        {
            string desc = addIssuesLink(v.desc, baseRepo, repoInOrigin);
            output~="\n- "~desc;
        }
    }
    if(includeFooter)
    {
        output~=
`

|Changelog Metadata|
|------------------:|
|Generated with [changelog-d](`~codePackageLink~`) `~changelogdVersion~`|
|Contribute at `~contributeAt~`|
`;
    }
    return output;
}

/**
 * For the parser to work, you must write in the format
 * `Key: Value`
 *
 * The Key will store multiple values to generate in the report
 *
 * Params:
 *   out_Changelog = Output changelog to generate
 *   fromBranch = Source branch
 *   toBranch = Target branch to generate changelog
 *   out_Error = If an error ocurred while rtying to parse
 *   cfg = Configuration for the generated changelog
 *
 * Returns:
 */
bool generateChangelog(out ChangelogReport out_Changelog, string fromBranch, string toBranch, out string out_Error, ChangelogConfig cfg)
{
	import std.process;
	enum isNotGitRepo = 128;
    enum hasNoGitWindows = 9009;
    enum hasNoGitPosix = 127;

	int gitCode = executeShell("git --help").status;
	if(gitCode == hasNoGitPosix || gitCode == hasNoGitWindows)
	{
		out_Error = "Git is not installed on your PC. Install it before you can run changelog-d";
		return false;
	}
	if(gitCode == isNotGitRepo)
	{
		out_Error = "Not running in a git repository for being able to execute changelog-d";
		return false;
	}

    auto res = executeShell("git log "~fromBranch~".."~toBranch~" --oneline --decorate");
    if(res.status != 0)
    {
        out_Error = "Could not execute git log using branches: " ~ fromBranch~ ".."~ toBranch~ "\nOutput: " ~ res.output;
        return false;
    }

	return parseChangelog(res.output, out_Changelog, out_Error, fromBranch, toBranch, cfg);
}

version(CLI)
int main(string[] args)
{
    import std.stdio;
    import std.file;
    import std.getopt;
    string out_Error;

    string from, to, outputFile = "Changelog.md";
    bool allowDuplicates, allowMerge;

    ChangelogConfig cfg;

    GetoptResult res = getopt(args,
    "from", "The from branch which this program will calculate the log [can also be a tag]", &from,
    "to", "The to branch which this program will get the log", &to,
    "allow-duplicates", "Changelog-d removes duplicate commits messages by default", &cfg.allowDuplicates,
    "allow-merge", "Changelog-d removes merge commits messages by default", &cfg.allowMerge,
    "skip-pr", "Skips the PR merge formatting", &cfg.skipMergePRFormatting,
    "remote", "Sets the remote from which the PRs are formatted. Defaults to origin", &cfg.remote,
    "output", "Output file path. Defaults to Changelog.md",  &outputFile);
    if(res.helpWanted)
    {
        defaultGetoptPrinter("changelog-d help information:\n", res.options);
        return 0;
    }
    if(!from || !to)
    {
        defaultGetoptPrinter("changelog-d requires both --from and --to arguments:\n", res.options);
        return 1;
    }
    ChangelogReport report;
    if(!generateChangelog(report, from, to, out_Error, cfg))
    {
        writeln(out_Error);
        return 1;
    }
    string formatted = formatChangelog(report, cfg);
    std.file.write(outputFile, formatted);
	return 0;
}


unittest
{
    enum reportExample =
`0b4e466 (HEAD -> main, tag: v1.17.1, origin/main, origin/HEAD) Update: Using existing phobos thisExePath
300df20 Update: Proper way to get windows exe path
c8f8f60 Fixed: Support for linux
6c0412d Update: Now working redub update on macOS
0c1e888 Added: Redub update command
54b0e24 (tag: v1.17.0) Added: Redub fetches, fixed #32 (author issue), improved sdl->json parsing, improved redub clean, improved redub cache check after clean, parallel fetching
fc4658f (tag: v1.16.1) Fixed: Remove comments from SDL before converting to JSON, handle buildTypes correctly from SDL converter, clean test files
5aae8f1 (tag: v1.16.0) Added: SDL->JSON parser to Redub, removing one more dependency from dub
34c071f (tag: v1.15.0) Update: Fully added --single support for redub
4484d2b (tag: v1.14.16) Fixed #15 - Preprocess SDL file before using dub convert
36581b9 (tag: v1.14.15) Update: Pkg-config execution is fully parallelized, added more timings on vverbose mode
8aac1fe (tag: v1.14.14) Fixed: Pending merge requirements weren't being processed with environment
7dcf931 (tag: v1.14.13) Update: Remove buildType enforce false for holding ecosystem
c9edfc1 (tag: v1.14.12) Update: Redub now includes version of the compiler used to be built, throws an exception if an inexistent configuration is sent, defaults plugin compiler to be the same as the used one to build
2f25633 (tag: v1.14.11) Update: Fixed #30 and #29. Also fixed issue when specifying a custom compiler with arch not triggering LDC anymore. Fixed issue where specifying global compiler would fai
f8f104a (tag: v1.14.10) Update: Plugins won't include environment variables in the process of building itself
ae381cb (tag: v1.14.9) Fixed: #27, #28, expected artifacts now will only be evaluated at requirement time, removed it from build requirements, copy attributes on dir copy, fixed target name
bc56cdc (tag: v1.14.8) Update: Do not output deps by default, this is causing compile time slowdown rather than good
398f2ad (tag: v1.14.7) Update: Less memory allocation inside adv_diff and inference for simplified hashing when file bigger than 2MB
a655ee2 (tag: v1.14.6) Update: Added simplified hashing for output files bringing a much afster cache writing
269d72b (tag: v1.14.5) Update: Faster copy cache formula using a simplified process of checking
0061fff (tag: v1.14.4) Fixed: Dynamic library names
19b659e (tag: v1.14.3) Update: Fixed dynamic lib name for linux and osx
9316c07 (tag: v1.14.2) Update: Fix linux build
4509fca (tag: v1.14.1) Fixed: Crash on empty adv cache formula and redub plugins are now global
883f5b4 (tag: v1.14.0) Added: Redub plugin support, fixes #11
a64d2cd Merge branch 'main' into plugin
5785651 (tag: v1.13.10) Update: Adv diff will now use content hash for cache formulas instead of modification time, this will fix a problem where it wasn't able to get name changes on file
fd2593c Wip: Adding plugins
fcf8546 (tag: v1.13.9) Update: Remove start group from macOS
16fd690 (tag: v1.13.8) Update: Now redub will always specify to handle circular linker dependencies
f71ef7a (tag: v1.13.7) Update: Fix targetName
177ab33 (tag: v1.13.6) Update: Handling targetName
cc468bc (tag: v1.13.5) Update: Fixed some cases where a dependency could be double registered when using subpackages
abb5e80 (tag: v1.13.4) Fixed: Correctly infer staticLibrary for non root packages
ce11ea7 (tag: v1.13.3) Update: Fixed postBuildCommands to be used after .exe gen
2ea7283 (tag: v1.13.2) Fixed: A problem where some files would not be copied
e70f0cf (tag: v1.13.1) Update: Fixed on can't build for windows when having different drive disks
f6902c0 (tag: v1.13.0) Update: Improved logging to print less things, also fixed an issue where sometimes a sub package would get a wrong name
339b12f (tag: v1.12.1) Fixed: Clean will now also clear the cache folder so it will always cause a rebuild (solves the trying to run inexistent file problem), and now also outputs libraries when they are root
71120b4 (tag: v1.12.0) Update: Fixed problem getting wrong cache when cross compiling, fixed the problem where the run arguments were not being sent correctly
ff27aad (tag: v1.11.9) Update: Added getOutputName for redub api, added verbose build type
93702c8 (tag: v1.11.8) Update: Filter -preview= from the dflags
083dd41 (tag: v1.11.7) Update: Added time-trace and mixin-check to the build
35d9c70 (tag: v1.11.6) Fixed: Now the copy cache will also look for object files
eb03849 (tag: v1.11.5) Fixed: Bug wehre some times the creation of cache files would not happen and still would cache the file
21c91ed Update: Improvements on redub library api
86077ab (tag: v1.11.4) Fixed: Bug on LDC where it would not allow to build if the directory for object dir didn't exist
783ed6b (tag: v1.11.3) Update: Improved build to save cache even when it fails
17e5423 Update: Improved source imports
90c9aee (tag: v1.11.2) Fixed: Verbose output for posix
2fbee71 (tag: v1.11.1) Fixed: Regression bug on compiling for posix
afb703f (tag: v1.11.0) Update: API should now get ISA for building
2f74ee1 (tag: v1.10.9) Fixed: Checking compiler for null return
ef1675a Update: Minor performance improvement
30b0a15 (tag: v1.10.8) Fixed: satisfies now correctly uses matchAll
15f4548 (tag: v1.10.7) Update: Improved a little more the compiler finding so it doesn't try to search always on global path
d92094e (tag: v1.10.6) Update: Reduced memory allocations inside adv_diff and improved hexstring parsing algorithm
ac47330 (tag: v1.10.5) Update: Improved compilation API so now it doesn't require a full cache status
3d19eee (tag: v1.10.4) Fixed: Even more speed on the up to date status
0d0489e (tag: v1.10.3) Update: Improve performance of diffstatus
771bf17 (tag: v1.10.2) Fixed: old build warnings
391a97f (tag: v1.10.1) Fixed: Linking on LDC, LDC not polluting anymore user folder, simplified compilation API, added clean on force builds
0baabef (tag: v1.10.0) Added: Flag and inference for using existing objects
7fff146 Fixed: Cache for the new entries
5845e51 Fixed: Removed loggings
d9ef4bd Fixed: Windows is now using correct d_dependencies
054d065 Fixed: Not working on windows d_dependencies
bb3ee90 Added: Dirty builds
b03ee51 Fixed: d_dependencies received in some cases more information that wasn't being handled
2e11eaa Merge branch 'main' of github.com:MrcSnm/redub
f66ce90 Added: New test for dd dependencies
cc63e14 Added: New test for dd dependencies
e9ad51b (tag: v1.9.12) Update: Improvement for showing which file is dirty
9de05d3 Update: Improve info on which files weren't found on adv_diff and initial deps parsing
78fcf0e (tag: v1.9.11) Fixed: Bug where sometimes it would incorrectly identify as up to date
fd41243 (tag: v1.9.10) Fixed: subPackages would sometimes not get the correct version
2d40aba (tag: v1.9.9) Hotfix: Better error information when incompatible semver is found
9395c1c Fixed: Now supporting glob matching copy on copyFilse
36c0297 (tag: v1.9.8) Added: Support for wasm/webassembly OS and now the json cache is cleared after parsing a project, hide cache write log if it is too small
3aea3fc (tag: v1.9.7) Update version
edc84ec Merge pull request #22 from 0-v-0/fix-index
b61fdac Fixed: index out of range
5aed9e7 (tag: v1.9.6) Added: 'darwin' platform filter, fixed run execution by escaping its command
513cef7 (tag: v1.9.5) Fixed: Now none projects should not build and only run its commands. Added invalid targetType and fixed preGenerateCommands when inside configuration
201b79a (tag: v1.9.4) Fixed: Now the link files always are sent to their parents
f132fba (tag: v1.9.3) Fixed: Now differing dependency version from different depth level are updated
44c9728 (tag: v1.9.2) Fixed: Now correctly adding environment variables per project
c05848c (tag: v1.9.1) Added: Filter out hidden files from adv cache and fixed cache invalidation for linking step
36a1ecc (tag: v1.9.0) Added: Caching solution with print-ups with copy enough and up-to-date builds
efbeba1 (tag: v1.8.8) Fixed: Redub now handles up to date builds much better
a127a52 (tag: v1.8.7) Fixed: copyDir now make create a directory
79fbb01 (tag: v1.8.6) Added: Use hardlink instead of copy making it much faster, also added cache for linker
0da116a (tag: v1.8.5) Added: Initial binary caching
ed2547f WIP: Adding copyCache to compilation cache, so, the output files are stored somewhere else, also added cache clear based on redub version
50f576e (tag: v1.8.4) Fixed: Bug when  pkg-config does not exists
eb0a9a9 (tag: v1.8.3) Update: Added targetPath and targetName from CLI, while keeping the cache calculation smarter
37e59a2 (tag: v1.8.2) Added: pkg-config execution on linux
0ed9785 WIP: Adding pkg-config
dd0b3e0 (tag: v1.8.1) Update: Improved redub clean to try cleaning all the files that were generated in the process
31f989a (tag: v1.8.0) Update: Added redub test #10 support, and now the cache invalidation only occurs before building since it gives the opportunity to change the tree
ff05693 (tag: v1.7.12) Fixed: Now sourceLibrary with dependencies can be handled better
c54c213 (tag: v1.7.11) Update: Now the cache is being able to be calculated in parallel
ad50725 (tag: v1.7.10) Fixed: Issue #19 lflags were not being merged
db31e25 (tag: v1.7.9) Fixed: Wrong bug which made not be able to build single projects
7e18cc6 (tag: v1.7.8) Update: Auto clear compiler cache when changing redub version
7dc282c Fixed: More flexibility when assigning a defaultCompiler
c2b20ef (tag: v1.7.7) Update: Smarter log in every build type
ad358ad (newmain) Fixed: Faster dependency resolution by logging less information
7e32988 Update: Made the caching calculation be done in a separate thread for static libraries, making the program fully efficient
4171341 (tag: v1.7.6) Fixed: Build issue on linux
f22560b Fixed: Build issue on linux
a8beabe (tag: v1.7.5) Added: defaultCompiler, compilers cache for faster inference, and fixed #14
b15a6b2 (tag: v1.7.4) Fixed: Made the output shorter when uusing up to date builds [ignore time took]
846783d (tag: v1.7.3) Fixed: #16 compilation error for old compiler
0345c50 (tag: v1.7.2) Merge branch 'main' of github.com:MrcSnm/redub
1229ba3 Updated: Better support on preGenerateCommands + handling --single + more environment being parsed
71315cd Merge pull request #13 from jacob-carlborg/fix-build-docs
6504391 Fix build instructions
6150f16 Remove trailing whitespace
`;

    string err;
    ChangelogReport report;
    if(!parseChangelog(reportExample, report, err, "0", "0"))
        assert(false, "Some error ocurred while reading valid report: '"~err~"'");
    import std.stdio;
    writeln = formatChangelog(report);
}
# changelog-d
Tool for generating changelogs using git for the D programming language
Generates a markdown file using git log.
Also has a library API if there is a need for further customization.

## Usage:

```
     --from The from branch which this program will calculate the log [can also be a tag]
       --to The to branch which this program will get the log
   --output Output file path. Defaults to Changelog.md
-h   --help This help information.
```





# Output Example


# Changelog for redub v1.17.4

## Untagged
- Fixed #15 - Preprocess SDL file before using dub convert

## Fixed
-  Correctly injecting in json fetch
-  Problem where redub could not find replace redub from other folders
-  Support for linux
-  Remove comments from SDL before converting to JSON, handle buildTypes correctly from SDL converter, clean test files
-  Pending merge requirements weren't being processed with environment
-  #27, #28, expected artifacts now will only be evaluated at requirement time, removed it from build requirements, copy attributes on dir copy, fixed target name
-  Dynamic library names
-  Crash on empty adv cache formula and redub plugins are now global

## Update
-  Using existing phobos thisExePath
-  Proper way to get windows exe path
-  Redub now includes version of the compiler used to be built, throws an exception if an inexistent configuration is sent, defaults plugin compiler to be the same as the used one to build
-  Fixed #30 and #29. Also fixed issue when specifying a custom compiler with arch not triggering LDC anymore. Fixed issue where specifying global compiler would fai
-  Plugins won't include environment variables in the process of building itself
-  Do not output deps by default, this is causing compile time slowdown rather than good
-  Less memory allocation inside adv_diff and inference for simplified hashing when file bigger than 2MB


## Added
-  Fast build mode to update, fixed linker issue on macOS from stripping wrong extension
-  Redub update command
-  Redub fetches, fixed #32 (author issue), improved sdl->json parsing, improved redub clean, improved redub cache check after clean, parallel fetching
-  SDL->JSON parser to Redub, removing one more dependency from dub

|Changelog Metadata|
|------------------:|
|Generated with [changelog-d](https://code.dlang.org/packages/changelog-d) v1.0.3|
|Contribute at https://github.com/MrcSnm/changelog-d|

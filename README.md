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
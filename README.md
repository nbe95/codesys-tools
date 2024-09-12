# Codesys Tools

Here comes a handy collection of scripts to make your everyday life with Codesys a little more
comfortable.

Most of them are PowerShell scripts to ensure that they're running smoothly and without preparation
on any Windows host.

> [!IMPORTANT]
> I am not associated with *CODESYS Group*, *3S-Smart Software Solutions* or any associated software
> manufacturer or retailer in any form. I have been working with this tools for years and personally
> find them to be useful.

## :mag: Declaration Checker

Checks variable prefixes in code export files according to the Codesys recommendations on
[Hungarian Notation](https://content.helpme-codesys.com/en/LibDevSummary/varnames.html).

```powershell
.\check-declarations.ps1 [-Level Info] .\dir1\file1.exp, .\dir2, ...
```

## :pencil2: Code Formatter

Formats code export files according to common conventions and senseful recommendations.

```powershell
.\format-code.ps1 .\dir1\file1.exp, .\dir2, ...
```

## :wastebasket: Temporary Files Remover

Removes all those temporary files left by Codesys or associated tools, which keep cluttering your
hard drive. Once you're done working on a feature or a project, this script helps you to find those
files and delete them accordingly.

> [!CAUTION]
> This tool deletes files. As there's currently no dry-mode implemented, **use at  your own risk**!

```powershell
.\remove-tmp-files.ps1 [-Recursive] .\project_dir1, .\project_dir2, ...
```

```sh
./remove-tmp-files.sh [-r] ./project_dir
```

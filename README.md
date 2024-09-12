# Codesys Tools

Here comes a handy collection of scripts to make your eyerday life with Codesys a little more comfortbale.

Most of them are PowerShell scripts to ensure that they're runnung smoothly and without preparationon on any Windows host.

> [NOTE]
> I am not associated with *Codesys* or any partner software manufacturer in any form. I have been
> working with this tools for years and personally find them to be useful.

## Declaration Checker

Checks variable prefixes according to the Codesys recommendations on
[Hungarian Notation](https://content.helpme-codesys.com/en/LibDevSummary/varnames.html)

```powershell
./check-declarations.ps1 [-Level Info] .\dir1\file1.exp, .\dir2, ...
```

## Code Formatter

Formats code export files according to common conventions and senseful recommendations.

```powershell
./format-code.ps1 .\dir1\file1.exp, .\dir2, ...
```

## Temporary Files Remover

This script removes all those temporary files left by Codesys, which keep cluttering your hard drive.
Once you're done working on a feature or a project, this script helps you to find those files and delete them accordingly.

> [WARNING]
> :rotating_light: This tool deletes files. As there's currently no dry-mode implemented, **USE AT
> YOUR OWN RISK**.

```powershell
./remove-tmp-files.ps1 [-Recursive] .\project_dir1, .\project_dir2, ...
```

```sh
./remove-tmp-files.sh [-r] .\project_dir
```

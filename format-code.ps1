param (
    [string[]] $Targets = ("."),
    [switch] $Quiet = $false,
    [switch] $DryRun = $false
)

enum Result { Ok; Changed; Ignored }

Function Format-CodesysFile {
    param([string] $File)

    $Content = Get-Content -Raw -Path $File
    if ($Content.Length -eq 0) {
        Return [Result]::Ok
    }
    if ($Content.ToUpper().Contains("@NOFORMAT")) {
        Return [Result]::Ignored
    }

    $Formatted = $Content

    # Enforce spaces around operators :=, =>, <=, >=, <>, =, <, >
    $Formatted = $Formatted -replace ' *(:=|(?<!=|<)=>|<=(?!=|>)|>=|<>|(?<!=)=(?!=|>)|<(?!=|-)|(?<!=|-)>) *', ' $1 '

    # Enforce spaces before/after - and / (unless in arrows, comments, strings or constructed type like DT#1970-01-01-00:00:00)
    # Note: Find and mark relevant chars first, then replace them in a second step
    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''))|[\t ]*\/[\t ]*', '$1{slash}'
    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''|#[\d\-_:]+))|(?<!\W|\n)[\t ]*\-(?!>|-)[\t ]*', '$1{hyphen}'

    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''|#[\d\-_:]+))(?:{(?:slash|hyphen)})+', '$1'
    $Formatted = $Formatted -replace '{hyphen}', ' - '
    $Formatted = $Formatted -replace '{slash}', ' / '

    # Put spaces around other arithmetical operators +, *
    $Formatted = $Formatted -replace '(?<![\s\(+*]|^)([+*])(?![+*\)])', ' $1'
    $Formatted = $Formatted -replace '(?<![+*\(])([+*])(?![\s\)+*]|$)', '$1 '

    # Open and close comments with a single space
    $Formatted = $Formatted -replace '\(\*(?!$|\r?\n)\s*', '(* '
    $Formatted = $Formatted -replace '\s*(?<!^|\n)\*\)', ' *)'

    # Remove unnecessary semicolons after specific keywords
    $Formatted = $Formatted -replace '(?<=THEN|END_IF|END_FOR|END_WHILE|END_REPEAT|END_CASE);', ''

    # Initialize strings and arrays properly using square brackets
    $Formatted = $Formatted -replace '(?<!\S)STRING\s*?\((.+?)\)', 'STRING[$1]'
    $Formatted = $Formatted -replace 'ARRAY\s*?\[(.+?)\]', 'ARRAY[$1]'

    # Only use NOT operator with parentheses and remove any space between
    $Formatted = $Formatted -creplace '(?<!\w)NOT\s+(?!_)((?>[\w.]+(?>(?>\[(?>\((?<array>)|[^[\]]+|\](?<-array>))*(?(array)(?!))\]|\((?>\((?<expr>)|[^()]+|\)(?<-expr>))*(?(expr)(?!))\))?\.?)*)+)', 'NOT($1)'
    $Formatted = $Formatted -creplace 'NOT\s+\(', 'NOT('

    # Use capital data type prefixes and small time units (e.g. T#1s)
    @(
        "BYTE", "SINT", "USINT",
        "WORD", "INT", "DINT",
        "DWORD", "DINT", "UDINT",
        "TIME", "T",
        "TIME_OF_DAY", "TOD",
        "DATE", "D",
        "DATE_AND_TIME", "DT"
    ) | ForEach-Object {
        $Formatted = $Formatted -replace "$_#(\w+)", "$_#`$1"
    }
    @("d", "h", "m", "s", "ms") | ForEach-Object {
        $Formatted = $Formatted -replace "(?!\W)(T(?:IME)?)#((?:\d+[dhms]+)+)?(\d+)$_", "`$1#`$2`$3$_"
    }

    # Remove empty VAR blocks
    $Formatted = $Formatted -replace "(?m)^VAR([^\n]+)?\n\s*END_VAR\r?\n?", ""

    # Use consistent spacing for UDTs and enumerations
    $Formatted = $Formatted -replace "(?s)((?<!\w)TYPE\s+\w+\s*:)\s*\(\*(.*)\*\)\s*(?=\((?!\*)|STRUCT)", "(*`$2*)`r`n`$1`r`n" # First, move any inline-comment above type/enum declaration
    $Formatted = $Formatted -replace "(?s)TYPE\s+(\w+)\s*:\s*(\((?!\*)|STRUCT)(?:\r?\n)*", "TYPE `$1 :`r`n`$2`r`n"
    $Formatted = $Formatted -replace "\s*(\);|END_STRUCT)\s+END_TYPE;?", "`r`n`$1`r`nEND_TYPE"

    # Use at least one tab for indentation within any VAR/TYPE/STRUCT block
    Select-String -InputObject $Formatted -Pattern "(?smi)^(?<container>VAR|TYPE)(?:_\w+)?.*?\n+(?:\s*(?:STRUCT|\((?!\*))(?:\r?\n)*)?(?<content>.+?)\s*(?:\s*(?:END_STRUCT|\)\s*;)\s*)?^END_\<container>" -AllMatches | ForEach-Object {
        $_.Matches | ForEach-Object {
            $Block = $_.Groups["content"]
            if ($Block.Length) {
                $Indented = $Block -replace "(?m)^\t?(.*)$", "`t`$1"
                $Formatted = $Formatted.Replace($Block, $Indented)
            }
        }
    }

    # Remove leading/trailing space and spaces in round/square brackets
    $Formatted = $Formatted -replace '(?<=\r?\n) +', ''
    $Formatted = $Formatted -replace '[\t ]+(?=\r?\n)', ''
    $Formatted = $Formatted -replace '(?<=[\(\[]) +', ''
    $Formatted = $Formatted -replace ' +(?=[\)\]])', ''

    # Remove superfluous line breaks
    $Formatted = $Formatted -replace '(\r?\n)+(\(\* @(?:END_DECLARATION|OBJECT_END) .+? \*\))', '$1$2'
    $Formatted = $Formatted -replace '(\r?\n)+(END_(?:VAR|TYPE))', '$1$2'
    $Formatted = $Formatted -replace '(\r?\n){3,}(END_(?:PROGRAM|FUNCTION_BLOCK|FUNCTION))', '$1$2'
    $Formatted = $Formatted -replace '((?:\r?\n){3})(?:\r?\n)+', '$1'

    # Remove multiple spaces and those surrounded by tabs
    $Formatted = $Formatted -replace '(?:(?<=\t) +| +(?=\t))', ''
    $Formatted = $Formatted -replace ' +', ' '

    # Remove spaces in front of semicolons
    $Formatted = $Formatted -replace '[\t ]+(?=;)', ''

    # Because of performance and encoding issues, for the following operations each line must be processed individually
    $Lines = @()
    $Formatted -split "\r\n" | ForEach-Object {

        # Skip any non-code-related lines
        if ($_ -match '^(?!VISUALISATION|_|\(\* @).') {

            # Make sure each comma has no leading space and is followed by exactly one space, unless at the end of a line
            $FormattedLine = $_ -replace '\s*?,(?!\t|\r?\n|$)(?: +)?', ', '
            $Lines += $FormattedLine
        } else {
            $Lines += $_
        }
    }
    $Formatted = $Lines -join [Environment]::NewLine
    Remove-Variable Lines

    # Check if anything was modified
    if ((Compare-Object $Content $Formatted -SyncWindow 0 -CaseSensitive).Length -ne 0) {
        # Save formatted file if not running dryly
        if (-not $DryRun) {
            Set-Content $File $Formatted -NoNewline
        }
        Return [Result]::Changed
    }
    Return [Result]::Ok
}


$CountAll = 0
$CountChanged = 0
$CountIgnored = 0

# Search the given target path(s) recursively for export files
Get-ChildItem -Path $Targets -File -Include *.exp -Exclude _*, -FollowSymLink -Recurse | ForEach-Object {

    # Format code file and print result
    $File = Resolve-Path -Relative $_
    $Result = Format-CodesysFile -File $File

    $ResultStr = "  OK  "
    $ResultStyle = @{ForegroundColor = "Green"}
    $CountAll++

    If ($Result -eq [Result]::Changed) {
        $ResultStr = "CHANGE"
        $ResultStyle = @{ForegroundColor = "Red"}
        $CountChanged++
    }

    If ($Result -eq [Result]::Ignored) {
        $ResultStr = "IGNORE"
        $ResultStyle = @{ForegroundColor = "Yellow"}
        $CountIgnored++
    }

    if (-not $Quiet) {
        Write-Host "[" -NoNewline -ForegroundColor "DarkGray"
        Write-Host $ResultStr -NoNewline @ResultStyle
        Write-Host "] " -NoNewline -ForegroundColor "DarkGray"
    }
    if (-not $Quiet -or $Result -eq [Result]::Changed) {
        Write-Host $File
    }
}

# Print overall result
if (-not $Quiet) {
    Write-Host ("`n{0} file(s) processed, {1} formatted, {2} ignored." -f $CountAll, $CountChanged, $CountIgnored)
}

# Exit successfully if no files were changed
if ($CountChanged -gt 0) {
    exit 1
}
exit 0

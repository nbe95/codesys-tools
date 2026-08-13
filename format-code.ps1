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

    $NewLine = [Environment]::NewLine
    $Formatted = $Content

    # Eliminate nested comments (repeat until all are done)
    do {
        $Before = $Formatted
        $Formatted = $Formatted -replace "(?s)\(\*((?:.(?!\*\)))*?)\(\*", "(*`$1 "
        $Formatted = $Formatted -replace "(?s)\*\)((?:.(?<!\(\*))*?)\*\)", " `$1*)"
    } until ($Formatted -eq $Before)

    # Enforce spaces around operators :=, =>, <=, >=, <>, =, <, > (unless part of arrows)
    $Formatted = $Formatted -replace ' *(:=|(?<!=|<)=>|<=(?!=|>)|>=|<>|(?<!=)=(?!=|>)|<(?!=|-)|(?<!=|-)>) *', " `$1 "

    # Enforce spaces before and after arithmetical operators (unless part of arrows, comments or strings)
    # Note: Find and mark relevant chars first, then replace them in a second step
    $Formatted = $Formatted -replace "(?s)(\(\*.*?\*\)|'.*?')|[\t ]*\+[\t ]*", "`$1{plus}"
    $Formatted = $Formatted -replace "(?s)(\(\*.*?\*\)|'.*?'|#[\d\-_:]+)|(?<=\w)[\t ]*\-(?!>|-)[\t ]*", "`$1{minus}" # allow minus prefix (e.g. -1) and in constructed types like DT#0000-00-00:00:00:00
    $Formatted = $Formatted -replace "(?s)(\(\*.*?\*\)|'.*?')|[\t ]*\*[\t ]*", "`$1{asterisk}"
    $Formatted = $Formatted -replace "(?s)(\(\*.*?\*\)|'.*?')|[\t ]*\/[\t ]*", "`$1{slash}"

    $Formatted = $Formatted -replace "(?s)(\(\*.*?\*\)|'.*?'|#[\d\-_:]+)(?:{(?:plus|minus|asterisk|slash)})+", '$1'
    $Formatted = $Formatted -replace "{plus}", " + "
    $Formatted = $Formatted -replace "{minus}", " - "
    $Formatted = $Formatted -replace "{asterisk}", " * "
    $Formatted = $Formatted -replace "{slash}", " / "

    # Open and close comments with a single space
    $Formatted = [regex]::Replace($Formatted, '(?s)\(\*(.*?)\*\)', {
        param($Match)
        $Content = $Match.Groups[1].Value
        if ($Content -match '^\s*@') { # ignore system comments (first value preceded by an @)
            $Match.Value
        } else {
            "(* " + $Content.Trim() + " *)"
        }
    })

    # Remove unnecessary semicolons after specific keywords
    $Formatted = $Formatted -replace "(?<=THEN|END_IF|END_FOR|END_WHILE|END_REPEAT|END_CASE)\s*?;", ""

    # Initialize strings and arrays properly using square brackets
    $Formatted = $Formatted -replace "(?<!\S)STRING\s*?[\[\(](.+?)[\]\)]", "STRING[`$1]"
    $Formatted = $Formatted -replace "(?<!\S)ARRAY\s*?\[(.+?)\]", "ARRAY[`$1]"

    # Only use NOT operator with parentheses and remove any space between (repeat until all are done)
    do {
        $Before = $Formatted
        $Formatted = $Formatted -creplace "(?<!\w)NOT\s+(?!_)((?>[\w.]+(?>(?>\[(?>\((?<array>)|[^[\]]+|\](?<-array>))*(?(array)(?!))\]|\((?>\((?<expr>)|[^()]+|\)(?<-expr>))*(?(expr)(?!))\))?\.?)*)+)", "NOT(`$1)"
        $Formatted = $Formatted -creplace "NOT\s+\(", "NOT("
    } until ($Formatted -eq $Before)

    # Use capital data type prefixes and small time units (e.g. T#1s)
    @(
        "BYTE", "SINT", "USINT",
        "WORD", "INT", "UINT",
        "DWORD", "DINT", "UDINT",
        "TIME", "T",
        "TIME_OF_DAY", "TOD",
        "DATE", "D",
        "DATE_AND_TIME", "DT"
    ) | ForEach-Object {
        $Formatted = $Formatted -replace "$_#([\w\-]+)", "$_#`$1"
    }
    @("d", "h", "m", "s", "ms") | ForEach-Object {
        $Formatted = $Formatted -replace "(?!\W)(T(?:IME)?)#((?:\d+[dhms]+)+)?(\d+)$_", "`$1#`$2`$3$_"
    }

    # Use consistent spacing for UDTs and enumerations
    $Formatted = $Formatted -replace "(?s)((?<!\w)TYPE\s+\w+\s*:)\s*\(\*(.*?)\*\)\s*(\((?!\*)|STRUCT)\s*", "(*`$2*)$NewLine`$1$NewLine`$3$NewLine" # First, move any inline-comment above type/enum declaration
    $Formatted = $Formatted -replace "(?s)TYPE\s+(\w+)\s*?:\s*(\((?!\*)|STRUCT)\s*", "TYPE `$1 :$NewLine`$2$NewLine"
    $Formatted = $Formatted -replace "\s*(\)\s*;|END_STRUCT)\s+END_TYPE;?", "$NewLine`$1$($NewLine)END_TYPE"

    # Remove empty VAR blocks
    $Formatted = $Formatted -replace "(?m)^VAR([^\n]+)?\n\s*END_VAR\r?\n?", ""

    # Enforce trivial format within any VAR/TYPE/STRUCT block
    $ExtractRegex = '(?smi)' +
        '^(?<container>VAR|TYPE)(?:_\w+)?(?:\s+\w+)?(?:\s*:\s*)?\s*[\r\n]+' +       # Header + optional name + :
        '(?:' +
            '(?:\s*STRUCT\s*[\r\n]+(?<content>.*?)\s*END_STRUCT\s*;?\s*[\r\n]+)' +  # Case A: Struct
            '|' +
            '(?:\s*(?<enum>\(\s*[\r\n]+(?<content>.*?)\s*\))\s*;\s*[\r\n]+)' +      # Case B: Enum
            '|' +
            '(?<content>.*?)\s*' +                                                  # Case C: Var
        ')' +
        '(?=^\s*END_\k<container>)'
    Select-String -InputObject $Formatted -Pattern $ExtractRegex -AllMatches | ForEach-Object {

        # Note: Last match must be processed first, because results may get manipulated in place
        $Matches = $_.Matches
        [array]::Reverse($Matches)

        $Matches | ForEach-Object {
            $Block = $_.Groups["content"]
            if ($Block.Length) {
                $BlockFormatted = $Block.Value

                # Only one enum definition per line (ignore comments and parentheses)
                if ($_.Groups["enum"].Success) {
                    $NestedParentheses = '\((?>[^()]+|(?<open>\()|(?<-open>\)))+(?(open)(?!))\)'
                    $BlockFormatted = [regex]::Replace($BlockFormatted, "(\(\*.*?\*\))|($NestedParentheses)|(?<comma>,(?:\r?\n)?)", {
                        if ($args[0].Groups["comma"].Success) { ",`t$NewLine" } else { $args[0].Value }
                    })
                }

                # Ensure at least one tab of indentation
                $BlockFormatted = $BlockFormatted -replace "(?m)^\t?(.*)`$", "`t`$1"

                # Replace actual block by position and length
                $Formatted = $Formatted.Remove($Block.Index, $Block.Length).Insert($Block.Index, $BlockFormatted)
            }
        }
    }

    # Remove superfluous line breaks
    $Formatted = $Formatted -replace "(\r?\n)+(\(\* @\b(?:END_DECLARATION|OBJECT_END)\b .+? \*\))", "`$1`$2"
    $Formatted = $Formatted -replace "((?<!END_)\b(?:VAR|TYPE)(?:_\w+)?\b.*?)(\r?\n)+", "`$1`$2"
    $Formatted = $Formatted -replace "(\r?\n)+(\bEND_(?:VAR|TYPE)\b)", "`$1`$2"
    $Formatted = $Formatted -replace "((?<!END_)\b(?:PROGRAM|FUNCTION_BLOCK|FUNCTION)\b)(\r?\n)+", "`$1`$2"
    $Formatted = $Formatted -replace "(\r?\n){3,}(\bEND_(?:PROGRAM|FUNCTION_BLOCK|FUNCTION)\b)", "`$1`$2"
    $Formatted = $Formatted -replace "((?:\r?\n){3})(?:\r?\n)+", "`$1"

    # Remove leading/trailing space, spaces in round/square brackets
    $Formatted = $Formatted -replace "(?m)^ +", ""
    $Formatted = $Formatted -replace "(?m) +(?=\r?\n|`$)", ""
    $Formatted = $Formatted -replace "(?m)[\t ]+(?=\r?\n|`$)", ""
    $Formatted = $Formatted -replace "(?<=[\(\[]) +", ""
    $Formatted = $Formatted -replace " +(?=[\)\]])", ""

    # Remove multiple spaces, those surrounded by tabs and right before semicolons
    $Formatted = $Formatted -replace "(?:(?<=[\t ]) +| +(?=\t))", ""
    $Formatted = $Formatted -replace "[\t ]+(?=;)", ""

    # Because of performance and encoding issues, for the following operations each line must be processed individually
    $Lines = @()
    $Formatted -split "\r\n" | ForEach-Object {

        # Skip any non-code-related lines
        if ($_ -match "^(?!VISUALISATION|_|\(\* @).") {
            $LineFormatted = $_

            # Make sure each comma has no leading space and is followed by exactly one space, unless in a table or at the end of a line
            $LineFormatted = $LineFormatted -replace "\s+(?=,)", ""
            $LineFormatted = $LineFormatted -replace ",(?!\t|`$) *", ", "
            $Lines += $LineFormatted
        } else {
            $Lines += $_
        }
    }
    $Formatted = $Lines -join $NewLine
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

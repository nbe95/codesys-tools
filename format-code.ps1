param (
    [string[]]$Targets = (".\")
)

Function Format-CodesysFile {
    param([string] $File)

    $Content = Get-Content -Raw $File
    if ($Content.Length -eq 0) {
        Return 0
    }
    if ($Content.ToUpper().Contains("@NOFORMAT")) {
        Return 2
    }

    $Formatted = $Content

    # Enforce spaces around operators :=, =>, <=, >=, <>, =, <, >
    $Formatted = $Formatted -replace ' *?(:=|=>|<=|>=|<>|=|<(?!=|-)|(?<!=|-)>) *?', ' $1 '

    # Enforce spaces before/after - and / (unless in comments, strings or constructed type like DT#1970-01-01-00:00:00)
    # Note: Find and mark relevant chars first, then replace them in a second step
    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''))|[\t ]*\/[\t ]*', '$1{slash}'
    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''|#[\d\-_:]+))|(?<!\W|\n)[\t ]*\-[\t ]*', '$1{hyphen}'

    $Formatted = $Formatted -replace '((?:\(\*(?:.|\r?\n)*?\*\)|''.*?''|#[\d\-_:]+))(?:{(?:slash|hyphen)})+', '$1'
    $Formatted = $Formatted -replace '{hyphen}', ' - '
    $Formatted = $Formatted -replace '{slash}', ' / '

    # Put spaces around other arithmetical operators +, *
    $Formatted = $Formatted -replace '(?<![\s\(+*]|^)([+*])(?![+*\)])', ' $1'
    $Formatted = $Formatted -replace '(?<![+*\(])([+*])(?![\s\)+*]|$)', '$1 '

    # Remove leading/trailing space and spaces in round/square brackets
    $Formatted = $Formatted -replace '(?<=\r?\n) +', ''
    $Formatted = $Formatted -replace '[\t ]+(?=\r?\n)', ''
    $Formatted = $Formatted -replace '(?<=[\(\[]) +', ''
    $Formatted = $Formatted -replace ' +(?=[\)\]])', ''

    # Open and close comments with a single space
    $Formatted = $Formatted -replace '\(\*(?!$|\r?\n)\s*', '(* '
    $Formatted = $Formatted -replace '\s*(?<!^|\n)\*\)', ' *)'

    # Remove multiple spaces and those surrounded by tabs
    $Formatted = $Formatted -replace '(?:(?<=\t) +| +(?=\t))', ''
    $Formatted = $Formatted -replace ' +', ' '

    # Remove spaces in front of semicolons
    $Formatted = $Formatted -replace '[\t ]+(?=;)', ''

    # Remove superfluous line breaks
    $Formatted = $Formatted -replace '(\r?\n)+(\(\* @(?:END_DECLARATION|OBJECT_END) .+? \*\))', '$1$2'
    $Formatted = $Formatted -replace '(\r?\n)+(END_(?:VAR|TYPE))', '$1$2'
    $Formatted = $Formatted -replace '(\r?\n){3,}(END_(?:PROGRAM|FUNCTION_BLOCK|FUNCTION))', '$1$2'
    $Formatted = $Formatted -replace '((?:\r?\n){3})(?:\r?\n)+', '$1'

    # Remove unnecessary semicolons after specific keywords
    $Formatted = $Formatted -replace '(?<=THEN|END_IF|END_FOR|END_WHILE|END_REPEAT|END_CASE);', ''

    # Initialize strings and arrays properly using square brackets
    $Formatted = $Formatted -replace '(?<!\S)STRING\s*?\((.+?)\)', 'STRING[$1]'
    $Formatted = $Formatted -replace 'ARRAY\s*?\[(.+?)\]', 'ARRAY[$1]'

    # Only use NOT operator with parentheses and remove any space between
    $Formatted = $Formatted -creplace '(?<=\W)NOT\s+(?!_)((?>\w+(?>(?>\[(?>\((?<array>)|[^[\]]+|\](?<-array>))*(?(array)(?!))\]|\((?>\((?<expr>)|[^()]+|\)(?<-expr>))*(?(expr)(?!))\))?\.?)*)+)', 'NOT($1)'
    $Formatted = $Formatted -creplace 'NOT\s+\(', 'NOT('

    # Because of performance and encoding issues, for the following operations each line must be processed individually
    $Lines = @()
    foreach ($Line in $Formatted -split "\r\n") {

        # Skip any non-code-related lines
        if ($Line -match '^(?!VISUALISATION|_|\(\* @).') {

            # Make sure each comma has no leading space and is followed by exactly one space, unless at the end of a line
            $FormattedLine = $Line -replace '\s*?,(?!\t|\r?\n|$)(?: +)?', ', '
            $Lines += $FormattedLine
        } else {
            $Lines += $Line
        }
    }
    $Formatted = $Lines -join [Environment]::NewLine
    Remove-Variable Lines

    # Check if anything was modified
    if ((Compare-Object $Content $Formatted -SyncWindow 0).Length -ne 0) {
        Set-Content $File $Formatted -NoNewline
        Return 1
    }
    Return 0
}


$CountAll = 0
$CountChanged = 0
$CountIgnored = 0

# Search the given target path(s) recursively for export files
Get-ChildItem -Path $Targets -File -Filter *.exp -Exclude _* -FollowSymLink -Recurse | ForEach-Object {

    # Format code and print result
    $Result = Format-CodesysFile $_.FullName

    $ResultStr = "  OK  "
    $ResultStyle = @{ForegroundColor = "Green"}
    $CountAll++

    If ($Result -eq 1) {
        $ResultStr = "CHANGE"
        $ResultStyle = @{ForegroundColor = "Red"}
        $CountChanged++
    }

    If ($Result -eq 2) {
        $ResultStr = "IGNORE"
        $ResultStyle = @{ForegroundColor = "Yellow"}
        $CountIgnored++
    }

    Write-Host "[" -NoNewline -ForegroundColor "DarkGray"
    Write-Host ("{0}" -f $ResultStr) -NoNewline @ResultStyle
    Write-Host "] " -NoNewline -ForegroundColor "DarkGray"
    Write-Host $_.FullName
}

# Print overall result
Write-Host ("`n{0} file(s) processed, {1} formatted, {2} ignored." -f $CountAll, $CountChanged, $CountIgnored)

if ($CountChanged -gt 0) {
    exit 1
}
exit 0

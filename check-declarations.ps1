param (
    [string[]] $Targets = @(".\"),
    [ValidateSet("Error", "Warning", "Info", "Debug")][string] $Level = "Info"
)

enum LogLevel { Error; Warning; Info; Debug; }

function Get-CenteredText {
    param(
        [string] $Message,
        [int] $Size = $Host.UI.RawUI.BufferSize.Width
    )
    $SpacesBefore = ([Math]::Max(0, [Math]::Floor(($Size - $Message.Length) / 2)))
    $SpacesAfter = $Size - $SpacesBefore - $Message.Length
    return ("{0}{1}{2}" -f (" " * $SpacesBefore), $Message, (" " * $SpacesAfter))
}

function Write-Log {
    param(
        [LogLevel] $LogLevel,
        [string] $Message,
        [string] $File,
        [string] $Var
    )
    if ($LogLevel -gt $Level) {
        return;
    }

    $Color = switch ($LogLevel) {
        "Debug" { "DarkGray" }
        default { (Get-Host).UI.RawUI.ForegroundColor }
    }
    $EmphColor = switch ($LogLevel) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        "Debug" { "DarkGray" }
        default { (Get-Host).UI.RawUI.ForegroundColor }
    }
    $VarColor = "Magenta"
    Write-Host "[" -NoNewline -ForegroundColor "DarkGray"
    Write-Host (Get-CenteredText -Message $LogLevel.ToString().ToUpper() -Size 7) -NoNewline -ForegroundColor $EmphColor
    Write-Host "] " -NoNewline -ForegroundColor "DarkGray"
    if ($File) {
        Write-Host "$($File): " -NoNewline -ForegroundColor $Color
    }
    if ($Var) {
        Write-Host $Var -NoNewline -ForegroundColor $VarColor
        Write-Host " - " -NoNewline -ForegroundColor $Color
    }
    Write-Host $Message -ForegroundColor $Color
}

# Mapping of known instancable types and aliases
$TypeMapping = @{   # Will be extended at runtime by custom types (FBs, structs, enums)
    # Basic data types
    BOOL = "x";
    BYTE = "by";
    SINT = "si";
    INT = "i";
    DINT = "di";
    USINT = "usi";
    UINT = "ui";
    UDINT = "udi";
    WORD = "w";
    DWORD = "dw";
    REAL = "r";
    LREAL = "lr";
    DATE = "d";
    TIME = "tim";
    TIME_OF_DAY = "tod";
    TOD = "tod";
    DATE_AND_TIME = "dt";
    DT = "dt";
    STRING = "s";

    # POUs from stdlib
    TON = "TON";
    TOF = "TOF";
    TP = "TP";
    RTC = "RTC";
    R_TRIG = "RTRIG";
    F_TRIG = "FTRIG";
    CTU = "CTU";
    CTD = "CTD";
    CTUD = "CTUD";
    RS = "RS";
    SR = "SR";
    SEMA = "SEMA";
    BLINK = "BLINK";
    PACK = "fb";
    UNPACK = "fb";
}
$TypeAliases = @{}  # Will be extended at runtime by custom aliases

function Get-IsCamelCase {
    param([string] $Name)
    return $Name -cmatch "^[A-Z]{1,3}[a-z\d]+_?(?:[A-Z\d]{1,3}[a-z\d]+_?)*[A-Z\d]{0,2}(?:_[\w\d]+)?$" # Last group tolerates unit suffixes like _deg100 or _mV
}

function Get-IsUpperCase {
    param([string] $Name)
    return $Name -cmatch "^[A-Z\d_]+$"
}

function Get-AllMatchingBlocks {
    param(
        [string] $Content,
        [string] $Pattern
    )
    return Select-String -InputObject $Content -Pattern $Pattern -AllMatches | ForEach-Object { $_.Matches }
}

function Test-CodesysFile {
    param([string] $File)
    $Warnings = 0
    $Errors = 0

    $Content = Get-Content -Raw $File
    if ($Content.Length -gt 0) {

        # Check POU naming conventions
        $PouNames = Get-AllMatchingBlocks $Content "(?mi)^(?:PROGRAM|FUNCTION(?:_BLOCK)?|TYPE|ACTION|VISUALISATION)\s+([\w\d]+)(?:\s+_VISU_TYPES)?\s*:?\s*(?:[\w\d,]+)?"
        $PouNames | ForEach-Object {
            if ($_ -match "(?mi)^(?<object>\w+)\s+(?<name>[\w\d+]+)") {
                $Name = $Matches["name"]
                Write-Log Debug "Checking POU name:", $Name $File

                $IsCamelCase = Get-IsCamelCase $Name
                $IsUpperCase = Get-IsUpperCase $Name
                if (-not $IsCamelCase -and -not $IsUpperCase) {
                    Write-Log Warning "POU name does neither match PascalCase nor UPPER_CASE convention." $File $Name
                    $Warnings++;
                }
            }
        }

        # Extract each declaration block (e.g. VAR...END_VAR)
        $DeclarationBlocks = Get-AllMatchingBlocks $Content "(?smi)^(?<context>(?<container>VAR|STRUCT)(?:_(?:INPUT|OUTPUT|IN_OUT|GLOBAL|EXTERNAL))?(?:\s+(?:CONSTANT|RETAIN|PERSISTENT))*)\r?\n(?<content>.*?)^END_\<container>"
        $DeclarationBlocks | ForEach-Object {

            # Extract and check each distinct declaration
            $Context = $_.Groups["context"]
            $ContentWithoutComments = $_ -Replace "\(\*.*?\*\)", ""
            $Declarations = Get-AllMatchingBlocks $ContentWithoutComments "(?smi)([\w]+\s*(?:AT\s+[%\w.*]+)?\s*:\s*[^;]*?\s*;)"
            $Declarations | ForEach-Object {

                # Perform checks on declaration and store results
                Write-Log Debug "Parsing declaration. Context: $($Context), declaration: $($_)" $File
                $Result = Test-VarDeclaration -File $File -Context $Context -Declaration $_
                $Warnings += $Result[0]
                $Errors += $Result[1]
            }
        }
    }
    Return $Warnings, $Errors
}

function Test-VarDeclaration {
    param(
        [string] $File,
        [string] $Context,
        [string] $Declaration
    )
    $Warnings = 0
    $Errors = 0

    # Split declaration into its parts
    if ($Declaration -cmatch "(?sm)(?<var>(?:(?<prefix>(?:[GS]+_)?(?:[A-Z]+|[a-z]+)?)_)?(?<name>\S+?))\s*(?<addr>AT\s+[%\w.*]+)?\s*:\s*(?<type>[\w\s\[\].,]+?)(?:\s*:=\s*(?<init>.*?))?\s*;") {
        $Var = $Matches["var"]
        $Prefix = $Matches["prefix"]
        $Name = $Matches["name"]
        $Type = $Matches["type"]
        # $Addr = $Matches["addr"]
        # $Init = $Matches["init"]

        # Check naming conventions
        $Underscores = (Select-String -InputObject $Name -Pattern "_" -AllMatches).Matches.Count
        if ($Underscores -gt 1) {
            Write-Log Warning "Name contains more than one underscore." $File $Var
            $Warnings++;
        }

        $IsCamelCase = Get-IsCamelCase $Name
        $IsUpperCase = Get-IsUpperCase $Name
        $IsSingleCharInt = $Name -cmatch "^[a-z]$" -and $Type -match "U?INT" # Allow single-char names for integers, e.g. for indices like "n"
        if (-not $IsCamelCase -and -not $IsUpperCase -and -not $IsSingleCharInt) {
            Write-Log Warning "Variable name does neither match PascalCase nor UPPER_CASE convention." $File $Var
            $Warnings++;
        }

        # Check prefix
        $IsStruct = $Context.Contains("STRUCT")
        $ExpectedPrefixes = @(Get-ValidVarPrefixes -Context $Context -Type $Type)
        $ExpectedPrefixesLog = $ExpectedPrefixes -join ", "
        if (-not $ExpectedPrefixes) {
            Write-Log Info "Cannot check variable prefix; no declaration found for $($Type)." $File $Var
            $ExpectedPrefixesLog = "?"
        }
        if ($Prefix) {
            if ($ExpectedPrefixes -and -not $ExpectedPrefixes.Contains($Prefix)) {
                Write-Log Error "Variable prefix does not match declaration. Current: $($Prefix), expected: $($ExpectedPrefixesLog)" $File $Var
                $Errors++;
            }
        } elseif (-not $IsSingleCharInt) {
            if ($IsStruct) {
                Write-Log Warning "Variable prefix missing in struct. Expected: $($ExpectedPrefixesLog)" $File $Var
                $Warnings++;
            } else {
                Write-Log Error "Variable prefix missing. Expected: $($ExpectedPrefixesLog)" $File $Var
                $Errors++;
            }
        }
    }
    return $Warnings, $Errors
}

function Get-ValidVarPrefixes {
    param(
        [string] $Context,
        [string] $Type
    )
    $Type = $Type.ToUpper()
    $Context = $Context.ToUpper()

    # Resolve custom aliases
    $IsAlias = $false
    if ($TypeAliases.ContainsKey($Type)) {
        $IsAlias = $true
        $Type = $TypeAliases[$Type].ToUpper()
    }

    # Build possible prefixes by joining distinctive components
    $PrefixesGlobal = @("")
    if ($Context.Contains("GLOBAL") -or $Context.Contains("EXTERNAL")) {
        $PrefixesGlobal = @("g", "G_", "GS_")
    }

    $PrefixConst = if ($Context.Contains("CONSTANT")) { "c" } else { "" }

    $PrefixType = ""
    if ($Type.Contains("POINTER TO")) { $PrefixType += "p" }
    if ($Type -match "ARRAY\[[\d\w\s.,]+\] OF") { $PrefixType += "a" }

    $BaseType = ""
    foreach ($TypeKey in $TypeMapping.Keys) {
        if ($Type -match "(?m)(?<!\w)$TypeKey(?:\s*[\[\(][\w\d\s.,]+[\]\)])?\s*$") {
            $BaseType = $TypeMapping[$TypeKey]
            break
        }
    }
    if (-not $BaseType) {
        return @()   # Return nothing if base type could not be mapped
    }

    # Allow base type prefix as well as "t" for aliases
    $ValidCombinations = $PrefixesGlobal.ForEach({ $_ + $PrefixConst + $PrefixType + $BaseType })
    if ($IsAlias) {
        $ValidCombinations += $PrefixesGlobal.ForEach({ $_ + $PrefixConst + "t" })
    }
    return $ValidCombinations
}

function Read-CustomTypesAndAliases {
    param([string] $File)
    $Content = Get-Content -Raw $File
    $ContentWithoutComments = $Content -Replace "\(\*.*?\*\)", ""

    # Store names and desired prefix of function blocks
    $FunctionBlocks = Get-AllMatchingBlocks $ContentWithoutComments "(?mi)^FUNCTION_BLOCK\s+(?:[\w\d]+)"
    $FunctionBlocks | ForEach-Object {
        if ($_ -match "FUNCTION_BLOCK\s+(?<name>[\w\d]+)") {
            if ($TypeMapping.ContainsKey($Matches["name"])) {
                Write-Log Error "Type prefix for $($Matches["name"]) is defined more than once." $File
            } else {
                $TypeMapping.Add($Matches["name"], "fb")
                Write-Log Debug "Mapped custom type prefix: $($Matches["name"]) -> fb" $File
            }
        }
    }

    # Store names and desired prefix of enums and structs
    $EnumsAndStructs = Get-AllMatchingBlocks $ContentWithoutComments "(?smi)^TYPE\s+(?:[\w\d]+)\s*:[\s\r\n]*(?:STRUCT|\()"
    $EnumsAndStructs | ForEach-Object {
        if ($_ -match "TYPE\s+(?<name>[\w\d]+)\s*:[\s\r\n]*(?<struct>STRUCT|\()") {
            if ($TypeMapping.ContainsKey($Matches["name"])) {
                Write-Log Error "Type prefix for $($Matches["name"]) is defined more than once." $File
            } else {
                $Value = if ($Matches["struct"] -eq "STRUCT") { "st" } else { "e" }
                $TypeMapping.Add($Matches["name"], $Value)
                Write-Log Debug "Mapped custom type prefix: $($Matches["name"]) -> $($Value)" $File
            }
        }
    }

    # Grab names and definition of type aliases
    # (i.e. any other types which were not either a struct or an enum)
    $AliasDefs = Get-AllMatchingBlocks $ContentWithoutComments "(?smi)^TYPE\s+(?:[\w\d]+)\s*:\s*(?:.+)\s*;"
    $AliasDefs | ForEach-Object {
        if ($_ -match "TYPE\s+(?<name>[\w\d]+)\s*:\s*(?<definition>.+)\s*;") {
            if (-not $TypeMapping.ContainsKey($Matches["name"])) {
                if ($TypeAliases.ContainsKey($Matches["name"])) {
                    Write-Log Error "Type alias for $($Matches["name"]) is defined more than once." $File
                } else {
                    $TypeAliases.Add($Matches["name"], $Matches["definition"])
                    Write-Log Debug "Mapped custom type alias: $($Matches["name"]) -> $($Matches["Value"])" $File
                }
            }
        }
    }
}

$CountAll = 0
$CountWarnings = 0
$CountErrors = 0

# Search the given target path(s) recursively for export files
$ExpFiles = Get-ChildItem -Path $Targets -File -Filter *.exp -Exclude _* -FollowSymLink -Recurse

# Scan all POUs for custom instancable types
$ExpFiles | ForEach-Object {
    Read-CustomTypesAndAliases -File $_.FullName
}

# Perform actual check
$ExpFiles | ForEach-Object {
    $Result = Test-CodesysFile -File $_.FullName
    $CountAll++
    $CountWarnings += $Result[0]
    $CountErrors += $Result[1]
}

# Print overall result
Write-Host ("`n{0} file(s) processed, {1} error(s), {2} warning(s)." -f $CountAll, $CountErrors, $CountWarnings)

if ($CountErrors -gt 0) {
    exit 1
}
exit 0

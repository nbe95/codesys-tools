BeforeAll {
    function FindEntry {
        [cmdletbinding()]
        param(
            [parameter(Mandatory = $true, ValueFromPipeline = $true)] $Input,
            [string] $Class,
            [string] $Var,
            [string] $Msg,
            [string] $Actual,
            [string[]] $Expected = @(),     # if present, all items must match
            [string] $Keyword
        )
        foreach ($Line in $Input) {
            if ($Line -Match "(?mi)^\[\s*(?<cls>\w+)\s*\] (?<file>.+): (?<var>.+) - (?<msg>.*?)(?: expected: (?<exp>.+?))?(?:, actual: (?<act>.+?))?`$") {
                $ExpArray = $Matches["exp"] -split ", "
                $ExpAreEqual = @(Compare-Object $Expected $ExpArray -SyncWindow 0).Length -eq 0
                if ((-not $Class        -or $Class -eq $Matches["cls"]) -and
                    (-not $Var          -or $Var -eq $Matches["var"]) -and `
                    (-not $Actual       -or $Actual -eq $Matches["act"]) -and `
                    (-not $Expected     -or $ExpAreEqual) -and `
                    (-not $Keyword      -or $Matches["msg"] -like "*$Keyword*")) {
                    return $Line
                }
            }
        }
        return $null
    }

    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\check-declarations.ps1"
    $InputDir = Resolve-Path -Relative "$PSScriptRoot\input"
}

Describe "Check declaration checker" {

    It "Basic declaration parsing and deduction" {
        PowerShell $Cmd "$InputDir\types.exp" | Tee-Object -Variable Output | Out-Host

        $Output | FindEntry -Class "ERROR" -Var "Nothing" -Expected "x" -Keyword "missing" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "_Underscore" -Expected "x" -Keyword "missing" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Invalid" -Expected "?" -Keyword "missing" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "INFO"  -Var "Invalid" -Keyword "no declaration found" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "y_Bool" -Actual "y" -Expected "x" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "bz_Byte" -Actual "bz" -Expected "by" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "sj_SInt" -Actual "sj" -Expected "si" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "usj_USInt" -Actual "usj" -Expected "usi" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "v_Word" -Actual "v" -Expected "w" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "j_Int" -Actual "j" -Expected "i" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "uj_UInt" -Actual "uj" -Expected "ui" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "dv_DWord" -Actual "dv" -Expected "dw" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "dj_DInt" -Actual "dj" -Expected "di" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "udj_UDInt" -Actual "udj" -Expected "udi" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "tom_Time" -Actual "tom" -Expected "tim" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "c_Date" -Actual "c" -Expected "d" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "toy_TimeOfDay" -Actual "toy" -Expected "tod" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "du_DateTime" -Actual "du" -Expected "dt" | Should -Not -BeNullOrEmpty

        $Output | FindEntry -Class "ERROR" -Var "q_String1" -Actual "q" -Expected "s" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "q_String2" -Actual "q" -Expected "s" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "q_String3" -Actual "q" -Expected "s" | Should -Not -BeNullOrEmpty
    }

    It "Context evaluation" {
        PowerShell $Cmd "$InputDir\context.exp" | Tee-Object -Variable Output | Out-Host

        $Output | FindEntry -Class "ERROR" -Var "Var" -Expected "x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Input" -Expected "x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Output" -Expected "x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "InOut" -Expected "x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "External" -Expected "gx", "G_x", "GS_x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Global" -Expected "gx", "G_x", "GS_x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Constant" -Expected "cx" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "Retain" -Expected "x" | Should -Not -BeNullOrEmpty
        $Output | FindEntry -Class "ERROR" -Var "RetainPersistent" -Expected "x" | Should -Not -BeNullOrEmpty
    }
}

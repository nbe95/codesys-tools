BeforeAll {
    function FindEntry {
        [cmdletbinding()]
        param(
            [parameter(Mandatory = $true, ValueFromPipeline = $true)] $Input,
            [string] $Class,
            [string] $Var,
            [string] $Msg,
            [string] $Actual,
            [string] $Expected,
            [string] $Keyword
        )
        foreach ($Line in $Input) {
            if ($Line -Match "(?m)^\[\s*(?<cls>\w+)\s*\] (?<file>.+): (?<var>.+) - (?<msg>.*?)(?: expected: (?<exp>.+?))?(?:, actual: (?<act>.+?))?$") {
                if ((-not $Class        -or $Matches["cls"] -eq $Class) -and `
                    (-not $Var          -or $Matches["var"] -eq $Var) -and `
                    (-not $Actual       -or $Matches["act"] -eq $Actual) -and `
                    (-not $Expected     -or $Matches["exp"] -eq $Expected) -and `
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

Describe "Run and check declaration checker" {

    It "Check basic type declarations" {

        PowerShell $Cmd "$InputDir\basic-types.exp" | Tee-Object -Variable Output | Out-Host

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
}

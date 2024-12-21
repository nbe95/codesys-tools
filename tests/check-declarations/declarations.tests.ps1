BeforeAll {
    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\check-declarations.ps1"
    $InputDir = Resolve-Path -Relative "$PSScriptRoot\input"
}

Describe "Run and check declaration checker" {
    It "Check basic type declarations" {
        PowerShell $Cmd "$InputDir\basic-types.exp" | Tee-Object -Variable Output | Out-Host
        $Result = $Output -Join "`n"

        $Result | Should -Match "(?<!\w)Nothing .*missing.* expected: x"
        $Result | Should -Match "(?<!\w)_Underscore .*missing.* expected: x"

        $Result | Should -Match "(?<!\w)y_Bool .*current: y.* expected: x"

        $Result | Should -Match "(?<!\w)bz_Byte .*current: bz.* expected: by"
        $Result | Should -Match "(?<!\w)sj_SInt .*current: sj.* expected: si"
        $Result | Should -Match "(?<!\w)usj_USInt .*current: usj.* expected: usi"

        $Result | Should -Match "(?<!\w)v_Word .*current: v.* expected: w"
        $Result | Should -Match "(?<!\w)j_Int .*current: j.* expected: i"
        $Result | Should -Match "(?<!\w)uj_UInt .*current: uj.* expected: ui"

        $Result | Should -Match "(?<!\w)dv_DWord .*current: dv.* expected: dw"
        $Result | Should -Match "(?<!\w)dj_DInt .*current: dj.* expected: di"
        $Result | Should -Match "(?<!\w)udj_UDInt .*current: udj.* expected: udi"

        $Result | Should -Match "(?<!\w)u_Time .*current: u.* expected: tim"
        $Result | Should -Match "(?<!\w)c_Date .*current: c.* expected: d"
        $Result | Should -Match "(?<!\w)toy_TimeOfDay .*current: toy.* expected: tod"
        $Result | Should -Match "(?<!\w)du_DateTime .*current: du.* expected: dt"

        $Result | Should -Match "(?<!\w)q_String1 .*current: q.* expected: s"
        $Result | Should -Match "(?<!\w)q_String2 .*current: q.* expected: s"
        # $Result | Should -Match "(?<!\w)q_String3 .*current: q.* expected: s"
    }
}

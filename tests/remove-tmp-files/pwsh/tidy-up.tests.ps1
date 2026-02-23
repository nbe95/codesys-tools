BeforeAll {
    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\..\remove-tmp-files.ps1"
    $InputDir = "$PSScriptRoot\..\input"
    $TmpDir = "$PSScriptRoot\..\tmp"

    Remove-Item -Recurse -Path $TmpDir -ErrorAction SilentlyContinue
    Copy-Item -Path $InputDir -Destination $TmpDir -Recurse
}

Describe "Test removal of temporary files" {
    It "Test on non-project directory" {
        PowerShell $Cmd "$TmpDir\dir_a" | Out-Host

        "$TmpDir\dir_a\foo.txt" | Should -Exist
    }

    It "Test on project directory" {
        PowerShell $Cmd "$TmpDir\dir_b" | Out-Host

        "$TmpDir\dir_b\foo.project" | Should -Exist
        "$TmpDir\dir_b\foo.backup" | Should -Not -Exist
        "$TmpDir\dir_b\foo.lock" | Should -Not -Exist
        "$TmpDir\dir_b\foo.opt" | Should -Not -Exist
        "$TmpDir\dir_b\foo.~u" | Should -Not -Exist
        "$TmpDir\dir_b\DEFAULT.DFR" | Should -Not -Exist

        "$TmpDir\dir_b\bar.txt" | Should -Exist
        "$TmpDir\dir_b\foobar.project.txt" | Should -Exist
    }

    It "Test on nested directory structure" {
        PowerShell $Cmd "$TmpDir\dir_c" | Out-Host

        "$TmpDir\dir_c\dir_d\dir_e\nothing.txt" | Should -Exist

        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.projectarchive" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.backup" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.lock" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.opt" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.~u" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\DEFAULT.DFR" | Should -Exist
    }

    It "Test on nested directory structure with recursion" {
        PowerShell $Cmd "$TmpDir\dir_c" -Recursive | Out-Host

        "$TmpDir\dir_c\dir_d\dir_e\nothing.txt" | Should -Exist

        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.projectarchive" | Should -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.backup" | Should -Not -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.lock" | Should -Not -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.opt" | Should -Not -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\foo.~u" | Should -Not -Exist
        "$TmpDir\dir_c\dir_d\dir_f\dir_g\DEFAULT.DFR" | Should -Not -Exist
    }
}

<#
    .SYNOPSIS
        Automated unit test for MSFT_SqlScript DSC resource.

    .NOTES
        To run this script locally, please make sure to first run the bootstrap
        script. Read more at
        https://github.com/PowerShell/SqlServerDsc/blob/dev/CONTRIBUTING.md#bootstrap-script-assert-testenvironment
#>

# Suppression of this PSSA rule allowed in tests.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

$script:DSCModuleName = 'SqlServerDsc'
$script:DSCResourceName = 'MSFT_SqlScript'

if ($env:APPVEYOR -eq $true -and $env:CONFIGURATION -ne 'Unit')
{
    Write-Verbose -Message ('Unit test for {0} will be skipped unless $env:CONFIGURATION is set to ''Unit''.' -f $script:DSCResourceName) -Verbose
    return
}

#region HEADER

# Unit Test Template Version: 1.2.0
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'SqlServerDscHelper.psm1')


$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit

#endregion HEADER

function Invoke-TestSetup {
    Add-Type -Path (Join-Path -Path (Join-Path -Path (Join-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'Tests') -ChildPath 'Unit') -ChildPath 'Stubs') -ChildPath 'SqlPowerShellSqlExecutionException.cs')
    Import-Module -Name (Join-Path -Path (Join-Path -Path (Join-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'Tests') -ChildPath 'Unit') -ChildPath 'Stubs') -ChildPath 'SQLPSStub.psm1') -Global -Force
}

function Invoke-TestCleanup {
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}


# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope $script:DSCResourceName {
        InModuleScope 'SqlServerDscHelper' {
            $script:DSCModuleName = 'SqlServerDsc'
            $resourceName = 'MSFT_SqlScript'

            $testParameters = @{
                ServerInstance = $env:COMPUTERNAME
                SetFilePath    = "set.sql"
                GetFilePath    = "get.sql"
                TestFilePath   = "test.sql"
            }

            $testParametersTimeout = @{
                ServerInstance = $env:COMPUTERNAME
                SetFilePath    = "set-timeout.sql"
                GetFilePath    = "get-timeout.sql"
                TestFilePath   = "test-timeout.sql"
                QueryTimeout   = 30
            }

            Describe "$resourceName\Get-TargetResource" {

                Context 'Get-TargetResource fails to import SQLPS module' {
                    $throwMessage = "Failed to import SQLPS module."

                    Mock -CommandName Import-SQLPSModule -MockWith {
                        throw $throwMessage
                    }

                    It 'Should throw the correct error from Import-Module' {
                        { Get-TargetResource @testParameters } | Should -Throw $throwMessage
                    }
                }

                Context 'Get-TargetResource returns script results successfully' {
                    Mock -CommandName Import-SQLPSModule
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        return ''
                    }

                    It 'Should return the expected results' {
                        $result = Get-TargetResource @testParameters

                        $result.ServerInstance | Should -Be $testParameters.ServerInstance
                        $result.SetFilePath | Should -Be $testParameters.SetFilePath
                        $result.GetFilePath | Should -Be $testParameters.GetFilePath
                        $result.TestFilePath | Should -Be $testParameters.TestFilePath
                        $result | Should -BeOfType Hashtable
                    }
                }

                Context 'Get-TargetResource returns script results successfully with query timeout' {
                    Mock -CommandName Import-SQLPSModule
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        return ''
                    }

                    It 'Should return the expected results' {
                        $result = Get-TargetResource @testParametersTimeout
                        $result.ServerInstance | Should -Be $testParametersTimeout.ServerInstance
                        $result.SetFilePath | Should -Be $testParametersTimeout.SetFilePath
                        $result.GetFilePath | Should -Be $testParametersTimeout.GetFilePath
                        $result.TestFilePath | Should -Be $testParametersTimeout.TestFilePath
                        $result | Should -BeOfType Hashtable
                    }
                }

                Context 'Get-TargetResource throws an error when running the script in the GetFilePath parameter' {
                    $errorMessage = "Failed to run SQL Script"

                    Mock -CommandName Import-SQLPSModule
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        throw $errorMessage
                    }

                    It 'Should throw the correct error from Invoke-Sqlcmd' {
                        { Get-TargetResource @testParameters } | Should -Throw $errorMessage
                    }
                }
            }

            Describe "$resourceName\Set-TargetResource" {

                Context 'Set-TargetResource fails to import SQLPS module' {
                    $throwMessage = "Failed to import SQLPS module."

                    Mock -CommandName Import-SQLPSModule -MockWith { throw $throwMessage }

                    It 'Should throw the correct error from Import-Module' {
                        { Set-TargetResource @testParameters } | Should -Throw $throwMessage
                    }
                }

                Context 'Set-TargetResource runs script without issue' {
                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        return ''
                    }

                    It 'Should return the expected results' {
                        $result = Set-TargetResource @testParameters
                        $result | Should -Be ''
                    }
                }

                Context 'Set-TargetResource runs script without issue using timeout' {
                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        return ''
                    }

                    It 'Should return the expected results' {
                        $result = Set-TargetResource @testParametersTimeout
                        $result | Should -Be ''
                    }
                }

                Context 'Set-TargetResource throws an error when running the script in the SetFilePath parameter' {
                    $errorMessage = "Failed to run SQL Script"

                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        throw $errorMessage
                    }

                    It 'Should throw the correct error from Invoke-Sqlcmd' {
                        { Set-TargetResource @testParameters } | Should -Throw $errorMessage
                    }
                }
            }

            Describe "$resourceName\Test-TargetResource" {
                Context 'Test-TargetResource fails to import SQLPS module' {
                    $throwMessage = 'Failed to import SQLPS module.'

                    Mock -CommandName Import-SQLPSModule -MockWith {
                        throw $throwMessage
                    }

                    It 'Should throw the correct error from Import-Module' {
                        { Set-TargetResource @testParameters } | Should -Throw $throwMessage
                    }
                }

                Context 'Test-TargetResource runs script without issue' {
                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {}

                    It 'Should return true' {
                        $result = Test-TargetResource @testParameters
                        $result | Should -Be $true
                    }
                }

                Context 'Test-TargetResource runs script without issue with timeout' {
                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {}

                    It 'Should return true' {
                        $result = Test-TargetResource @testParametersTimeout
                        $result | Should -Be $true
                    }
                }

                Context 'Test-TargetResource throws the exception SqlPowerShellSqlExecutionException when running the script in the TestFilePath parameter' {
                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        throw New-Object -TypeName Microsoft.SqlServer.Management.PowerShell.SqlPowerShellSqlExecutionException
                    }

                    It 'Should return false' {
                        $result = Test-TargetResource @testParameters
                        $result | Should -Be $false
                    }
                }

                Context 'Test-TargetResource throws an unexpected error when running the script in the TestFilePath parameter' {
                    $errorMessage = "Failed to run SQL Script"

                    Mock -CommandName Import-SQLPSModule -MockWith {}
                    Mock -CommandName Invoke-Sqlcmd -MockWith {
                        throw $errorMessage
                    }

                    It 'Should throw the correct error from Invoke-Sqlcmd' {
                        { Test-TargetResource @testParameters } | Should -Throw $errorMessage
                    }
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}

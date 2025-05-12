<#
.SYNOPSIS
Helper functions for the PSSecretsAO test suite.
#>

#region Test Execution and Reporting

function Invoke-Test {
    <#
    .SYNOPSIS
    Executes a single test scriptblock and reports the result.
    .PARAMETER Name
    The name of the test being executed.
    .PARAMETER TestScript
    The scriptblock containing the test logic.
    .EXAMPLE
    Invoke-Test -Name "Test Case 1" -TestScript { Assert-True $true }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$TestScript
    )

    try {
        # Execute the test script in the caller's scope to allow variable access if needed
        . $TestScript
        Write-TestResult -Name $Name -Result "PASS"
        return $true
    }
    catch {
        # Capture detailed error information
        $errorMessage = "Error: $($_.Exception.Message)"
        if ($_.ScriptStackTrace) {
            $errorMessage += "`nStackTrace: $($_.ScriptStackTrace)"
        }
        Write-TestResult -Name $Name -Result "FAIL" -ErrorMessage $errorMessage
        return $false
    }
}

function Write-TestResult {
    <#
    .SYNOPSIS
    Writes the result of a test to the console.
    .PARAMETER Name
    The name of the test.
    .PARAMETER Result
    The result string ('PASS' or 'FAIL').
    .PARAMETER ErrorMessage
    An optional error message for failed tests.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('PASS', 'FAIL')]
        [string]$Result,

        [string]$ErrorMessage
    )

    if ($Result -eq "PASS") {
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        if ($ErrorMessage) {
            # Indent error message for readability
            $indentedError = $ErrorMessage -split "`n" | ForEach-Object { "       $_" }
            Write-Host $indentedError -ForegroundColor Red
        }
    }
}

#endregion

#region Assertions

function Assert-Equal {
    <#
    .SYNOPSIS
    Asserts that two values are equal. Throws an error if they are not.
    .PARAMETER Expected
    The expected value.
    .PARAMETER Actual
    The actual value.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Expected,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Actual,

        [string]$Message
    )

    # Handle $null comparison carefully
    $areEqual = $false
    if (($null -eq $Expected) -and ($null -eq $Actual)) {
        $areEqual = $true
    }
    elseif (($null -ne $Expected) -and ($null -ne $Actual)) {
        # Use -eq for general comparison, might need specific handling for complex types
        if ($Expected -is [array] -and $Actual -is [array]) {
             if ((Compare-Object -ReferenceObject $Expected -DifferenceObject $Actual -IncludeEqual).Length -eq $Expected.Length) {
                 $areEqual = $true
             }
        } else {
            # Standard comparison
            if ($Expected -eq $Actual) {
                 $areEqual = $true
            }
        }
    }


    if (-not $areEqual) {
        $errorMsg = "Assertion failed: Expected '$Expected' but got '$Actual'."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}

function Assert-NotEqual {
    <#
    .SYNOPSIS
    Asserts that two values are not equal. Throws an error if they are equal.
    .PARAMETER Expected
    The value that the actual value should not be equal to.
    .PARAMETER Actual
    The actual value.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Expected,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Actual,

        [string]$Message
    )

    # Handle $null comparison carefully
    $areEqual = $false
    if (($null -eq $Expected) -and ($null -eq $Actual)) {
        $areEqual = $true
    }
    elseif (($null -ne $Expected) -and ($null -ne $Actual)) {
        # Use -eq for general comparison
         if ($Expected -eq $Actual) {
              $areEqual = $true
         }
    }


    if ($areEqual) {
        $errorMsg = "Assertion failed: Expected values to be different, but both were '$Actual'."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}


function Assert-True {
    <#
    .SYNOPSIS
    Asserts that a condition is true. Throws an error if it is not.
    .PARAMETER Condition
    The condition to evaluate. Should result in $true or $false.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [string]$Message
    )

    if (-not $Condition) {
        $errorMsg = "Assertion failed: Expected condition to be True, but was False."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}

function Assert-False {
    <#
    .SYNOPSIS
    Asserts that a condition is false. Throws an error if it is not.
    .PARAMETER Condition
    The condition to evaluate. Should result in $true or $false.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [string]$Message
    )

    if ($Condition) {
        $errorMsg = "Assertion failed: Expected condition to be False, but was True."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}

function Assert-Null {
    <#
    .SYNOPSIS
    Asserts that a value is null. Throws an error if it is not.
    .PARAMETER Actual
    The actual value to check.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Actual,

        [string]$Message
    )

    if ($null -ne $Actual) {
        $errorMsg = "Assertion failed: Expected value to be Null, but was '$Actual'."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}

function Assert-NotNull {
    <#
    .SYNOPSIS
    Asserts that a value is not null. Throws an error if it is null.
    .PARAMETER Actual
    The actual value to check.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Actual,

        [string]$Message
    )

    if ($null -eq $Actual) {
        $errorMsg = "Assertion failed: Expected value to not be Null."
        if ($Message) {
            $errorMsg += " $Message"
        }
        throw $errorMsg
    }
}

function Assert-Throws {
    <#
    .SYNOPSIS
    Asserts that a scriptblock throws an error.
    .PARAMETER ScriptBlock
    The scriptblock expected to throw an error.
    .PARAMETER ExpectedExceptionType
    Optional. The expected type of the exception.
    .PARAMETER ExpectedErrorMessageContains
    Optional. A string that the error message is expected to contain.
    .PARAMETER Message
    An optional message to include in the error if the assertion fails.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [type]$ExpectedExceptionType,

        [string]$ExpectedErrorMessageContains,

        [string]$Message
    )

    $errorOccurred = $false
    $caughtException = $null
    try {
        # Execute the scriptblock
        & $ScriptBlock
    }
    catch {
        $errorOccurred = $true
        $caughtException = $_
    }

    if (-not $errorOccurred) {
        $errorMsg = "Assertion failed: Expected an error to be thrown, but no error occurred."
        if ($Message) { $errorMsg += " $Message" }
        throw $errorMsg
    }

    # Optional: Check exception type
    if ($PSBoundParameters.ContainsKey('ExpectedExceptionType')) {
         if ($null -eq $caughtException.Exception -or $caughtException.Exception.GetType() -ne $ExpectedExceptionType) {
            $actualType = if ($null -ne $caughtException.Exception) { $caughtException.Exception.GetType().FullName } else { '$null' }
            $errorMsg = "Assertion failed: Expected exception type '$($ExpectedExceptionType.FullName)', but got '$actualType'."
            if ($Message) { $errorMsg += " $Message" }
            throw $errorMsg
        }
    }

    # Optional: Check error message content
    if ($PSBoundParameters.ContainsKey('ExpectedErrorMessageContains')) {
        $actualMessage = $caughtException.Exception.Message
        if ($null -eq $actualMessage -or $actualMessage -notmatch $ExpectedErrorMessageContains) {
             $errorMsg = "Assertion failed: Expected error message to contain '$ExpectedErrorMessageContains', but got '$actualMessage'."
             if ($Message) { $errorMsg += " $Message" }
             throw $errorMsg
         }
     }
}


#endregion

#region Test Environment Management

function New-TestEnvironment {
    <#
    .SYNOPSIS
    Creates a temporary directory for test artifacts.
    .OUTPUTS
    String. The full path to the created temporary directory.
    #>
    # Generate a unique directory name
    $testDirName = "PSSecretsAOTests_" + (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random)
    $testPath = Join-Path -Path $env:TEMP -ChildPath $testDirName

    if (Test-Path -Path $testPath) {
        # If somehow it exists, remove it to ensure a clean state
        Remove-Item -Path $testPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create the directory
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    Write-Verbose "Created test environment at $testPath"
    return $testPath
}

function Remove-TestEnvironment {
    <#
    .SYNOPSIS
    Removes the temporary test directory and its contents.
    .PARAMETER TestPath
    The path to the test directory created by New-TestEnvironment.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TestPath
    )

    if ($TestPath -like "$($env:TEMP)\PSSecretsAOTests_*") { # Basic safety check
        if (Test-Path -Path $TestPath) {
            Write-Verbose "Removing test environment at $TestPath"
            Remove-Item -Path $TestPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Verbose "Test environment path '$TestPath' not found for removal."
        }
    } else {
         Write-Warning "Path '$TestPath' does not look like a valid test environment path. Skipping removal."
    }
}

#endregion

#endregion 
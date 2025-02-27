﻿#
# Python virtual env manager inspired by VirtualEnvWrapper
#
# Copyright (c) 2017 Regis FLORET
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

$WORKON_HOME=$Env:WORKON_HOME
$VIRTUALENWRAPPER_HOOK_DIR=''
$Version = "0.1.4"

#
# Set the default path and create the directory if don't exist
#
if (!$WORKON_HOME) {
    $WORKON_HOME = "$Env:USERPROFILE\Envs"
}

if ((Test-Path $WORKON_HOME) -eq $false) {
    mkdir $WORKON_HOME
}

#
# Get the absolute path for the environment
#
function Get-FullPyEnvPath($pypath) {
    return ("{0}\{1}" -f $WORKON_HOME, $pypath)
}

#
# Display a formated error message
#
function Write-FormattedError($err) {
    Write-Host
    Write-Host "  ERROR: $err" -ForegroundColor Red
    Write-Host
}

#
# Display a formated success messge
#
function Write-FormattedSuccess($err) {
    Write-Host
    Write-Host "  SUCCESS: $err" -ForegroundColor Green
    Write-Host
}

#
# Retrieve the python version with the path the python exe regarding the version.
# Python < 3.3 is for this function a Python 2 because the module venv comes with python 3.3
#
# Return the major version of python
#
function Get-PythonVersion($Python) {
    if (!(Test-Path $Python)) {
        Write-FormattedError "$Python doesn't exist"
        return
    }

    $python_version = Invoke-Expression "& '$Python' --version 2>&1"
    if (!$Python -and !$python_version) {
        Write-Host "I don't find any Python version into your path" -ForegroundColor Red
        return
    }

    $is_version_2 = ($python_version -match "^Python\s2") -or ($python_version -match "^Python\s3.3")
    $is_version_3 = $python_version -match "^Python\s3" -and !$is_version_2

    if (!$is_version_2 -and !$is_version_3) {
        Write-FormattedError "Unknown Python Version expected Python 2 or Python 3 got $python_version"
        return
    }

    return $(if ($is_version_2) {"2"} else {"3"})
}

#
# Common command to create the Python Virtual Environement.
# $Command contains either the Py2 or Py3 command
#
function Invoke-CreatePyEnv($Command, $Name) {
    $NewEnv = Join-Path $WORKON_HOME $Name
    Write-Host "Creating virtual env... "

    Invoke-Expression "$Command '$NewEnv'"

    $VEnvScriptsPath = Join-Path $NewEnv "Scripts"
    $ActivatePath = Join-Path $VEnvScriptsPath "activate.ps1"
    . $ActivatePath

    Write-FormattedSuccess "$Name virtual environment was created and you are in it."
}

#
# Create Python Environment using the VirtualEnv.exe command
#
function New-Python2Env($Python, $Name)  {
    $Command = (Join-Path (Join-Path (Split-Path $Python -Parent) "Scripts") "virtualenv.exe")

    if ((Test-Path $Command) -eq $false) {
        Write-FormattedError "You must install virtualenv program to create the Python virtual environment '$Name'"
        return
    }

    Invoke-CreatePyEnv $Command $Name
}

#
# Create Python Environment using the venv module
#
function New-Python3Env($Python, $Name) {
    if (!$Python) {
        $PythonExe = Find-Python
    } else {
        $PythonExe = Join-Path (Split-Path $Python -Parent) "python.exe"
    }

    $Command = "& '$PythonExe' -m venv"

    Invoke-CreatePyEnv $Command $Name
}

#
# Find python.exe in the path. If $Python is given, try with the given path
#
function Find-Python ($Python) {
    # The path contains the python executable
    if ($Python.EndsWith('python.exe'))
    {
        if (!(Test-Path $Python))
        {
            return $false
        }

        return $Python
    }

    # No python given, get the default one
    if (!$Python) {
        return Get-Command "python.exe" | Select-Object -ExpandProperty Source
    }

    # The python path doesn't exist
    if (!(Test-Path $Python)) {
        return $false
    }

    # The pas is a directory path not a executable path
    $PythonExe = Join-Path $Python "python.exe"
    if (!(Test-Path $PythonExe)) {
        return $false
    }

    return $PythonExe
}

#
# Create the Python Environment regardless the Python version
#
function New-PythonEnv($Python, $Name, $Packages, $Append) {
    $version = Get-PythonVersion $Python

    BackupPath
    if ($Append) {
        $Env:PYTHONPATH = "$Append;$($Env:PYTHONPATH)"
    }

    if ($Version -eq "2") {
        New-Python2Env -Python $Python -Name $Name
    } elseif ($Version -eq "3") {
        New-Python3Env -Python $Python -Name $Name
    } else {
        Write-FormattedError "This is the debug voice. I expected a Python version, got $Version"
        RestorePath

    }
}

function BackupPath {
    $Env:OLD_PYTHON_PATH = $Env:PYTHONPATH
}

function RestorePath {
    $Env:PYTHONPATH = $Env:OLD_PYTHON_PATH
    $Env:Path = $Env:OLD_SYSTEM_PATH
}

#
# Test if there's currently a python virtual env
#
function Get-IsInPythonVenv($Name) {
    if ($Env:VIRTUAL_ENV) {
        if ($Name) {
            if (([string]$Env:VIRTUAL_ENV).EndsWith($Name)) {
                return $true
            }

            return $false;
        }

        return $true
    }

    return $false
}

# Now, work on a env
function Workon {
    Param(
        [string] $Name
    )

    if (!$Name) {
        Write-FormattedError "No python venv to work on. Did you forget the -Name option?"
        return
    }

    $new_pyenv = Get-FullPyEnvPath $Name
    if ((Test-Path $new_pyenv) -eq $false) {
        Write-FormattedError "The Python environment '$Name' don't exists. You may want to create it with 'MkVirtualEnv $Name'"
        return
    }

    if (Get-IsInPythonVenv -eq $true) {
        deactivate        
    }

    $activate_path = "$new_pyenv\Scripts\Activate.ps1"
    if ((Test-path $activate_path) -eq $false) {
        Write-FormattedError "Enable to find the activation script. You Python environment $Name seems compromised"
        return
    }

    Import-Module $activate_path

    $Env:OLD_PYTHON_PATH = $Env:PYTHON_PATH
    $Env:VIRTUAL_ENV = "$new_pyenv"
}

#
# Create a new virtual environment.
#
function New-VirtualEnv()
{
    Param(
        [Parameter(HelpMessage="The virtual env name")]
        [string]$Name,

        [Parameter(HelpMessage="The requirements file")]
        [alias("r")]
        [string]$Requirement,

        [Parameter(HelpMessage="The Python directory where the python.exe lives")]
        [string]$Python,

        [Parameter(HelpMessage="The package to install. Repeat the parameter for more than one")]
        [alias("i")]
        [string[]]$Packages,

        [Parameter(HelpMessage="Associate an existing project directory to the new environment")]
        [alias("a")]
        [string]$Associate
    )

    if ($Name.StartsWith("-")) {
        Write-FormattedError "The virtual environment name couldn't start with - (minus)"
        return
    }

    if ($Append -and !(Test-Path $Append)) {
        Write-FormattedError "The path '$Append' doesn't exist"
        return
    }

    if (!$Name) {
        Write-FormattedError "You must at least give me a PyEnv name"
        return
    }

    if ((IsPyEnvExists $Name) -eq $true) {
        Write-FormattedError "There is an environment with the same name"
        return
    }

    $PythonRealPath = Find-Python $Python
    if (!$PythonRealPath) {
        Write-FormattedError "The path to access to python doesn't exist. Python directory = $Python"
        return
    }

    New-PythonEnv -Python $PythonRealPath -Name $Name

    foreach($Package in $Packages)  {
         Invoke-Expression "$WORKON_HOME\$Name\Scripts\pip.exe install $Package"
    }


    if ($Requirement -ne "") {
        if (! $(Test-Path $Requirement)) {
            Write-Error "The requirement file doesn't exist"
            Break
        }

        Invoke-Expression "$WORKON_HOME\$Name\Scripts\pip.exe install -r $Requirement"
    }
}


#
# Check if there is an environment named $Name
#
function IsPyEnvExists($Name) {
    $children = Get-ChildItem $WORKON_HOME

    if ($children.Length -gt 0) {
        for ($i=0; $i -lt $children.Length; $i++) {
            if (([string]$children[$i]).CompareTo($Name) -eq 0) {
                return $true
            }
        }
    }

    return $false
}

function Get-VirtualEnvs {
    $children = Get-ChildItem $WORKON_HOME
    Write-Host
    Write-Host "`tPython Virtual Environments available"
    Write-Host
    Write-host ("`t{0,-30}{1,-15}" -f "Name", "Python version")
    Write-host ("`t{0,-30}{1,-15}" -f "====", "==============")
    Write-Host

    if ($children.Length) {
        $failed = [System.Collections.ArrayList]@()

        for($i = 0; $i -lt $children.Length; $i++) {
            $child = $children[$i]
            try {
                $PythonVersion = (((Invoke-Expression ("$WORKON_HOME\{0}\Scripts\Python.exe --version 2>&1" -f $child.name)) -replace "`r|`n","") -Split " ")[1]
                Write-host ("`t{0,-30}{1,-15}" -f $child.name,$PythonVersion)
            } catch {
                $failed += $child
            }
        }
    } else {
        Write-Host "`tNo Python Environments"
    }
    if ($failed.Length -gt 0) {
        Write-Host
        Write-Host "`tAdditionally, one or more environments failed to be listed"
        Write-Host "`t=========================================================="
        Write-Host
        foreach ($item in $failed) {
            Write-Host "`t$item"
        }
    }


    Write-Host
}

#
# Remove a virtual environment.
#
function Remove-VirtualEnv {
    Param(
        [string]$Name
    )

    if ((Get-IsInPythonVenv $Name) -eq $true) {
        Write-FormattedError "You want to destroy the Virtual Env you are in. Please type 'deactivate' before to dispose the environment before"
        return
    }

    if (!$Name) {
        Write-FormattedError "You must fill a environment name"
        return
    }

    $full_path = Get-FullPyEnvPath $Name
    if ((Test-Path $full_path) -eq $true) {
        Remove-Item -Path $full_path -Recurse
        Write-FormattedSuccess "$Name was deleted permanently"
    } else {
        Write-FormattedError "$Name not found"
    }
}

<#
.Synopsis
    Get the current version of VirtualEnvWrapper
#>
function Get-VirtualEnvVersion() {
    Write-Host "Version $Version"
}

<#
.Synopsis
    Create a temporary environment. 
#>
function New-TemporaryVirtualEnv() {
    Param(
        [Parameter(HelpMessage="Change directory into the newly created virtual environment")]
        [alias("c")]
        [switch]
        $Cd = $False,

        [Parameter(HelpMessage="Don't change directory")]
        [alias("n")]
        [switch]$NoCd = $false,

        # Reimplement New-VirtualEnv parameters
        [Parameter(HelpMessage="The requirements file")]
        [alias("r")]
        [string]$Requirement,

        [Parameter(HelpMessage="The Python directory where the python.exe lives")]
        [string]$Python,

        [Parameter(HelpMessage="The package to install. Repeat the parameter for more than one")]
        [alias("i")]
        [string[]]$Packages,

        [Parameter(HelpMessage="Associate an existing project directory to the new environment")]
        [alias("a")]
        [string]$Associate
    )

    Begin
    {
        if ($NoCd -eq $true) {
            $Cd = $false;
        }
    }

    Process
    {
        $uuid = (Invoke-Expression "python -c 'import uuid; print(str(uuid.uuid4()))'")
        $dest_dir = "$WORKON_HOME/$uuid"

        # Recompose command line
        $args = ""
        foreach($param in $PSBoundParameters.GetEnumerator())
        {
            $args += (" -{0} {1}" -f $param.Key,$param.Value)
        }

        Invoke-Expression "New-VirtualEnv $uuid $args"

        $message = "This is a temporary environment. It will be deleted when you run 'deactivate'."
        Write-Host $message
        $message | Out-File -FilePath "$dest_dir/README.tmpenv"

        # Write deactivation file. See Workon rewriting deactivate feature
        $post_deactivate_file_content = @"
if ((est-Path -Path `"$dest_dir/README.tmpenv`") {
    Write-Host `"Removing temporary environment $uuid`"
    # Change the location else MS Windows will refuse to remove the directory
    Set-Location `"$WORKON_HOME`" 
    Remove-VirtualEnv $uuid
}
"@
        $post_deactivate_file_content | Out-File -FilePath "$WORKON_HOME/$uuid/postdeactivate.ps1"

        if ($Cd -Eq $true) {
            Set-Location -Path "$WORKON_HOME/$uuid"
        }
    }
}

#
# Powershell alias for naming convention
#
Set-Alias lsvirtualenv Get-VirtualEnvs
Set-Alias rmvirtualenv Remove-VirtualEnv
Set-Alias mkvirtualenv New-VirtualEnv
Set-Alias mktmpenv New-TemporaryVirtualEnv

Write-Host "Virtual Env Wrapper for Powershell activated"

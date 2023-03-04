### PUBLIC NON-PORTABLE MANIFEST ###
param (
    [string]$cmd,
    [string]$trgversion,
    [string]$path,
    [switch]$force,
    [switch]$quiet
)

### PATH RESOLVER ###

$dgpath = getdgpath

if($path -eq '')
{
    $path = "$dgpath\apps"
}
else
{
    if(!(Test-Path $path))
    {
        Write-Host "Error: " -f r -n
        Write-Host "path isn't accessible."
        exit -1
    }
}

### DATA SETUP ###

$name = "outline"
$portable = $false
$version = "current"
$source = "https://s3.amazonaws.com/outline-releases/client/windows/stable/Outline-Client.exe"
$sourcetype = "permalink"
$executable = "C:\Program Files (x86)\Outline\Outline.exe"
$uninstaller = "C:\Program Files (x86)\Outline\Uninstall Outline.exe"
$dependencies = @()

### INSTALL ###

if($cmd -eq "install")
{

    ### NON-PORTABLE WARNING ###

    if($portable -eq $false -and !($quiet))
    {
        Write-Host "Warning: " -f y -n
        Write-Host "$name " -f gre -n; Write-Host "is not a portable application. It won't be installed in " -n; Write-Host "'denget/apps'" -f gre -n; Write-Host ". Do you want to continue? (y/n): " -n
        $answer = Read-Host

        if($answer -eq "n" -or $answer -eq "N")
        {
            exit -1
        }
    }

    ### SOURCE RESOLVER ###

    try {
        $null = Invoke-WebRequest -Uri $source -Method Head -UseBasicParsing
    }
    catch {
        Write-Host "Error: " -f r -n
        Write-Host "source error - $($_.Exception.Response.StatusCode)"
        exit -1
    }

    ### PRE-INSTALLATION STEPS ###


    ### INSTALLER/FILES DOWNLOAD ###

    $downfile = "$name.exe"
    Write-Quiet "Downloading " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " from " -n; Write-Quiet "$source" -f gre -n; Write-Quiet "..."
    if ($(find aria2)) {& $(getinstalled "aria2" executable) -x 16 -k 1M -q --dir "$dgpath\temp" -o $downfile $source}
    else {& Invoke-WebRequest $source -UseBasicParsing -OutFile "$dgpath\temp\$downfile"}

    ### INSTALLER EXECUTION / FILE COPY ###

    Write-Quiet "Running installer..."
    $installerparams = @{
        FilePath     = "$dgpath\temp\$name.exe"
        Wait         = $true
        WindowStyle = 'Hidden'
    }
    Start-Process @installerparams

    ### POST-INSTALLATION STEPS ###


    ### REMOVING INSTALLER / CLEANING TEMP ###

    Write-Quiet "Cleaning up..."
    Remove-Item "$dgpath\temp\$name.exe"

    ### CHECKING IF EXECUTABLE EXISTS ###

    if(!(Test-Path $executable))
    {
        Write-Host "Error: " -f r -n
        Write-Host "executable not found. Installation failed or aborted by user."
        exit -1
    }

    ### DEPENDENCIES CHECK ###

    if($dependencies.Length -ne 0)
    {
        Write-Quiet "Note: " -f blu -n
        Write-Quiet "this app has the following dependencies:"
        foreach($dependency in $dependencies)
        {
            Write-Quiet "$dependency" -f gre
        }

        $bucketoforigin = $PSScriptRoot.Split("\")[-1]
        Write-Quiet "You can see this list again by running '" -n; Write-Quiet "denget dependencies $name $bucketoforigin" -f m -n; Write-Quiet "'."
    }

    ### RETURNING DATA TO DENGET ###

    $global:appversion = $version
    $global:portable = $portable
    $global:executable = $executable

    exit 0
}

### UNINSTALL ###

if($cmd -eq "uninstall")
{
    ### CHECK IF VERSIONS ARE MISMATCHED FOR PORTABLE ###

    if ($version -ne $trgversion -and $portable -and !($force))
    {
        Write-Host "Warning: " -f y -n
        Write-Host "version installed ($trgversion) doesn't match the version in the manifest ($version)."
        Write-Host "Possibly, the manifest was updated. Uninstalling may result in an error if the uninstalling process has changed."
        Write-Host "Do you want to proceed anyway? (y/n): " -NoNewline
        $answer = Read-Host

        if($answer -eq "n" -or $answer -eq "N")
        {
            exit -1
        }
    }

    ### WARNINGS / PRE-UNINSTALLATION STEPS ###

    if(!($quiet)) {
        Write-Host "Are you sure you want to uninstall " -n; Write-Host "$name" -f gre -n; Write-Host "? (y/n): " -n
        $answer = Read-Host

        if($answer -eq "n" -or $answer -eq "N")
        {
            exit -1
        }
    }

    ### UNINSTALLER EXECUTION / FILE DELETION ###

    Write-Quiet "Deleting app..."

    $uninstallerparams = @{
        FilePath     = $uninstaller
        Wait         = $true
        WindowStyle = 'Hidden'
    }
    Start-Process @uninstallerparams

    ### CHECKING IF EXECUTABLE EXISTS ###

    if(Test-Path $executable)
    {
        Write-Host "Error: " -f r -n
        Write-Host "executable still exists. Uninstallation failed or aborted by user."
        exit -1
    }

    ### POST-UNINSTALLATION STEPS ###


    ### DEPENDENCIES CHECK ###

    if($dependencies.Length -ne 0)
    {
        Write-Quiet "Note: " -f blu -n
        Write-Quiet "this app has the following dependencies you might want to uninstall too:"
        foreach($dependency in $dependencies)
        {
            Write-Quiet "$dependency" -f gre
        }

        $bucketoforigin = $PSScriptRoot.Split("\")[-1]
        Write-Quiet "You can see this list again by running '" -n; Write-Quiet "denget dependencies $name $bucketoforigin" -f m -n; Write-Quiet "'."
    }

    exit 0
}
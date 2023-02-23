### IWR PORTABLE MANIFEST ###
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

$name = "xoutput"
$portable = $true
$version = "current"
$source = "https://github.com/csutorasa/XOutput/releases/latest/download/XOutput.zip"
$sourcetype = "permalink"
$executable = "$path\$name\$version\XOutput.exe"
$uninstaller = ""
$dependencies = @("ViGEmBus", "dotNET7")

### INSTALL ###

if($cmd -eq "install")
{

    ### NON-PORTABLE WARNING ###

    if($portable -eq $false -and !($quiet))
    {
        Write-Host "Warning: " -f y -n
        Write-Host "$name " -f gre -n; Write-Host "is not a portable application. It won't be installed in " -n; Write-Host "$path" -f gre -n; Write-Host ". Do you want to continue? (y/n): " -n
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

    $downfile = "$name.zip"
    Write-Quiet "Downloading " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " from " -n; Write-Quiet "$source" -f gre -n; Write-Quiet "..."
    $oldProgressPreference = $ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    if ($(find aria2)) {& $(getinstalled "aria2" executable) -x 16 -k 1M -q --dir "$dgpath\temp" -o $downfile $source}
    else {& Invoke-WebRequest $source -UseBasicParsing -OutFile "$dgpath\temp\$downfile"}
    $global:ProgressPreference = $oldProgressPreference

    ### INSTALLER EXECUTION / FILE COPY ###

    Write-Quiet "Extracting..."
    $oldProgressPreference = $ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    & Expand-Archive -Path $dgpath\temp\$name.zip -DestinationPath $path\$name -Force
    $global:ProgressPreference = $oldProgressPreference

    $countFiles = Get-ChildItem $path\$name -File | Measure-Object | Select-Object -ExpandProperty Count
    $countFolders = Get-ChildItem $path\$name -Directory | Measure-Object | Select-Object -ExpandProperty Count
    if($countFiles -eq 0 -and $countFolders -eq 1)
    {
        $childFolder = Get-ChildItem $path\$name | Select-Object -First 1
        $childFolder = $childFolder.Name
        Start-Sleep -s 3
        Move-Item -Path "$path\$name\$childFolder" -Destination "$path\$name\$version" -Force
    }
    else
    {
        [void](New-Item -ItemType Directory -Path "$path\$name\$version")
        Get-ChildItem $path\$name | Where-Object {$_.Name -ne "$version"} | Move-Item -Destination "$path\$name\$version" -Force
    }

    ### CREATE DESKTOP SHORTCUT ###

    if (!$quiet) {
    Write-Host "Do you want to create a desktop shortcut? (y/n): " -NoNewline
    $answer = Read-Host

    if($answer -eq "y" -or $answer -eq "Y")
    {
        Write-Host "Creating desktop shortcut..."
        $shortcut = (New-Object -ComObject Wscript.Shell).CreateShortcut("$env:USERPROFILE\Desktop\$name.lnk")
        $shortcut.TargetPath = $executable
        #$shortcut.Arguments = ''
        #$shortcut.IconLocation = ''
        $shortcut.Save()
    }
    }

    ### CREATE START MENU SHORTCUT ###

    if (!$quiet) {
    Write-Host "Do you want to create a start menu shortcut? (y/n): " -NoNewline
    $answer = Read-Host

    if($answer -eq "y" -or $answer -eq "Y")
    {
        if(!(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget")) # Create denget folder if it doesn't exist
        {
            [void](New-Item -ItemType Directory -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget")
        }

        Write-Host "Creating start menu shortcut..."
        $shortcut = (New-Object -ComObject Wscript.Shell).CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget\$name.lnk")
        $shortcut.TargetPath = $executable
        #$shortcut.Arguments = ''
        #$shortcut.IconLocation = ''
        $shortcut.Save()
    }
    }

    ### POST-INSTALLATION STEPS ###


    ### REMOVING INSTALLER / CLEANING TEMP ###

    Write-Quiet "Cleaning up..."
    Remove-Item "$dgpath\temp\$name.zip"

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

    Get-ChildItem "$path\$name" -Recurse | Remove-Item -Force -Recurse
    Remove-Item "$path\$name" -Recurse -Force

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

    ### REMOVE DESKTOP SHORTCUT ###

    if(Test-Path "$env:USERPROFILE\Desktop\$name.lnk")
    {
        Write-Quiet "Removing desktop shortcut..."
        Remove-Item "$env:USERPROFILE\Desktop\$name.lnk"
    }

    ### REMOVE START MENU SHORTCUT ###

    if(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget\$name.lnk")
    {
        Write-Quiet "Removing start menu shortcut..."
        Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget\$name.lnk"
    }

    exit 0
}
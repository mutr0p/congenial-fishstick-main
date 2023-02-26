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

$name = "rclone"
$portable = $true
$version = "current"
$source = "https://downloads.rclone.org/rclone-current-windows-amd64.zip"
$sourcetype = "permalink"
$executable = "$path\$name\$version\rclone.exe"
$uninstaller = ""
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

    $downfile = "$name.zip"
    Write-Quiet "Downloading " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " from " -n; Write-Quiet "$source" -f gre -n; Write-Quiet "..."
    if ($(find aria2)) {& $(getinstalled "aria2" executable) -x 16 -k 1M -q --dir "$dgpath\temp" -o $downfile $source}
    else {& Invoke-WebRequest $source -UseBasicParsing -OutFile "$dgpath\temp\$downfile"}

    ### INSTALLER EXECUTION / FILE COPY ###

    Write-Quiet "Extracting..."
    & Expand-Archive -Path $dgpath\temp\$name.zip -DestinationPath $path\$name -Force

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

    Write-Quiet "Running post-installation steps..."
    $rclonep = Split-Path -Path $executable -Parent
    New-Item "$rclonep\rclone.conf" | Out-Null
    if ($quiet) { & $executable config file --config="$rclonep\rclone.conf" | Out-Null }
    else { & $executable config file --config="$rclonep\rclone.conf" }

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

    Write-Quiet "Warning: " -f y -n
    Write-Quiet "rclone is used by denget for cloud storage functionality. Uninstalling it will turn the cloud storage functionality off (except if you have rclone installed globally)."
    Write-Quiet "Also, uninstalling rclone will delete a local cofiguration file with your cloud remotes if you configured any, and you'll have to configure them again."
    Write-Quiet "If you decide to proceed, you will have an option to backup your configuration file to Desktop in the next prompt."

    if(!($quiet)) {
        Write-Host "Are you sure you want to uninstall " -n; Write-Host "$name" -f gre -n; Write-Host "? (y/n): " -n
        $answer = Read-Host

        if($answer -eq "n" -or $answer -eq "N")
        {
            exit -1
        }
    }

    if(!($force)) {
        Write-Host "Do you want to backup your configuration file? (y/n): " -NoNewline
        $answer = Read-Host

        if($answer -eq "y" -or $answer -eq "Y")
        {
            Write-Host "Backing up configuration file to your Desktop..."
            $rclonep = Split-Path -Path $executable -Parent
            Copy-Item "$rclonep\rclone.conf" "$env:USERPROFILE\Desktop\" -Force
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
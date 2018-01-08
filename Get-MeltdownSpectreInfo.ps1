<#
For a collection or report, for example, if you want to run this command on remote computers using invoke-command you can try something like this

$csvReport = "\\[serverpath]\[share]\JanPatchStatus.csv"
$checkExist = get-item $csvReport

if($csvReport){
}
else{
$csvHeader = "computername,regkey,biosdate,status"
$csvHeader | out-file $csvReport
}

Then for each check create a variable and then at the end of the script do something like
$reportString = $computername + "," + $regkey + "," + $biosdate + "," + $status
$reportString | out-file $csvReport -append

Will get back to this...

Further To Do: Maybe check for updates against a list of all known 2018-01 Security patches to display a pass/fail on that front.
This at least for the moment should provide all necessary background outside of Windows Update to check a machine's readiness for meltdown/spectre
#>

# Check if the AV set key to allow Windows to find the January update exists
$allowKey = (get-item HKLM:\software\Microsoft\Windows\CurrentVersion\QualityCompat\ -ErrorAction SilentlyContinue).property

if($allowKey){ 
    write-host "Your AV has set the proper registry key and your machine is eligible for the Jan 3rd Windows patches." -ForegroundColor Green
    # for the possible CSV report
    $regkey = "True"}
else{
    write-host "Your AV is not up to date, incompatible, or you don't have an AV."
    write-host "Your comptuer is currently not able to see and install the Jan 3rd Windows patches."
    write-host "Update your AV and check for HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\QualityCompat\cadca5fe-87d3-4b96-b7fb-a231484277cc"
    write-host ""
    write-host "**CAUTION** Do this following at your own risk. Manually setting the key with an incompatible AV will cause BSOD" -ForegroundColor Red
    write-host "If you need to set the key yourself because you do not have AV installed, open a new elevated command prompt and paste this command:" -ForegroundColor Red
    write-host 'reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\QualityCompat" /v cadca5fe-87d3-4b96-b7fb-a231484277cc /t REG_DWORD /d 0 /f' -ForegroundColor Red
    write-host ""
    }

# for computers with the prerequisites we will install and run the latest Speculationcontrol module from Microsoft
$installModuleExists = get-command "install-module" -ErrorAction SilentlyContinue

if($installModuleExists){
    # -Force ensures we get the latest version, even if this script or module has been run before
    Install-Module SpeculationControl -Force
    $speculationControlExists = get-command "get-speculationcontrolsettings" -ErrorAction SilentlyContinue}
else{
    # if Install-Module isn't available we'll pull the script down from a user on Github
    New-Item -Path c:\temp -ItemType Directory -ErrorAction SilentlyContinue
    # Microsoft's Powershell Gallery doesn't provide raw file for download
    # Will pull a copy off of a Github repository...may need to verify the file's existence or upload a separate copy
    # I may want to pull the function out and run it here for more variable control, as setting script output into a variable doesn't work well
    $url = "https://raw.githubusercontent.com/justin-p/PowerShell/master/Meltdown-Scans/portable_client_check/Get-SpeculationControlSettings.ps1"
    $output = "c:\temp\Get-SpeculationControlSettings.ps1"
    Invoke-WebRequest -Uri $url -OutFile $output
    }

# if we were able to install SpeculationControl We'll run it
# if not we'll run the script we downloaded instead
if($speculationControlExists){
    Get-SpeculationControlSettings}
else{
    & "C:\temp\Get-SpeculationControlSettings.ps1"}


# mitigation requires hardware patching
# a lazy check will compare the bios date to 2017. If the BIOS was 2017 or earlier it likely wasn't patched.
# a 2018 BIOS date is *likely* to be patched.
$biosInfo = gwmi win32_bios | select *
$biosdate = ($biosinfo.ReleaseDate).substring(0,8)
$releaseYear = ($biosInfo.ReleaseDate).substring(0,4)
if([int]$releaseYear -le 2017){
    write-host "Your BIOS was last updated in $releaseYear. You will need a BIOS update from your PC manufacturer to fully patch." -ForegroundColor Red}
else{
    write-host "Your BIOS was last updated in $releaseyear. You're probably hardware patched. Check SpeculationControl output and check your manufacturer to be certain." -ForegroundColor Green}


# Windows Server needs some extra registry keys to start working if the updates were applied.
$OSVersion = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

# Check for the three server keys and output the commands to enable them if necessary.
if($OSVersion -like "*Server*"){
    $serverkey1 = (get-itemproperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\" -Name FeatureSettingsOverride -ErrorAction SilentlyContinue).FeatureSettingsOverride #0
    $serverkey2 = (get-itemproperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\" -Name FeatureSettingsOverrideMask -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask #3
    $serverkey3 = (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\" -Name MinVmVersionForCpuBasedMitigations -ErrorAction SilentlyContinue).MinVmVersionForCpuBasedMitigations #1.0
    
    if($serverkey1 -eq "0"){
        Write-Host "The first server registry key to enable migitations is set." -ForegroundColor Green}
    }
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 0 /f' -ForegroundColor Red
        Write-Host ""}

    if($serverkey2 -eq "3"){
        Write-Host "The second server registry key to enable mitigations is set" -ForegroundColor Green}
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f' -ForegroundColor Red
        Write-Host ""}

       if($serverkey3 -eq "1.0"){
        Write-Host "The third server registry key to enable mitigations is set" -ForegroundColor Green}
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" /v MinVmVersionForCpuBasedMitigations /t REG_SZ /d "1.0" /f' -ForegroundColor Red
        Write-Host ""}
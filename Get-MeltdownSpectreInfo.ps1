<#  Get-MeltdownSpectreInfo.ps1 
    Quick and messy check that runs through some of the important parts of Spectre/Meltdown checks
    Made to be talkative and informative
    
    Crappy logging capability at the bottom for use with remote shares and invoke-command remoting
#>

# Check if the AV set key to allow Windows to find the January update exists
$allowKey = (get-item HKLM:\software\Microsoft\Windows\CurrentVersion\QualityCompat\ -ErrorAction SilentlyContinue).property

if($allowKey){ 
    write-host "Your AV has set the proper registry key and your machine is eligible for the Jan 3rd Windows patches." -ForegroundColor Green
    # for the possible CSV report
    #$regkey = "True"
    }
else{
    write-host "Your AV is not up to date, incompatible, or you don't have an AV."
    write-host "Your comptuer is currently not able to see and install the Jan 3rd Windows patches."
    write-host "Update your AV and check for HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\QualityCompat\cadca5fe-87d3-4b96-b7fb-a231484277cc"
    write-host ""
    write-host "**CAUTION** Do this following at your own risk. Manually setting the key with an incompatible AV will cause BSOD" -ForegroundColor Red
    write-host "If you need to set the key yourself because you do not have AV installed, open a new elevated command prompt and paste this command:" -ForegroundColor Red
    write-host 'reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\QualityCompat" /v cadca5fe-87d3-4b96-b7fb-a231484277cc /t REG_DWORD /d 0 /f' -ForegroundColor Red
    write-host ""
    #for the possible csv report
    #$regkey = "False"
    }


# windows updates
# this is the list of updates released between the 3rd and 4th
# will need to be updated past that if more are released on patch tuesday or later particulary for server 2008 and 2012 non r2 editions

$updated = get-hotfix -id kb4056899,kb4056894,kb4056892,kb4056890,kb4056891,kb4056897,kb4056888,kb4056893 -ErrorAction SilentlyContinue
if($updated){
    $hotfix = $updated.hotfixid
    $patchdate = $updated.installedon
    write-host "You have $hotfix applied since $patchdate. If you've rebooted your patches are set." -ForegroundColor Green
    write-host ""}
else{
    write-host "You still haven't gotten the appropriate patch from Windows Update. Check for updates and set the registry key as above if you haven't done so yet." -ForegroundColor Red
    write-host ""
    #for the possible csv report
    #$hotfix = "unpatched"
    }


# for computers with the prerequisites we will install and run the latest Speculationcontrol module from Microsoft
$installModuleExists = get-command "install-module" -ErrorAction SilentlyContinue

if($installModuleExists){
    # -Force ensures we get the latest version, even if this script or module has been run before
    Install-Module SpeculationControl -Force
    $speculationControlExists = get-command "get-speculationcontrolsettings" -ErrorAction SilentlyContinue}
else{
    # if Install-Module isn't available we'll pull the script down from the technet gallery
    # it's provided as a zip so we must download and extract it
    New-Item -Path c:\temp -ItemType Directory -ErrorAction SilentlyContinue
    New-Item -Path C:\temp\speculationcontrol -ItemType Directory -ErrorAction SilentlyContinue
    $url = "https://gallery.technet.microsoft.com/scriptcenter/Speculation-Control-e36f0050/file/185106/1/SpeculationControl.zip"
    $output = "c:\temp\Get-SpeculationControlSettings.zip"
    Invoke-WebRequest -Uri $url -OutFile $output
    # courtesy of https://blogs.technet.microsoft.com/heyscriptingguy/2015/03/11/use-powershell-to-extract-zipped-files/
    Add-Type -assembly "system.io.compression.filesystem"
    $destination = "c:\temp\speculationcontrol"
    [io.compression.zipfile]::ExtractToDirectory($output, $destination)
    Import-Module "C:\temp\speculationcontrol\speculationcontrol\speculationcontrol.psm1" -Force 
    }

## previous version of the script downloaded a ps1 that defined Get-SpeculationControlSettings and ran it
## the new version which imports the file as a module should allow us to skip the loop and call the cmdlet directly

# if we were able to install SpeculationControl We'll run it
# if not we'll run the script we downloaded instead
#if($speculationControlExists){
    Get-SpeculationControlSettings
#else{
#    & "C:\temp\Get-SpeculationControlSettings.ps1"}


# mitigation requires hardware patching
# a lazy check will compare the bios date to 2017. If the BIOS was 2017 or earlier it likely wasn't patched.
# a 2018 BIOS date is *likely* to be patched. advise user to check diligently
# if I wanted to go all out I could pull manufacturer from win32_bios and refer user to link to manufacturer page on issue
# not all manufacturers have this available yet so I won't bother with it now
$biosInfo = gwmi win32_bios | select *
$biosdate = ($biosinfo.ReleaseDate).substring(0,8)
$releaseYear = ($biosInfo.ReleaseDate).substring(0,4)
if([int]$releaseYear -le 2017){
    write-host "Your BIOS was last updated in $releaseYear. You may need a BIOS update from your PC manufacturer to fully patch." -ForegroundColor Red
    write-host "Some manufacturers may have been quick and released in 2017 -- so check the speculation control settings for verification."
    write-host ""}
else{
    write-host "Your BIOS was last updated in $releaseyear. You're probably hardware patched. Check SpeculationControl output and check your manufacturer to be certain." -ForegroundColor Green
    write-host ""}


# Windows Server needs some extra registry keys to start working if the updates were applied.
$OSVersion = (get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

# Check for the three server keys and output the commands to enable them if necessary.
if($OSVersion -like "*Server*"){
    $serverkey1 = (get-itemproperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\" -Name FeatureSettingsOverride -ErrorAction SilentlyContinue).FeatureSettingsOverride #0
    $serverkey2 = (get-itemproperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\" -Name FeatureSettingsOverrideMask -ErrorAction SilentlyContinue).FeatureSettingsOverrideMask #3
    $serverkey3 = (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\" -Name MinVmVersionForCpuBasedMitigations -ErrorAction SilentlyContinue).MinVmVersionForCpuBasedMitigations #1.0
    
    if($serverkey1 -eq "0"){
        Write-Host "The first server registry key to enable migitations is set." -ForegroundColor Green
        #possible csv out
        #$serverkey1set = "True"
        }
    
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 0 /f' -ForegroundColor Red
        Write-Host ""
        #possible csv out
        #$serverkey1set = "False"
        }

    if($serverkey2 -eq "3"){
        Write-Host "The second server registry key to enable mitigations is set" -ForegroundColor Green
        #possible csv out
        #$serverkey2set = "True"
        }
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f' -ForegroundColor Red
        Write-Host ""
        #possible csv out
        #$serverkey2set = "False"
        }

       if($serverkey3 -eq "1.0"){
        Write-Host "The third server registry key to enable mitigations is set" -ForegroundColor Green
        #possible csv out
        #$serverkey3set = "True"
        }
    else{
        Write-Host "In order to enable mitigations, you must set the following key after updates." -ForegroundColor Red
        Write-Host "Run this in an elevated command prompt" -ForegroundColor Red
        Write-Host 'reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" /v MinVmVersionForCpuBasedMitigations /t REG_SZ /d "1.0" /f' -ForegroundColor Red
        Write-Host ""
        #possible csv out
        #$serverkey3set = "False"
        }

}
else{
# for our lame CSV
# $serverkey1set = "NA"
# $serverkey2set = "NA"
# $serverkey3set = "NA"
}
<#
For a collection or report, for example, if you want to run this command on remote computers using invoke-command you can try something like this

$csvReport = "\\[serverpath]\[share]\JanPatchStatus.csv"
$checkExist = get-item $csvReport

# if the item is there we'll go about our business
# if not we need to create the right csv headers
if($checkExist){
    write-host "Appending output to file..."
}
else{
    $csvHeader = "computername,regkey,hotfix,biosdate,serverkey1set,serverkey2set,serverkey3set"
    $csvHeader | out-file $csvReport
}

Then for each check create a variable and then at the end of the script do something like
$reportString = $env:COMPUTERNAME + "," + $regkey + "," + $hotfix + "," + $biosdate + "," + $serverkey1set + "," + $serverkey2set + "," + $serverkey3set
$reportString | out-file $csvReport -append

#>

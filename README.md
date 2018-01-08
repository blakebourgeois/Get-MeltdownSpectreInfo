# Get-MeltdownSpectreInfo

Usage: Download and run as an administrator
.\Get-MeltdownSpectreInfo.ps1

This script will report whether or not the AV set registry key is present and will advise no-AV users how to set it.

To mitigate risk, the script will NOT automatically add any reg keys but it's certainly possible to modify it to do so.

The script will download the Get-SpeculationControlSettings cmdlet either from Microsoft's PowershellGallery if available or will download the code from Github.

The script will check the BIOS date and see if the BIOS version is 2018 or higher. If the BIOS is older than 2018 we can assume it's likely unpatched against these exploits.

Finally, for Windows Server OS's, the script will check if the registry keys to actually enable the patches are present. If not, the necessary code is shown to the user.

# To Do

My next steps will be to actually pull data on the Windows updates present on the machine, but it'll take a bit to work out which patches to include to make this fully encompassing for all Win 7, 8, 10, Server 2008, 2012, and 2016 systems.

As it stands it's an adequate dashboard of how a machine stands.

The top of the script has a skeleton outline of how to get the script to build out a CSV on a remote share if you want to push this script to run on remote systems. 
It'll require a bit more work and will also need to be moved to the BOTTOM of the script when ready so the variables are populated correctly. More on that later.
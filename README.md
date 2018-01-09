# Get-MeltdownSpectreInfo

Usage: Download and run as an administrator
.\Get-MeltdownSpectreInfo.ps1

This script will report whether or not the AV set registry key is present and will advise no-AV users how to set it.

To mitigate risk, the script will NOT automatically add any reg keys but it's certainly possible to modify it to do so.

This script will check for the presence of any of the available hotfixes that are made to fix this issue. It will need to be updated for 1/9/2018 patch Tuesday, possibly need to keep up with future roll ups too (gross, this probably won't be maintained).

The script will download the Get-SpeculationControlSettings cmdlet either from Microsoft's PowershellGallery if available or will download a zip from technet and extract and install the module. You MUST run as admin.

The script will check the BIOS date and see if the BIOS version is 2018 or higher. If the BIOS is older than 2018 we can assume it's likely unpatched against these exploits.

Finally, for Windows Server OS's, the script will check if the registry keys to actually enable the patches are present. If not, the necessary code is shown to the user.

# To Do

Update hotfix list with future patches.

Test out and flesh out the CSV thing at the bottom. Something something galaxy brain meme "make your own csv using out-file -append" is one of my worst powershell habits.

When manufacturers all have pages out detailing their affected systems and bios quick links may use win32_bios.manufacturer to display a link to a page to get bios updates...that's pushing it though.
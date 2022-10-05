# Description of Cloud PC Azure AD Cleanup
Currently Windows 365 does not support resize in MEM portal if users have been assigned a license through group-based licensed.


# Required PowerShell Modules

This script uses 'Microsoft.Graph' modules. The script only installs the Microsoft.Graph modules it needs to run this script, not the entire Microsoft.Graph module. These modules are:

- Microsoft.Graph.authentication 
- Microsoft.Graph.Identity.DirectoryManagement
- Microsoft.Graph.DeviceManagement.Administration


# Microsoft Graph Permissions

The account you are running the script with needs to have the following Microsoft Graph API Permissions:

- CloudPC.Read.All
- Directory.ReadWrite.All


# Usage
There are three parameters to take care of before running the script.

$ExportToCSV: Specifying a path will export .csv report. Leave the variable blank for no report
$GracePeriod: Specifying '0' will delete all old devices. adding a higher number like '100' will only deleted old devices older than 100 days.
$DeleteOldCloudPCDevices: Setting to 'true' will delete devices, 'false' will not deleted devices.

There will be displayed output in the console while the script is running. It can however be difficult the keep track of.
I recommend use the '$ExportToCSV' variable, to get an better overview of what the script have done. 
# Update Notes

## 14 July 2022
This script has been updated with the following improvement and fixed: 

- Fixed an issue where "Quit" dident work properly and was in a endless loop.
- Instead of connecting with AzureADPreview module the script now only uses Microsoft Graph API calls in the script.
  View the required permissions at "Microsoft Graph Permissions" section below.
  By doing this change it's now possible to modify the script to connect with a Service Principal instead of a user account.
- Fixed wrong output when running the script.

# Windows 365 Resize group-based licensed
Currently Windows 365 does not support resize in MEM portal if users have been assigned a license through group-based licensed.
This script is a workaround to resize those users.
This script has many interactions in the PowerShell console, so it's currently not supported in an automated task.

# Required PowerShell Modules and Microsoft Graph Permissions

This script uses Microsoft.Graph. The script only installs the Microsoft.Graph modules it needs to run this script, not the entire Microsoft.Graph module. These modules are:

- Microsoft.Graph.authentication 
- Microsoft.Graph.Identity.DirectoryManagement
- Microsoft.Graph.Users
- Microsoft.Graph.Users.Actions
- Microsoft.Graph.DeviceManagement.Actions
- Microsoft.Graph.DeviceManagement.Administration
- Microsoft.Graph.Groups
- Microsoft.Graph.DeviceManagement.Functions 


# Microsoft Graph Permissions

The account you are running the script with needs to have the following Microsoft Graph API Permissions:

- CloudPC.ReadWrite.All
- Directory.Read.All
- GroupMember.ReadWrite.All
- User.ReadWrite.All
- Organization.Read.All 

# Usage

When the script is run, it will check if the Microsoft.Graph modules are installed and will install them if not present.

Once the user has authenticated, the script will set the connection to Microsoft.Graph to Beta.

You will have to fill out the variables at the top, remember to set the correct groups in the variables.
If you dont have license group for every license type just leave them blank.

    param(
             #Welcome Email Attribute Check
            [parameter(HelpMessage = "Specify an extension Attribute between 1 - 15 you want the script to use. e.g. extensionAttribute3")]
            [string]$ExstensionAttributeKey = "",

            [parameter(HelpMessage = "Value of exstension Attribute e.g. CPCWelcomeMailHaveBeenSent")]
            [string]$ExstensionAttributeValue = "",

            #Mail Contenct path
            [parameter(HelpMessage = "Mail content path e.g. C:\temp\message.html")]
            [string]$MailContentPath = "",
            
            #Email Attachment
            [parameter(HelpMessage = "Leave this blank if no email attachment is required, else specify the location to an attachment. e.g. C:\temp\attachment.pdf")]
            [string]$EmailAttachment = "",
            
            #Send Email Variable
            [parameter(HelpMessage = "Email Subject of the email")]
            [string]$EmailSubject = ""
            
                      

     )

#Function to check if MS.Graph module is installed and up-to-date
function invoke-graphmodule {
    $graphavailable = (find-module -name microsoft.graph)
    $vertemp = $graphavailable.version.ToString()
    Write-Output "Latest version of Microsoft.Graph module is $vertemp" | out-host

    foreach ($module in $modules){
        write-host "Checking module - " $module
        $graphcurrent = (get-installedmodule -name $module -ErrorAction SilentlyContinue)

        if ($graphcurrent -eq $null) {
            write-output "Module is not installed. Installing..." | out-host
            try {
                Install-Module -name $module -Force -ErrorAction Stop 
                Import-Module -name $module -force -ErrorAction Stop 

                }
            catch {
                write-output "Failed to install " $module | out-host
                write-output $_.Exception.Message | out-host
                Return 1
                }
        }
    }


    $graphcurrent = (get-installedmodule -name Microsoft.Graph.DeviceManagement.Functions)
    $vertemp = $graphcurrent.Version.ToString() 
    write-output "Current installed version of Microsoft.Graph module is $vertemp" | out-host

    if ($graphavailable.Version -gt $graphcurrent.Version) { write-host "There is an update to this module available." }
    else
    { write-output "The installed Microsoft.Graph module is up to date." | out-host }
}

function connect-msgraph {

    $tenant = get-mgcontext
    if ($tenant.TenantId -eq $null) {
        write-output "Not connected to MS Graph. Connecting..." | out-host
        try {
            Connect-MgGraph -Scopes $GraphAPIPermissions -ErrorAction Stop | Out-Null
        }
        catch {
            write-output "Failed to connect to MS Graph" | out-host
            write-output $_.Exception.Message | out-host
            Return 1
        }   
    }
    $tenant = get-mgcontext
    $text = "Tenant ID is " + $tenant.TenantId
    Write-Output "Connected to Microsoft Graph" | out-host
    Write-Output $text | out-host
}



#Function to set the profile to beta
function set-profile {
    Write-Output "Setting profile as beta..." | Out-Host
    Select-MgProfile -Name beta
}


$modules = @("Microsoft.Graph.Authentication",
             "Microsoft.Graph.Users.Actions",
             "Microsoft.Graph.DeviceManagement.Administration",
             "Microsoft.Graph.Users",
             "Microsoft.Graph.Identity.DirectoryManagement",
             "Microsoft.Graph.DeviceManagement.Functions"
            )

$WarningPreference = 'SilentlyContinue'

[String]$GraphAPIPermissions = @("CloudPC.Read.All",
                                  "User.Read.all",
                                  "Directory.ReadWrite.All",
                                  "Mail.Send",
                                  "Device.Read.All",
                                  "Directory.AccessAsUser.All"
                                 )

#Commands to load MS.Graph modules
if (invoke-graphmodule -eq 1) {
    write-output "Invoking Graph failed. Exiting..." | out-host
    Return 1
}

#Command to connect to MS.Graph PowerShell app
if (connect-msgraph -eq 1) {
    write-output "Connecting to Graph failed. Exiting..." | out-host
    Return 1
}

set-profile
 
 #Get all provisioned Cloud PC Devices
 
 $AllCPCDevices = Get-MgDevice -Filter "startsWith(Displayname,'CPC-')"
Foreach ($CPCDeviceInfo in $AllCPCDevices){
    #Check if Cloud PC is actived
    if ($CPCDeviceInfo.AccountEnabled -eq $true){

        #Check For if Welcome mail has been sent before
        $Attributecheck = $CPCDeviceInfo.ExtensionAttributes.$ExstensionAttributeKey
        if (!($Attributecheck -eq $ExstensionAttributeValue)){
            


            #Check if Cloud PC is done priovision
            try {
                $ProvisionStatus = Get-MgDeviceManagementVirtualEndpointCloudPC | where-object {$_.ManagedDeviceName -eq $CPCDeviceInfo.DisplayName}
            if ($ProvisionStatus.Status -eq "provisioned") {
                write-host ""
                write-host "Cloud PC: '$($CPCDeviceInfo.DisplayName)' has been provisioned correct and is ready to be logged into."
         
                   try{  
                    #Set Attribute on Azure AD Device
                    Write-Host "Setting Attribute on AzureAD Device:'$($CPCDeviceInfo.DisplayName)'"
                    Write-Host ""
                    $params = @{
                    "extensionAttributes" = @{
                    #Attribute check for if this is a new CloudPC
                    "$ExstensionAttributeKey" = "$ExstensionAttributeValue"
                       }
                     }

                     Update-MgDevice -DeviceId $CPCDeviceInfo.Id -BodyParameter ($params | ConvertTo-Json)
                                            
                      }
                       catch{ 
                             write-output "Unable to set Attribute on AzureAD Device:'$CPCDeviceInfo.DisplayName'" | out-host
                             write-output $_.Exception.Message | out-host
                             break
                            }

            }
                
                }
            
            catch {
                write-output "Unable to get Cloud PC Device status in Endpoint Manager" | out-host
                write-output $_.Exception.Message | out-host
                break
                }


        
        }
 
}

} 

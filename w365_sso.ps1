[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]    
    [array]$modulename = @("Microsoft.Graph.Authentication" 
                           "Microsoft.Graph.Applications"
                           "Microsoft.Graph.Groups"),
    [Parameter(Mandatory=$false)]    
    [String]$EntraIDGroup = "DYN-All_Cloud_PCs",
    [Parameter(Mandatory=$false)]    
    [String]$DynamicDeviceRule = 'device.displayName -startsWith "CPC-"'
 )


#Search for required modules and install them if they are not present on the system.
try {
        if ($modulename) {
        foreach ($module in $modulename){
            $checkmodule = Get-Module -ListAvailable | Where-Object { $_.Name -eq $module } -Verbose
            if($checkmodule) {
            Write-Host "$module is already installed" -ForegroundColor Cyan
            Import-Module $checkmodule.Name -Force
            } Else{
            Write-Host "$module is not installed, installing $module module" -ForegroundColor Green
            Install-Module $module -AllowClobber -Verbose -Force
            Import-Module $module -Force
            }

        }
            
          }else {
            Write-Host "No module requirements is specificed in variables" -ForegroundColor Cyan
      }           

}
catch {
                Write-Output "Unable to locate installed modules"
                write-output $_.Exception.Message
                Break
}



#Connect to Microsoft Graph.
try {
        
       Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All", "Group.ReadWrite.All"

}
catch {
                Write-Output "Unable to connect to Microsoft Graph"
                write-output $_.Exception.Message
                Break
}

#Get Microsoft Graph Service Principals for SSO.
try {
        
       #$MSRDspId = (Get-MgServicePrincipal -Filter "AppId eq 'a4a365df-50f1-4397-bc59-1a1564b8bb9c'").Id
        $WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id

}
catch {
                Write-Output "Unable to get Graph Service Principal"
                write-output $_.Exception.Message
                Break
}


#Set SSO property on Microsoft Graph Service Principals
try {
        
       #If ((Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $MSRDspId) -ne $true) {
        #Update-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $MSRDspId -IsRemoteDesktopProtocolEnabled
        #}

       If ((Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId) -ne $true) {
            Update-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId -IsRemoteDesktopProtocolEnabled
        }

}
catch {
                Write-Output "Unable to set property on Service Principal"
                write-output $_.Exception.Message
                Break
}


# Get property information on Service Principals
try {
        
       #Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $MSRDspId
       Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId

}
catch {
                Write-Output "Unable to Get property on Service Principal"
                write-output $_.Exception.Message
                Break
}



#Check if group name is being used
try {
        
       $Groupinformation = Get-MgGroup | Where-Object {$_.Name -eq $EntraIDGroup}
           If($Groupinformation){
           write-output "Group already exist"       
           }else{
           
           write-output "Group does not exist"
           write-output "Creating group" 

           $params = @{
	        description = "Group used for Azure Virtual Desktop SSO configuration"
	        displayName = $EntraIDGroup
	        groupTypes = @(
            "DynamicMembership"
            )
            mailEnabled = $false
            mailNickname = "NotSet"
            securityEnabled = $true
            membershipRule = $DynamicDeviceRule
            membershipRuleProcessingState = "on"
        }

            New-MgGroup -BodyParameter $params

        }

}
catch {
                Write-Output "Unable to gather information about Entra ID Groups"
                write-output $_.Exception.Message
                Break
}



#Assign group to Service Principals
try {
        
        $Groupinformation = Get-MgGroup -Filter "DisplayName eq '$EntraIDGroup'"
        
        $tdg = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphTargetDeviceGroup
        $tdg.Id = $Groupinformation.Id
        $tdg.DisplayName = $Groupinformation.DisplayName

        #New-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $MSRDspId -BodyParameter $tdg
        New-MgServicePrincipalRemoteDesktopSecurityConfigurationTargetDeviceGroup -ServicePrincipalId $WCLspId -BodyParameter $tdg
      

}
catch {
                Write-Output "Unable to assign group membership to Service principals"
                write-output $_.Exception.Message
                Break
}


#Disconnect from Microsoft Graph
Disconnect-MgGraph
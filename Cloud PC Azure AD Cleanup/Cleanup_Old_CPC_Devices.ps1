
#Parameters
Param(
    [parameter(HelpMessage = "Specifying a path will export .csv report. Leave the variable blank for no report")] 
    [string]$ExportToCSV = "C:\temp",

    [parameter(HelpMessage = "Specifying '0' will delete all old devices. adding a higher number like '100' will only deleted old devices older than 100 days.")] 
    [Int]$GracePeriod = 50,

    [parameter(HelpMessage = "Setting to 'true' will delete devices, 'false' will not deleted devices.")] 
    [string]$DeleteOldCloudPCDevices = $false

)

#Check if export to csv is configured.
if($ExportToCSV){
    Write-Output "Export of CSV file is configured"
    Write-Output "CSV file will be exported to '$ExportToCSV'"
    $TestPath = test-path $ExportToCSV
    if (!($TestPath)){
        Write-Output "Unable to find specified path, make sure the path exists."
        break
    }
}

#Check if Greceperiod is configured.
if($GracePeriod){
    Write-Output "GracePeriod is configure to $GracePeriod Days."
    Write-Output "Cloud PC has to be older than $GracePeriod Days to be deleted"
    $CurrentDate = Get-Date 
}

#Check Deletion of Cloud PC variable
if($DeleteOldCloudPCDevices -eq $true){
    Write-Output "Variable 'DeleteOldCloudPCDevices' is set to 'True'"
    Write-Output "Old Cloud PCs will be deleted."

}else {
    Write-Output "The Cloud PC won't be deleted"
    Write-Output "To deleted old Cloud PCs set variable 'DeleteOldCloudPCDevices' to 'True' under variables"
}

$StaleDevices = Get-MgDevice -All -Filter "startswith(displayName, 'CPC-')"
Write-Output "There are a total of $($StaleDevices.Count) Cloud PC devices"
$OutputResult = @()
foreach($StaleDevice in $StaleDevices) {
    Write-Output "Processing Cloud PC: '$($StaleDevice.DisplayName)'"
    $CreationDate = get-date $StaleDevice.AdditionalProperties.createdDateTime -Format dd-MM-yyyy
    Write-Output "Cloud PC has been created on $CreationDate"
    $Jointype = $StaleDevice.enrollmentType


    #Declare array for CSV output
    $csvoutput = [PSCustomObject]@{
        "CloudPCName" = "$($StaleDevice.DisplayName)"
        "EnrollmentType"       = "$Jointype"
        "CreationDate"         = "$CreationDate"
        "InGracePeriod"        = ""
        "DeletionStatus"       = ""
    }

   
$CloudPCDevice = Get-MgDeviceManagementVirtualEndpointCloudPC -Filter "ManagedDeviceName eq '$($StaleDevice.DisplayName)'"
If ($CloudPCDevice){
    Write-Output "Cloud PC is exist in Endpoint Manager and is therefore 'Active'."
    $csvoutput.InGracePeriod = "Cloud PC in use"
    $csvoutput.DeletionStatus = "Cloud PC in use"

}else {
    #Starting delete flow
    Write-Output "Cloud PC is not present in Endpoint Manager, starting delete flow."
    #Hybrid device scenario
            if ($Jointype -eq "OnPremiseCoManaged") {
                Write-Output "Cloud PC is hybrid joined"
                Write-Output "You must remove the device on-premise in order clean it up in AzureAD"

                $csvoutput.DeletionStatus = "Must be deleted on-premise"
                $csvoutput.InGracePeriod = "Not Relevant"

                
            }else{
                #Azure AD joined scenario
                Write-Output "Cloud PC is AzureADJoined"

                    if ($DeleteOldCloudPCDevices -eq $True){
                        Write-Output "Cloud PC will be deleted"
                            if($GracePeriod){
                                #Checking if Cloud PC is in range of Grace Period
                                
                                if ($CurrentDate.AddDays(-$GracePeriod) -gt $StaleDevice.AdditionalProperties.createdDateTime) {
                                    #Deleted old Cloud PC
                                    Write-Output "Cloud PC is out of Grace Period, Cloud PC will be deleted."
                                    Write-Output "Performing delete action on Cloud PC..."
                                     
                                    #Remove-MgDevice -DeviceId $StaleDevice.DeviceId 

                                    #Adding value to .csv output
                                    $csvoutput.InGracePeriod = "False"
                                    $csvoutput.DeletionStatus = "Deleted"

                                }else{
                                    Write-Output "Cloud PC is within Grace Period, Cloud PC will not be deleted."
                                    #Adding value to .csv output
                                    $csvoutput.InGracePeriod = "True"
                                    $csvoutput.DeletionStatus = "Not Deleted"
                                }


                            }else {
                                #Delete old Cloud PC
                                Write-Output "Performing delete action on Cloud PC..."
                                #Remove-MgDevice -DeviceId $StaleDevice.DeviceId 
                                $csvoutput.InGracePeriod = "Not configured"
                                $csvoutput.DeletionStatus = "Deleted"
                            }

                    }else{
                         #Adding value to .csv output
                         $csvoutput.InGracePeriod = "Not Relevant"
                         $csvoutput.DeletionStatus = "Deletion parameter is not true"

                    }
                }

            Write-Output ""


        }
    
        $OutputResult += $csvoutput

}
    
if($ExportToCSV){
    $CSVOutputName = "Delete_Old_CloudPC_Devices.csv"
    Write-output "Exporting CSV file to '$ExportToCSV\$CSVOutputName'"
    $OutputResult | export-csv -Path "$ExportToCSV\$CSVOutputName" -NoTypeInformation -force

}
##*===============================================
##* START - PARAMETERS
##*===============================================
Param
(
  [Parameter (Mandatory= $True)]
  [String] $NewImageName
)

#Name of your Custom Image VM
$CustomImageVMName = ""

 
 
##*===============================================
##* END - PARAMETERS
##*===============================================
 
##*===============================================
##* START - SCRIPT BODY
##*===============================================
 

#Connect to Azure
Write-Output "Connecting to Azure..."
Connect-AzAccount -Identity | out-null


$VM = Get-AzVM -Name $CustomImageVMName
$VMName = $VM.Name
 
#Check if Image name is valid
$CheckImageName = get-azimage -name $NewImageName
if ($CheckImageName) {
    Write-Error "Image name already exist choose another Image Name"
     
 
}
 
#Check if VM is running
Write-Output "Checking if VM is deallocated..."
$VMStatus = (get-azvm -ResourceGroupName $VM.ResourceGroupName -Name $VMName -Status).Statuses.DisplayStatus
if ($VMStatus -like "VM Deallocated") {
 
    Write-Output "$VMName is already deallocated..."
 
       
}
else {
    
    Write-Output "$VMName is not deallocated, deallocating VM..."
    Stop-AzVM -Name $VMName -ResourceGroupName $vm.ResourceGroupName -Force | out-null
 
 
}
 
 
    Write-Output "Getting VM information for $VMName..."
        
    #Get Disk, and create snapshot
    Write-Output "Getting Disk information for $VMName.."
    $VMOSDiskConfig = $VM.StorageProfile.OsDisk
    $VMOSDiskName = $VMOSDiskConfig.Name
     
    Write-Output "Creating disk Snapshot"
    $SnapshotName = "$($VMOSDiskName)_SnapshotTempVM"
    $SnapshotConfig =  New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $VM.Location -CreateOption copy -SkuName Standard_LRS
    New-AzSnapshot -Snapshot $SnapshotConfig -SnapshotName $SnapshotName -ResourceGroupName $VM.ResourceGroupName | out-null
 
 
    #Create Temp Disk for VM
    Write-Output "Creating Temp Disk"
    $osDiskName = "$($VMOSDiskName)_TempVM"
    $snapshot = Get-AzSnapshot -ResourceGroupName $VM.ResourceGroupName -SnapshotName $snapshotName
    $diskConfig = New-AzDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy
    $disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $vm.ResourceGroupName -DiskName $osDiskName

    #Create Temp VM Nic 
    Write-Output "Creating Temp NIC"
    $TempNicName = "$($VM.Name)_TempNic"
    $Virtualnetworksettings = $VM.NetworkProfile.NetworkInterfaces[0].Id | Get-AzNetworkInterface
    $nic = New-AzNetworkInterface -Name $TempNicName -ResourceGroupName $vm.ResourceGroupName -Location $snapshot.Location -SubnetId $Virtualnetworksettings.IpConfigurations.subnet.id
 
        
    #Create Temp VM
    Write-Output "Creating Temp VM" 
    $TempVMName = "$($VM.Name)_TempVM"
    $VirtualMachine = New-AzVMConfig -VMName $TempVMName -VMSize $VM.HardwareProfile.VmSize
    $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
    $VirtualMachine = Set-AZVMBootDiagnostic -VM $VirtualMachine -Disable
    New-AzVM -VM $VirtualMachine -ResourceGroupName $vm.ResourceGroupName -Location $snapshot.Location -DisableBginfoExtension | out-null
    $TempVM = Get-AzVM -Name $TempVMName

    Write-Output "Checking if temp VM is started..."
    $VMStatus = (get-azvm -Name $TempVMName -ResourceGroupName $TempVM.ResourceGroupName -Status).Statuses.DisplayStatus

#Timer variables
$Timer = [Diagnostics.Stopwatch]::StartNew()
$TimerRetryInterval = "10"
$Timerout = "900"

While (($Timer.Elapsed.TotalSeconds -lt $Timerout) -and (-not ($VMStatus -like "VM running"))) {
    Start-Sleep -Seconds $TimerRetryInterval
    $TotalSecs = [math]::Round($Timer.Elapsed.TotalSeconds, 0)
    Write-Output -Message "$TempVMName has not started waiting for VM to start. Task been running for $TotalSecs seconds..."
    $VMStatus = (get-azvm -Name $TempVMName -ResourceGroupName $TempVM.ResourceGroupName  -Status).Statuses.DisplayStatus
}
 
$Timer.Stop()
If ($Timer.Elapsed.TotalSeconds -gt $Timerout) {
    Write-Error "$TempVMName did not start before timeout period ending script..."
    Write-Error "Ending script"
    exit
     
}

 #Start sysprep
 $RunCommandscript =
@"

Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /oobe /shutdown /quiet'

"@

#Save Script to local file
$LocalPath = "C:\Temp"
Set-Content -Path "$LocalPath\RunCommandScript.ps1" -Value $RunCommandscript

Write-Output "Running 'Sysprep' on vm: $TempVMName"
$RunCommand = Invoke-AzVMRunCommand -VMName $TempVM.Name -ResourceGroupName $TempVM.ResourceGroupName -CommandId RunPowerShellScript -ScriptPath "$LocalPath\RunCommandScript.ps1"

     
Write-Output "Check if VM is stopped..."
$VMStatus = (get-azvm -ResourceGroupName $TempVM.ResourceGroupName -Name $TempVMName -Status).Statuses.DisplayStatus
 
#Timer variables
$Timer = [Diagnostics.Stopwatch]::StartNew()
$TimerRetryInterval = "10"
$Timerout = "900"
 
While (($Timer.Elapsed.TotalSeconds -lt $Timerout) -and (-not ($VMStatus -like "VM Stopped"))) {
    Start-Sleep -Seconds $TimerRetryInterval
    $TotalSecs = [math]::Round($Timer.Elapsed.TotalSeconds, 0)
    Write-Verbose -Message "$TempVMName has not stopped waiting for VM to stop. Task been running for $TotalSecs seconds..." -Verbose
    $VMStatus = (get-azvm -ResourceGroupName $TempVM.ResourceGroupName -Name $TempVMName -Status).Statuses.DisplayStatus
}
 
$Timer.Stop()
If ($Timer.Elapsed.TotalSeconds -gt $Timerout) {
    Write-Error "$TempVMName did not stopped before timeout period ending script..."
     
}
 
 
Write-Output "$TempVMName is stopped, Starting to deallocate it..."
stop-AzVM -Name $TempVMName -ResourceGroupName $TempVM.ResourceGroupName -Force | out-null
 
 
#Set VM to Generalized
Write-Output "Genealizing temp VM."
Set-AzVm -Name $TempVMName -ResourceGroupName $TempVM.ResourceGroupName -Generalized | out-null
 
#Create managed Image
Write-Output "Creating Azure Managed Image from temp VM"
$GeneralizedVM = Get-azvm -name $TempVMName -ResourceGroupName $TempVM.ResourceGroupName
$image = New-AzImageConfig -Location $GeneralizedVM.location -SourceVirtualMachineId $GeneralizedVM.Id
New-AzImage -Image $image -ImageName $NewImageName -ResourceGroupName $GeneralizedVM.resourcegroupname | out-null
 
#Delete Temp ressources
Write-Output "Removeing Temp Ressources"
Remove-AzVM -Name $TempVM.Name -resourcegroupname $TempVM.ResourceGroupName -Force
Remove-AzDisk -DiskName $tempvm.StorageProfile.OsDisk.Name -ResourceGroupName $TempVM.ResourceGroupName -Force
Remove-AzNetworkInterface -Name $TempNicName -ResourceGroupName $TempVM.ResourceGroupName -Force
Remove-AzSnapshot -SnapshotName $SnapshotName -ResourceGroupName $TempVM.ResourceGroupName -Force
 



Remove-Item -Path "$LocalPath\RunCommandScript.ps1"
##*===============================================
##* END - SCRIPT BODY
##*===============================================  

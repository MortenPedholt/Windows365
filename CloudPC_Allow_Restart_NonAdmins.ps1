 $user = "Users"
 $tmp = [System.IO.Path]::GetTempFileName()
 secedit.exe /export /cfg $tmp
 $settings = Get-Content -Path $tmp
 $account = New-Object System.Security.Principal.NTAccount($user)
 $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
 for($i=0;$i -lt $settings.Count;$i++){
     if($settings[$i] -match "SeShutdownPrivilege")
     {
         $settings[$i] += ",*$($sid.Value)"
     }
 }
 $settings | Out-File $tmp
 secedit.exe /configure /db secedit.sdb /cfg $tmp  /areas User_RIGHTS
 Remove-Item -Path $tmp
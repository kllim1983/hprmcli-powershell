﻿#======================== Define parameters ===========================

$db="Fabrics" #source db name
$ssvr="SQL-S" #source sql server
$tsvr="SQL-T" #target sql server

#======================= End define parameters ========================

Write-Host "Starting script... (it may take a while, please be patient)" -foregroundcolor black -backgroundcolor white

$list=hprmcli sql display -s $ssvr -d $db | select-string -pattern '\d{12}' -allmatches | % {$_.Matches} | % {$_.Value}
Write-Host "`nStep 1/3 - Removing snapshots..." -foregroundcolor black -backgroundcolor white

if (!$list) {
        Write-Host "`nWARNING: The snapshot list is empty! Is the host alive? or is the list expected to be empty?" -foregroundcolor black -backgroundcolor yellow
            $c="" 
            while ($c -notmatch "[y|n]") {
                $c=Read-Host "    Do you want to continue? (Y/N)"
                }
                if ($c -eq "y") {
                Write-Host "`nContinuing script..." -foregroundcolor black -backgroundcolor white
                }
                else {
                Write-Host "`nQuitting script, there is no snapshots found." -foregroundcolor black -backgroundcolor white
                break            
                }
            }
    
    
else {
        Write-Host "`nSnaphsot(s) found: $list, removing all snapshots..." -foregroundcolor black -backgroundcolor white
        ForEach ($snapshot in $list) {hprmcli sql unmount -s $ssvr -t $snapshot -f}
        Start-Sleep 3
        ForEach ($snapshot in $list) {hprmcli sql remove -s $ssvr -t $snapshot -f}
        Start-Sleep 3
    }
Write-Host "`nStep 2/3 - Creating snapshot... " -foregroundcolor black -backgroundcolor white
$e=0
do {
        $temp=hprmcli sql create -s $ssvr -d $db
        $temp
        if ($temp | Select-String ERR) {$e++} else{break}
        Write-Host "`n    Retrying $e/5," -foregroundcolor black -backgroundcolor white
        Start-Sleep 3
        
    } until ($e -eq 5)

while ($e -ge 5 -and $e -le 9) {
            Restart-Service -InputObject $(Get-Service -Computer $ssvr -Name SQLWriter)
            $temp=hprmcli sql create -s $ssvr -d $db
            $temp
        if ($temp | Select-String ERR) {$e++} else{break}
            Write-Host "`n    Retrying $e/10, attempting to restart $ssvr's SQLWriter service (most likely in failed state)." -foregroundcolor black -backgroundcolor white
            Start-Sleep 3
    }

if ($e -eq 10) {
        Write-Host "`nERROR: Something is wrong, unable to create snapshots, please verify and rerun. (Shadow Volume or VSSwriter error are the usual causes)" -foregroundcolor Yellow -backgroundcolor Red
        break
    }

Start-Sleep 3
Write-Host "`nStep 3/3 - Mounting snapshot..." -foregroundcolor black -backgroundcolor white

$mount = hprmcli sql display -s $ssvr | select-string -pattern '\d{12}' -allmatches | % {$_.Matches} | % {$_.Value}
$m=0

if (!$mount)
{
Write-Host "`nERROR: No snapshot(s) found, please verify and rerun." -foregroundcolor Yellow -backgroundcolor Red
}
else
{
    Write-Host "`nSnaphsot(s) found: $mount, mounting the most recent snapshot..." -foregroundcolor black -backgroundcolor white
    do {
        $mo=hprmcli sql mount -s $ssvr -t $($mount | select-object -last 1) -ts $tsvr -d $db -a $db'_T'
        $mo
        if ($mo | Select-String ERR) {$m++} else{break}
        Write-Host "`n    Retrying $e/5," -foregroundcolor black -backgroundcolor white
        Start-Sleep 3
        
    } until ($m -eq 5)
    
    if ($m -eq 5) {
        Write-Host "`nERROR: Something is wrong, unable to mount database, please verify and rerun. (Is the MSSQL service up and running?)" -foregroundcolor Yellow -backgroundcolor Red  
    }
    Write-Host "`nScript completed successfully." -foregroundcolor black -backgroundcolor white
}

Write-Host "`nDEBUG ONLY: $e, $m, $mount,`n`n$mo" -foregroundcolor darkgray 

write-host "`nPress any key to continue..." -foregroundcolor black -backgroundcolor white
[void][System.Console]::ReadKey($true)


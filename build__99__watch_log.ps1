
# watch current state
$log = "D:\Apteco\Build\Holidays\log\build_log.txt"

Get-Content -Path $log -Tail 1 -Wait
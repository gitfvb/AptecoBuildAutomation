################################################
#
# SCRIPT ROOT
#
################################################

# script root path
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{ $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
else
{ $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) }

Set-Location $scriptPath


################################################
#
# DEBUG
#
################################################

$debug = $false

if ( $debug ) {
    $inputMssqlConnectionString = "Data Source=<mssqlserver>;Initial Catalog=<mssqldatabase>;Trusted_Connection=True;"
    $inputDb2ConnectionString = "Server=<db2server>:<port>;Database=<db2database>;Uid=<db2user>;Pwd=<db2password>;"
    $inputSuccessFile = "D:\Apteco\Build\Holidays\temp\build.debug"
} else {
    $inputMssqlConnectionString = $Env:SOURCEDB
    $inputDb2ConnectionString = $Env:DBCONNECTION
    $inputSuccessFile = $Env:WAITFILE
}



################################################
#
# SETTINGS
#
################################################

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$functionsSubfolder = "functions"

# set db connections
$mssqlConnectionString = $inputMssqlConnectionString
$db2ConnectionString = $inputDb2ConnectionString

# Assign variables
$successFile = $inputSuccessFile
$sleepTime = $settings.sleepTime
$maxWaitTimeTotal = $settings.maxSecondsWaiting
$startTime = Get-Date


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# REMOVE SUCCESS FILE
#
################################################

If (Test-Path $successFile ) {
    Remove-Item -Path $successFile -Force
}


################################################
#
# CHECK MSSQL FOR SUCCESS
#
################################################

$mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

Do {

    "Trying to load the data from MSSQL"

    # define query -> currently the age of the date in the query has to be less than 12 hours
    $mssqlQuery = "Select * from dbo.StatusTable where datediff(hh, [LastUpdateDate], GETDATE()) <= $( $settings.maxAgeForData ) "
    
    # execute command
    $mssqlCommand = $mssqlConnection.CreateCommand()
    $mssqlCommand.CommandText = $mssqlQuery
    $mssqlResult = $mssqlCommand.ExecuteReader()
    
    # load data
    $mssqlTable = new-object "System.Data.DataTable"
    $mssqlTable.Load($mssqlResult)
    
    # check for result, count the number of rows for success
    $mssqlSuccess = $mssqlTable.rows.Count -gt 0

    # pause
    if ( $mssqlSuccess ) {
        "MSSQL successful"
    } else {
        "MSSQL not successful"
        Start-Sleep -Seconds $sleepTime
    }

} until ( $mssqlSuccess -or (New-TimeSpan -Start $startTime).TotalSeconds -ge $maxWaitTimeTotal )

$mssqlConnection.Close()


################################################
#
# CHECK DB2 FOR SUCCESS
#
################################################

# Load IBM DB2 assembly
$db2AssemblyFile = "C:\Program Files\Apteco\FastStats Designer\IBM.Data.DB2.dll"
[Reflection.Assembly]::LoadFile($db2AssemblyFile)

# the enviroment variable fills from the designer user defined variables
$db2Connection = New-Object "IBM.Data.DB2.DB2Connection"
$db2Connection.ConnectionString = $db2ConnectionString

$db2Connection.Open()

Do {

    "Trying to load the data from DB2"

    # define query
    $db2Query = "select * from schema.statustable where TIMESTAMP >= (CURRENT TIMESTAMP - $( $settings.maxAgeForData ) HOURS)"
    
    # execute command
    $db2Command = $db2Connection.CreateCommand()
    $db2Command.CommandText = $db2Query
    $db2Result = $db2Command.ExecuteReader()
    
    # load data
    $db2Table = new-object "System.Data.DataTable"
    $db2Table.Load($db2Result)
    
    # check for result, count the number of rows for success
    $db2Success = $db2Table.rows.Count -gt 0

    # pause
    if ( $db2Success ) {
        "DB2 successful"
    } else {
        "DB2 not successful"
        $db2Table
        Start-Sleep -Seconds $sleepTime
    }

} until ( $db2Success -or (New-TimeSpan -Start $startTime).TotalSeconds -ge $maxWaitTimeTotal )

$db2Connection.Close()


################################################
#
# CREATE SUCCESS FILE
#
################################################

if ( ($mssqlSuccess -and $db2Success) -or ( (New-TimeSpan -Start $startTime).TotalSeconds -ge $maxWaitTimeTotal ) ) {
    "MSSQL success: $( $mssqlSuccess )"
    "DB2 success: $( $db2Success )"
    "Timeout reached: $( ( (New-TimeSpan -Start $startTime).TotalSeconds -ge $maxWaitTimeTotal ) )"

    [datetime]::Now.ToString("yyyyMMddHHmmss") | Out-File -FilePath $successFile -Encoding utf8 -Force
}

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"


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
# SETTINGS
#
################################################

#-----------------------------------------------
# ENCRYPTION KEYS
#-----------------------------------------------

# create encryption keys, dependent on the system
$cspParams = New-Object "System.Security.Cryptography.CspParameters"
$cspParams.KeyContainerName = "XML_ENC_RSA_KEY"
$rsaKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspParams)

# these settings will be used to save credentials e.g. for a database
$encryptionSettings = @{
    keyContainerName = $cspParams.KeyContainerName
    keyName = "rsaKey"
    elementsToEncrypt = @("Objects")
    keySize = 256
}


#-----------------------------------------------
# GENERIC SETTINGS
#-----------------------------------------------

# dependent on PROD and TEST
$publishServer = "appservice"
$sourcedatabase = "localhost"
$environment = "PROD" 
$buildDir = "D:\Apteco\Build\"


#-----------------------------------------------
# SYSTEM SPECIFIC SETTINGS
#-----------------------------------------------

$systemsSettings = [array]@()

$systemsSettings += @{
    Name = "Holidays"
    Description = "HolidaysLongerName"
    designFile = "$( $buildDir )Holidays\designs\holidays.xml"
    SystemVariables = @{
        "LOADMONTHS" = 36
        "INCLUDEDUMMY" = "'Real'"
    }
}
    
$systemsSettings += @{
    Name = "Reisen"
    Description = "ReisenLongerName"
    designFile = "$( $buildDir )Reisen\designs\reisen.xml"
    SystemVariables = @{
        "LOADMONTHS" = 12
        "INCLUDEDUMMY" = "'Real','Dummy','Transaktion'"
    }

}
    

#-----------------------------------------------
# ENVIRONMENT VARIABLES USED BY DESIGNER
#-----------------------------------------------

# all environment variables
$environmentVariables = @{
    "BUILDDIR" = $buildDir
    "SOURCEDB" = "Data Source=$( $sourcedatabase );Initial Catalog=customers;Trusted_Connection=True;"
    "PS_CONNECTION" = "Data Source=$( $sourcedatabase );Initial Catalog=PS_Holidays;Trusted_Connection=True;"
    "RS_CONNECTION" = "Data Source=$( $sourcedatabase );Initial Catalog=RS_Holidays;Trusted_Connection=True;"
    "WAITFILE" = "$( $buildDir )#SYSNAME#\temp\build.now"
    "DEPLOY"="\\$( $publishServer )\Publish\#SYSNAME#\updates"
    "APTCRED"="Apteco WebService #SYSNAME# $( $environment )" # 
    "ENVIRONMENT"=$environment
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{
    systems = $systemsSettings
    sleepTime = 60
    maxSecondsWaiting = 10800 # seconds
    maxAgeForData = 16 # hours
    encryption = $encryptionSettings
    environment = $environmentVariables
    variablesXML = "$( $scriptPath )\variables.xml"
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8

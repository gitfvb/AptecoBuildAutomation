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

# Load settings
$settingsFilename = "settings.json"
$functionsSubfolder = "functions"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json


################################################
#
# FUNCTIONS
#
################################################

# load assemblies
Add-Type -AssemblyName System.Security

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}



################################################
#
# LOAD ENCRYPTED VARIABLES
#
################################################

# create encryption keys
$cspParams = New-Object "System.Security.Cryptography.CspParameters"
$cspParams.KeyContainerName = $settings.encryption.keyContainerName
$rsaKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspParams)
$keyName = $settings.encryption.keyName

# load xml file
$xml = New-Object "xml"
$xml.PreserveWhitespace
$xml.Load($settings.variablesXML)

# decrypt encrypted parts
$eXml = [System.Security.Cryptography.Xml.EncryptedXml]::new($xml)
$eXml.AddKeyNameMapping($keyName, $rsaKey)
$eXml.DecryptDocument();

# save decrypted xml file
#$tempxml = ([guid]::NewGuid()).Guid
#$xml.Save("$( $env:TEMP )\$( $tempxml ).xml")

# put decrypted xml into variables
$variables = ConvertFrom-Xml $xml

# decrypt securestrings
$variables.psobject.Members | where-object membertype -like 'noteproperty' | foreach {
    $variable = $_
    if ( $variable.Value.StartsWith("secure#") ) {
        $secureString = $variable.Value -replace "secure#","" | ConvertTo-SecureString
        $credentials = new-object -typename PSCredential -argumentlist "dummy",$secureString
        $_.Value = $credentials.GetNetworkCredential().password
        $credentials = ""
        $secureString = ""
    }
}


################################################
#
# RUN BUILD
#
################################################

$settings.systems | ForEach {
    
    # system settings
    $sysname = $_.Name
    $sysdesc = $_.Description
    $sysvars = $_.SystemVariables
    
    # set base environment variables
    [System.Environment]::SetEnvironmentVariable("SYSNAME",$sysname)
    [System.Environment]::SetEnvironmentVariable("SYSDESC",$sysdesc)

    # set general environment variables
    $settings.environment.psobject.Members | where-object membertype -like 'noteproperty' | ForEach {
        
        $key = $_.Name
        $value = $_.Value
        
        # replace encrypted variables
        $variables.psobject.Members | where-object membertype -like 'noteproperty' | foreach {
            $variable = $_
            $value = $value -replace "#$( $variable.Name )#", "$( $variable.Value )"      
        }
        
        # replace system variables
        $value = $value -replace "#SYSNAME#", $sysname

        # save environment variable
        #"key: $( $key ) - value: $( $value )" 
        [System.Environment]::SetEnvironmentVariable($key,$value)
        "key: $( $key ) - value: $( [System.Environment]::GetEnvironmentVariable($key) )" 
        
    }

    # set system specific environment variables
    $sysvars.psobject.Members | where-object membertype -like 'noteproperty' | ForEach {
        
        $key = $_.Name
        $value = $_.Value
        
        # replace encrypted variables
        $variables.psobject.Members | where-object membertype -like 'noteproperty' | foreach {
            $variable = $_
            $value = $value -replace "#$( $variable.Name )#", "$( $variable.Value )"      
        }
        
        # replace system variables
        $value = $value -replace "#SYSNAME#", $sysname

        # save environment variable
        #"key: $( $key ) - value: $( $value )" 
        [System.Environment]::SetEnvironmentVariable($key,$value)
        "key: $( $key ) - value: $( [System.Environment]::GetEnvironmentVariable($key) )" 
        
    }

    # execute designer console
    & DesignerConsole.exe "$( $settings.designFile )" /load #> "$( $settings.logFile )"       
    
    # empty environment variables
    $settings.environment.psobject.Members | where-object membertype -like 'noteproperty' |  ForEach {
        $key = $_.Name               
        [System.Environment]::SetEnvironmentVariable($key,"")
    }

    # empty system specific variables
    $sysvars.psobject.Members | where-object membertype -like 'noteproperty' |  ForEach {
        $key = $_.Name               
        [System.Environment]::SetEnvironmentVariable($key,"")
    }


}




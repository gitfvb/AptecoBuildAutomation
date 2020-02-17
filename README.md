This program allows you to use one designer file to build multiple systems with different settings or run just one build after the other

# Getting started

* Open PowerShell ISE with domain user that has access to the SQL Server like <domain>\<username>
* Open ```build__00__settings.ps1``` in PowerShell ISE and change settings if needed, after that execute that script to create a local ```settings.json``` file

  * Please create one section like here for every system you want to run in the order you have specified:<br/>
```PowerShell
  $systemsSettings += @{
    Name = "Holidays"
    Description = "HolidaysLongerName"
    designFile = "$( $buildDir )Holidays\designs\holidays.xml"
    SystemVariables = @{
        "LOADMONTHS" = 36
        "INCLUDEDUMMY" = "'Real'"
    }
}
```   

* Open ```build__01__credentials.ps1``` in PowerShell ISE and execute the script. You will be asked for some credentials that are getting saved encrypted into ```variables.xml```
* If you want to use the "wait for query script", you should change those queries. In there are examples for asking a Microsoft SQL Server and a DB2. Please change those queries:
```PowerShell
$mssqlQuery = "Select * from dbo.StatusTable where datediff(hh, [LastUpdateDate], GETDATE()) <= $( $settings.maxAgeForData ) "
...
$db2Query = "select * from schema.statustable where TIMESTAMP >= (CURRENT TIMESTAMP - $( $settings.maxAgeForData ) HOURS)"
```

# Daily Business

* You should create a Windows Task named "Run Build" that runs at minimum every day
* That Task is running the script ```build__20__build_system.ps1```
* There are two scripts that are used and triggered by Designer as preload actions:
  * ```build__10__wait_for_query``` This one will ask the SQLSERVER-WWS and the DB2-DWH for timestamps so it knows all nightly jobs have been finished first. At the end it will create a file which is the trigger for Designer to proceed with the next steps
  * ```build__30__export_maerkte.ps1``` This one is used to create several files with market data that can be used in FastStats e.g. for mapping an other things

# Hints

* There are some debug scripts
  * ```build__99__watch_log.ps1``` Watch the build log life through PowerShell
  * ```build__99__loop.ps1``` Runs the build in a loop
  * ```build__99__create_windows_task.ps1``` Creates a windows task to create a build task, not developed yet
* If you want to change the design sometimes it it best to open the application first with the domain user that has access to the SQLSERVER 

# Screenshots

An example how the ```build__10__wait_for_query``` script is used in Designer

* Pre Load Actions: <br/><br/>![2020-02-17 16_17_15-Clipboard](https://user-images.githubusercontent.com/14135678/74667912-18244680-519c-11ea-94f6-3aba66ec2c9d.png)<br/>


Some examples how you can use or implement environment variables

* System Configuration: Name and Description<br/><br/>![2020-02-17 16_13_34-Clipboard](https://user-images.githubusercontent.com/14135678/74667919-19557380-519c-11ea-86ec-0e34c224e3d0.png)<br/>
* System Configuration: Path to use<br/><br/>![2020-02-17 16_13_44-192 168 31 224 - Remotedesktopverbindung](https://user-images.githubusercontent.com/14135678/74667921-19557380-519c-11ea-930a-e4bd18a5ab14.png)<br/>
* Data Sources: Directly embedded in SQL Queries:<br/><br/>![2020-02-17 16_16_07-Clipboard](https://user-images.githubusercontent.com/14135678/74667908-165a8300-519c-11ea-974b-bc46600cf2fd.png)<br/>
* Post Load Actions: Refer to Credentials that you have used<br/><br/>![2020-02-17 16_15_07-Clipboard](https://user-images.githubusercontent.com/14135678/74667922-19ee0a00-519c-11ea-94de-51669807898d.png)<br/><br/>![2020-02-17 16_18_01-Clipboard](https://user-images.githubusercontent.com/14135678/74667916-18bcdd00-519c-11ea-95ce-ae0ce2802565.png)<br/>
* Post Load Actions: UNC path to deploy the system<br/><br/>![2020-02-17 16_18_31-Clipboard](https://user-images.githubusercontent.com/14135678/74667918-18bcdd00-519c-11ea-8168-474509baceda.png)<br/>


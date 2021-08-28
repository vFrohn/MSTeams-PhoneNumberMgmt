#Moduels to be used:
Import-Module SQLServer -Verbose #DB Writer permissions
Import-Module MicrosoftTeams -Verbose #Teams administrator #https://docs.microsoft.com/en-us/powershell/module/teams/connect-microsoftteams?view=teams-ps#parameters #Need to conenct as Service Princs

#Reference
# https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd?view=sqlserver-ps&source=docs#example-13--connect-to-azure-sql-database--or-managed-instance--using-a-managed-identity
# https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-service-principal-tutorial#assign-an-identity-to-the-azure-sql-logical-server
#
#Auth. using Service Principle with Secret against the SQL DB in Azure and Teams
$ClientID = "e1dd41c9-1d58-4e88-a7b4-9e9aa88fba58" # "enter application id that corresponds to the Service Principal" # Do not confuse with its display name
$TenantID = "b6c54b6e-3286-496c-a554-2a43795873ff" # "enter the tenant ID of the Service Principal"
$ClientSecret = "v_0Wa0~.4Q-ik.mNE5XANZD8L7GQ48.-AI" # "enter the secret associated with the Service Principal"

$RequestToken = Invoke-RestMethod -Method POST `
           -Uri "https://login.microsoftonline.com/$TenantID/oauth2/token"`
           -Body @{ resource="https://database.windows.net/"; grant_type="client_credentials"; client_id=$ClientID; client_secret=$ClientSecret }`
           -ContentType "application/x-www-form-urlencoded"
$AccessToken = $RequestToken.access_token
        
       
#Connect to Teams
Connect-MicrosoftTeams #When this is fixed as SP change it

#Azure DB info
$SQLServer = "seattle.database.windows.net"
$DBName = "PSTNnumbers_DK"
$DBTableName1 = "dbo.PhoneNumbers"

[Array]$Users = Get-CsOnlineUser | Select-Object Alias, LineURI

$Query_UsersInDB = "select * from $DBTableName1 where UsedBy IS NOT NULL;"
$Query_UsersInDB_CleanUp =  "UPDATE $DBTableName1 SET UsedBy='NULL'"
$UsersInDB = Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -AccessToken $AccessToken -Query $Query_UsersInDB -Verbose

#Run through all users
Foreach ($DBUser in $UsersInDB)
{
    if($Users -match $DBUser.UsedBy)
    {
        #Write-Host "Found" $User.UsedBy
    }
    else{
        Write-Host -ForegroundColor red "Not Found"
    }
    #Kig efter om brugeren er i DB, men ikke Teams - Ryd derefter op i DB
    #Kig efter om brugeren er i Teams, men ikke i DB og opdatere derefter DB

}

Function LookUpUser
{
    if($Teamsuser.Alias -notmatch $UsersInDB)
    {
        Write-Host "No match"
    }
    else {
        Write-Host "Match"
    }
}
Function CheckForPhoneNumber
{
    if([string]::IsNullOrWhiteSpace($Teamsuser.LineURI))
    {
        Write-Host "User dont have phone number"
    }
    else {
        Write-Host "User has phone number"
    }
}

Foreach ($Teamsuser in $Users)
{
    if($Teamsuser.Alias -like "*$UsersInDB*") #### broken
    {
        Write-Host -ForegroundColor Yellow $Teamsuser.Alias "Not found i DB"
        if([string]::IsNullOrWhiteSpace($Teamsuser.LineURI))
        {
        Write-Host -ForegroundColor Red $Teamsuser.Alias "dont have phone number"
        }
        else {
        Write-Host -ForegroundColor Green $Teamsuser.Alias "has phone number"
        }
    }
    else {
        Write-Host -ForegroundColor Green $Teamsuser.Alias "Found in DB"
    }
}

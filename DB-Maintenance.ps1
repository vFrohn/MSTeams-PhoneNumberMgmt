#Moduels to be used:
Import-Module SQLServer 
Import-Module MicrosoftTeams

#Auth. using Service Principle with Secret against the SQL DB in Azure and Teams
$ClientID = "" # "enter application id that corresponds to the Service Principal" # Do not confuse with its display name
$TenantID = "" # "enter the tenant ID of the Service Principal"
$ClientSecret = "" # "enter the secret associated with the Service Principal"

$RequestToken = Invoke-RestMethod -Method POST `
           -Uri "https://login.microsoftonline.com/$TenantID/oauth2/token"`
           -Body @{ resource="https://database.windows.net/"; grant_type="client_credentials"; client_id=$ClientID; client_secret=$ClientSecret }`
           -ContentType "application/x-www-form-urlencoded"
$AccessToken = $RequestToken.access_token

# Azure DB info
$SQLServer = ""
$DBName = ""
$DBTableName1 = ""
       
#Connect to Teams
$RequestToken = Invoke-RestMethod -Method POST `
           -Uri "https://login.microsoftonline.com/$TenantID/oauth2/token"`
           -Body @{ resource="https://database.windows.net/"; grant_type="client_credentials"; client_id=$ClientID; client_secret=$ClientSecret }`
           -ContentType "application/x-www-form-urlencoded"
$AccessToken = $RequestToken.access_token

$graphtokenBody = @{   
    Grant_Type    = "client_credentials"   
    Scope         = "https://graph.microsoft.com/.default"   
    Client_Id     = $ClientID 
    Client_Secret = $ClientSecret   
 }  
 
$graphToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method POST -Body $graphtokenBody | Select-Object -ExpandProperty Access_Token 
 
$teamstokenBody = @{   
    Grant_Type    = "client_credentials"   
    Scope         = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239/.default"   
    Client_Id     = $ClientID  
    Client_Secret = $ClientSecret 
 } 
 
$teamsToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method POST -Body $teamstokenBody | Select-Object -ExpandProperty Access_Token 
Connect-MicrosoftTeams -AccessTokens @("$graphToken", "$teamsToken")



# Retrieve Teams users and DB users
$TeamsUsers = Get-CsOnlineUser | Select-Object Alias, LineURI
$Query_UsersInDB = "SELECT * FROM $DBTableName1 WHERE UsedBy IS NOT NULL;"
$UsersInDB = Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -AccessToken $AccessToken -Query $Query_UsersInDB -Verbose

# Function to update DB with Teams user information if not already present
function Update-DatabaseWithTeamsUserInfo {
    param (
        [Parameter(Mandatory = $true)]
        $User
    )

    $userInDB = $UsersInDB | Where-Object { $_.UsedBy -eq $User.Alias }

    if (-not $userInDB -and -not [string]::IsNullOrWhiteSpace($User.LineURI)) {
        $UserPhoneNumber = $User.LineURI.TrimStart('TEL:+45')
        $UserNameInTeams = $User.Alias
        Write-Host "DB Update for $UserNameInTeams $UserPhoneNumber"
        $Query_UsersInDB_Add = "UPDATE $DBTableName1 SET UsedBy='$UserNameInTeams' WHERE PSTNnumber ='$UserPhoneNumber'"
        Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -AccessToken $AccessToken -Query $Query_UsersInDB_Add -Verbose
    }
}

# Function to release number in DB if user not found in Teams
function Release-DBNumberForNonTeamsUser {
    param (
        [Parameter(Mandatory = $true)]
        $DBUser
    )

    $userInTeams = $TeamsUsers | Where-Object { $_.Alias -eq $DBUser }

    if (-not $userInTeams) {
        Write-Host "$DBUser is not found in Microsoft Teams, user will be removed from the DB and number will become available"
        $Query_UsersInDB_CleanUp = "UPDATE $DBTableName1 SET UsedBy=NULL WHERE UsedBy ='$DBUser'"
        Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DBName -AccessToken $AccessToken -Query $Query_UsersInDB_CleanUp -Verbose
    }
}

# Update DB with Teams users info
foreach ($User in $TeamsUsers) {
    Update-DatabaseWithTeamsUserInfo -User $User
}

# Release numbers for users not in Teams
foreach ($DBUser in $UsersInDB.UsedBy) {
    Release-DBNumberForNonTeamsUser -DBUser $DBUser
}
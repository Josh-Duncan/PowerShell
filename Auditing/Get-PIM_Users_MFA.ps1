## Josh Duncan - GitHub@joshduncan.net
## 2023-07-24
## https://github.com/Josh-Duncan/PowerShell/wiki/Auditing-Get%E2%80%90PIM_Users_MFA.ps1
#
## This script will get all the users that have a PIM role assigned
## It will then query each of those users and identify the different types of MFA configured and what is the default.
## The data will be saved to a CSV file and output to the console.
#
## KNOWN ISSUES ##
## - No known issues
#
## TODO
## - Clean Up module installation - Test then install
## - Clean up Connections
#
## Minimum Permissions for full execution
## - Azure Global Reader

# Identify the locaiton you want to save the information
$strOutputFile = "Path_to_save_data.csv"
$strResourceID = "Azure Tenant ID"
Clear-Host
write-host
Write-host "Installing Modules..."
# Install the required modules
Install-Module Microsoft.Graph
Install-Module -Name AzureADPreview
Install-Module -Name MSOnline
Write-Host ""
write-host "Connecting to Services..."
write-host "  - Connecting to MSGraph" -NoNewLine
# Connect to azure and exit if there is a failure
try
{
    Connect-MgGraph | Out-Null
    Write-Host -ForegroundColor Green " [Successful]"
}
catch
{
    Write-Host -ForegroundColor Red " [Failed]"
    Exit
}
write-host "  - Connecting to AzureAD" -NoNewLine
try
{
    Connect-AzureAD | Out-Null
    Write-Host -ForegroundColor Green " [Successful]"
}
catch
{
    Write-Host -ForegroundColor Red " [Failed]"
    Exit
}
write-host "  - Connecting to MS Online" -NoNewLine
try
{
    Connect-MsolService | Out-Null
    Write-Host -ForegroundColor Green " [Successful]"
}
catch
{
    Write-Host -ForegroundColor Red " [Failed]"
    Exit
}

Write-Host ""
write-host "Getting Privileged Role Assigmnents" -NoNewLine
try
{
    # Get all the usres that have access to a privileged role assignment
    # Using the SubjectID and -unique flag, ensure only 1 entry for each user is returned 
    $PIMUsers = Get-AzureADMSPrivilegedRoleAssignment -ProviderId aadRoles -ResourceId $strResourceID | Select-Object SubjectId -Unique
    Write-Host -ForegroundColor Green " [Successful]"
}
catch
{
    # Identify that no PIM roles could be found
    Write-Host -ForegroundColor Red " [Failed - Could not retrieve Privileged Role Assignments]"
    Exit
}

$arrayPIMData = @()
Write-Host ""
Write-Host "Getting User MFA details..."
# get the MFA information for all the PIM users, display and output to the file
foreach ($user in $PIMUsers)
{
    try
    {
        # Look up the user based on the returned subjectID value
        $UserObject = Get-AzureADUser -ObjectId $user.SubjectId
        # Look up the MFA information for the identified user
        $UserMFA = Get-MSolUser -UserPrincipalName $UserObject.UserPrincipalName | Select-Object -ExpandProperty StrongAuthenticationMethods | Sort-Object -Property MethodType
        # Create a temporary record
        $tempRecord = [PSCustomObject]@{
            UserPrincipalName = $UserObject.UserPrincipalName
        }
        write-host ("  - " + $UserObject.UserPrincipalName + "...")
        foreach ($MFA in $UserMFA)
        {   
            # Create a new "column" for each MFA type and identify the default.  This should help make sure if a new type is added that this doesn't have to be updated
            $tempRecord | Add-Member -MemberType NoteProperty -Name $MFA.MethodType -Value $MFA.IsDefault
        }
        # add the temp record to the final array.
        $arrayPIMData += $tempRecord
    }
    catch
    # if there is an error, move on.  I left it here for debugging
    {}
}
Write-Host ("Saving data file to: " + $strOutputFile)
# output the array to a CSV
$arrayPIMData | Export-Csv -Path $strOutputFile -Force
Write-Host ""
# output the array to the consolle
$arrayPIMData | format-table
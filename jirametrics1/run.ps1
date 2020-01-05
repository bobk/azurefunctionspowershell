
# http://github.com/bobk/azurefunctionspowershell
#
# sample PowerShell code that demonstrates:
#    - simple Azure Function written in PowerShell
#    - basic use of JiraPS library https://atlassianps.org/docs/JiraPS/
#    - calculation of a single Jira metric (number of In Progress issues for which a given username is Assignee)
#
# this is a demo of Azure Functions and the JiraPS library and is not intended to be an exhaustive sample of error checking every Jira operation
#

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

Import-Module JiraPS

# Write to the Azure Functions log stream.
Write-Host "starting processing"

#   we need these 5 variables to calculate metrics - note that no user credentials are stored or cached anywhere
Write-Host "looking in GET parameters for variables"
$server = $Request.Query.server
$project = $Request.Query.project
$assignee = $Request.Query.assignee
$username = $Request.Query.username
$userpassword = $Request.Query.userpassword

#   ensure that all the variables are populated via the GET, if not check the POST
if ((-not $server) -or (-not $project) -or (-not $assignee) -or (-not $username) -or (-not $userpassword))
{
    Write-Host "not all variables found via GET, looking in POST"
    $server = $Request.Body.server
    $project = $Request.Body.project
    $assignee = $Request.Body.assignee
    $username = $Request.Body.username
    $userpassword = $Request.Body.userpassword
}

#   perform the query
if (($server) -and ($project) -and ($assignee) -and ($username) -and ($userpassword))
{
    Write-Host "variables:   server =  $server   project = $project   assignee = $assignee   username = $username   userpassword = ***"

    try
    {
        Write-Host "opening Jira connection"
        $jiraoptions = "https://" + $server
        Set-JiraConfigServer -Server $jiraoptions
#   username = Atlassian Cloud Jira Server user ID email address, userpassword = an API token generated under that user ID
        $userpassword_secure = ConvertTo-SecureString $userpassword -AsPlainText -Force
        $jiraconn = New-JiraSession -Credential (New-Object System.Management.Automation.PSCredential($username, $userpassword_secure))
        Write-Host "running query"
        $issues = Get-JiraIssue -Query "project in ($project) and assignee in ($assignee) and statusCategory in (""In Progress"") order by createdDate desc"
    
        $status = [HttpStatusCode]::OK
        $statusstr = "successful connection and query: num In Progress issues = " + $issues.Count.ToString()
    }
    catch
    {
        $status = [HttpStatusCode]::InternalServerError
        $statusstr = "exception occurred during connection or query: no data"
    }
    finally
    {
        Write-Host $statusstr
        Write-Host "closing Jira connection"
        Remove-JiraSession $jiraconn
    }

}
else {
    $status = [HttpStatusCode]::BadRequest
    $statusstr = "error retrieving variables: please pass the variables as either GET or POST"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $statusstr
})

Write-Host "ending processing"

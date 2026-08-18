#################################################
# HelloID-Conn-Prov-Target-HR2Day-Update-Email-Delete
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Invoke-HR2DayRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Endpoint,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstanceUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Method = 'GET',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Body,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Headers
    )

    process {
        try {
            Write-Verbose "Invoking command '$($MyInvocation.MyCommand)' to endpoint '$Endpoint' to Url $InstanceUrl"
            $splatRestMethodParameters = @{
                Uri         = "$InstanceUrl/services/apexrest/hr2d/$Endpoint"
                Method      = $Method
                ContentType = 'application/json'
                Headers     = $Headers
            }

            if($Body -ne $null){
                $splatRestMethodParameters['Body'] = $Body
            }

            Invoke-RestMethod @splatRestMethodParameters
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Resolve-HR2Day-Update-EmailError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )

    process {
        $HttpErrorObj = @{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $HttpErrorObj['ErrorMessage'] = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $stream = $ErrorObject.Exception.Response.GetResponseStream()
            $stream.Position = 0
            $streamReader = New-Object System.IO.StreamReader $Stream
            $errorResponse = $StreamReader.ReadToEnd()
            $HttpErrorObj['ErrorMessage'] = $errorResponse
        }
        Write-Output "'$($HttpErrorObj.ErrorMessage)', TargetObject: '$($HttpErrorObj.RequestUri), InvocationCommand: '$($HttpErrorObj.MyCommand)"
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }   

    #Write-Verbose "Invoking command '$($MyInvocation.MyCommand)'"
    Write-Verbose 'Retrieving HR2Day AccessToken'
$splatParams = @{
            grant_type    = 'client_credentials' 
            username      = $actionContext.Configuration.UserName
            client_id     = $actionContext.Configuration.ClientID
            client_secret = $actionContext.Configuration.ClientSecret
            
        }
    
    $accessToken = Invoke-RestMethod -Uri "$($actionContext.Configuration.BaseUrl)/services/oauth2/token" -Method Post -Body $splatParams

    Write-Verbose 'Adding Authorization headers'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $($accessToken.access_token)")
    $splatParams = @{ Headers = $headers }

    $splatParams['InstanceUrl'] = "$($accessToken.instance_url)"

    Write-Verbose 'Retrieving HR2Day Employee'
    $splatParams['Endpoint']="employee?ids=$($actionContext.References.Account)"

    $correlatedAccount = Invoke-HR2DayRestMethod @splatParams

    $correlatedAccount = $correlatedAccount | Select-Object -First 1
    
    $outputContext.PreviousData.employee = $correlatedAccount

    # Always compare the account against the current account in target system
    if ($null -ne $correlatedAccount) {
        if ($correlatedAccount.hr2d__EmailWork__c -ne $actionContext.Data.employee.hr2d__EmailWork__c){
               $action = 'DeleteAccount'
        } else {
            $action = 'NoChanges'
        }
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DeleteAccount' {
            Write-Information "Updating HR2Day-Update-Email account with accountReference: [$($actionContext.References.Account)]"
            Write-Information "Account property(s) required to update: hr2d__EmailWork__c)"
            
            $body = @{
                request = @{
                    requesterId = $actionContext.Configuration.RequesterId
                    employees = @(
                        @{
                            errors = ''
                            employeeid = $($actionContext.References.Account)
                            employee = $actionContext.Data.employee
                        }
                    )
                }
            }
            
            if (-not($actionContext.DryRun -eq $true)) {
                $splatParamsUpdate = @{
                    Endpoint    = 'employee'
                    InstanceUrl = $accessToken.instance_url
                    Method      = 'PUT'
                    Body        = $body | ConvertTo-Json -Depth 10
                    Headers     = $headers
                }
                $responseUpdateUser = Invoke-HR2DayRestMethod @splatParamsUpdate
            } else {
                Write-Information "[DryRun] Delete HR2Day-Update-Email account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Delete account was successful, Account property updated: hr2d__EmailWork__c]"
                    IsError = $false
                })
            break      
        }

        'NoChanges' {
            Write-Information "No changes to HR2Day-Update-Email account with accountReference: [$($actionContext.References.Account)]"

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = 'No changes will be made to the account during enforcement'
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "HR2Day-Update-Email account: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "HR2Day-Update-Email account with accountReference: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
                    IsError = $true
                })
            break
        }
    }
} catch {
    $outputContext.Success  = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HR2Day-Update-EmailError -ErrorObject $ex
        $auditMessage = "Could not update HR2Day email. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not update HR2Day email. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
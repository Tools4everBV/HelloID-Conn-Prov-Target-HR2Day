#################################################
# HelloID-Conn-Prov-Target-HR2Day-Update-Email-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
#region helper functions
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

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Headers
    )

    process {
        try {
            Write-Verbose "Invoking command '$($MyInvocation.MyCommand)' to endpoint '$Endpoint' to Url $InstanceUrl"
            $splatRestMethodParameters = @{
                Uri         = "$InstanceUrl/services/apexrest/hr2d/$Endpoint"
                Method      = 'Get'
                ContentType = 'application/json'
                Headers     = $Headers
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
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Determine if a user needs to be [created] or [correlated]
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
        $splatParams['Endpoint']="employee?$correlationField=$($correlationValue)"
        $correlatedAccount = Invoke-HR2DayRestMethod @splatParams
        $correlatedAccount = $correlatedAccount | Select-Object -First 1
        
        if ($null -ne $correlatedAccount){
             $action = 'CorrelateAccount'
            } 
        else {
             $action = 'NotFound'
        }          
    }
    else 
    {
        throw "Error in correlation configuration. The correlation configuration is not enabled, but this connector requires the correlation configuration to be set to enabled"
    }

    # Process
    switch ($action) {
        'NotFound' {                                
            Write-Information "HR2Day-Update-Email account: employeeid [$correlationValue] could not be found"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "HR2Day-Update-Email account: [$correlationValue] could not be found, could not update the Email"
                    IsError = $true
                })
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating HR2Day-Update-Email account'

            $outputContext.Data.ids = $correlationValue
            $outputContext.Data.employee = $correlatedAccount
            $outputContext.AccountReference = $correlationValue
            $outputContext.AccountCorrelated = $true
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
                    IsError = $false
                })
           
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HR2Day-Update-EmailError -ErrorObject $ex
        $auditMessage = "Could not create or correlate HR2Day account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create or correlate HR2Day account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
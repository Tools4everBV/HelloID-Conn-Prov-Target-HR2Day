#################################################
# HelloID-Conn-Prov-Target-HR2Day-Update
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-HR2DayError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Error: [$($httpErrorObj.ErrorDetails)] [$($_.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information 'Retrieving HR2Day AccessToken'
    $form = @{
        grant_type    = 'password'
        username      = $($actionContext.Configuration.UserName)
        client_id     = $($actionContext.Configuration.ClientID)
        client_secret = $($actionContext.Configuration.ClientSecret)
        password      = $($actionContext.Configuration.Password)
    }
    $accessToken = Invoke-RestMethod -Uri 'https://login.salesforce.com/services/oauth2/token' -Method Post -Form $form

    Write-Verbose -verbose 'Adding Authorization headers'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $($accessToken.access_token)")
    $splatParams = @{ Headers = $headers }

    Write-Information 'Verifying if a HR2Day account exists'
   
    $Account = @{
        ExternalId = $personContext.Person.ExternalId
        Mail       = $actionContext.Data.Mail
    }

    # Make sure to filter out arrays from $outputContext.Data (If this is not mapped to type Array in the fieldmapping). This is not supported by HelloID.
    $outputContext.PreviousData = $Account
    
    $splatRestMethodParameters = @{
        Uri         = "$($accessToken.instance_url)/services/data/v56.0/sobjects/HR2D__Employee__c/$($actionContext.References.Account)"
        Method      = 'Get'
        ContentType = 'application/json'
        Headers     = $Headers
    }
    
    $Employee = Invoke-RestMethod @splatRestMethodParameters
    
    #Compare work e-mailadress
    if( $($actionContext.Data.Mail) -ne $($employee.hr2d__EmailWork__c) ){
        $action = 'UpdateAccount'
    } else {
        $action = 'NoChanges'
    }

    # Process
    switch ($action) {
        'UpdateAccount' {
                        
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating HR2Day account with accountReference: [$($actionContext.References.Account)]"
                
                $uriPatch = "$($accessToken.instance_url)/services/apexrest/hr2d/employee"
        
                # Build the request body
                $body = @{
                    request = @{
                        requesterId = $($actionContext.Configuration.requesterId)
                        employees   = @(
                            @{
                                errors     = ""
                                employeeId = $($actionContext.References.Account)
                                employee   = @{
                                    "hr2d__emailWork__c" = "$($actioncontext.Data.Mail)"
                                }
                            }
                        )
                    }
                }

                # Convert to JSON (with depth for nested objects)
                $jsonBody = $body | ConvertTo-Json -Depth 10

                $result = Invoke-RestMethod -Uri $uriPatch -Headers ($headers + @{ "Content-Type" = "application/json" }) -Method PUT -Body $jsonBody 
            }
            else {
                Write-Information "[DryRun] Update HR2Day account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            # Make sure to filter out arrays from $outputContext.Data (If this is not mapped to type Array in the fieldmapping). This is not supported by HelloID.
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.name -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "HR2Day account: [$($actionContext.References.Account)] does not need to be updated"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "HR2Day account: [$($actionContext.References.Account)] does not need to be updated"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "HR2Day account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "HR2Day account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HR2DayError -ErrorObject $ex
        $auditMessage = "Could not update HR2Day account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not update HR2Day account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
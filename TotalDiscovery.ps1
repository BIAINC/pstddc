# Copyright © 2013 Business Intelligence Associates, Inc.
# All Rights Reserved

if ( [System.String]::IsNullOrEmpty($TDDCServer))
{
  Set-Variable -Name 'TDDCServer' -Value 'app.totaldiscovery.com' -Scope Global
}
if ( [System.String]::IsNullOrEmpty($TDDCProtocol))
{
  Set-Variable -Name 'TDDCProtocol' -Value 'https' -Scope Global
}

function Connect-TDDC()
{
  param
  (
  [Parameter( Position=0)]
  [Alias("token")]
  [String]
  $AuthToken,

  [Parameter( Position=1)]
  [String]
  $Server)

    if (-not [System.String]::IsNullOrEmpty($AuthToken)) { Set-Variable -Name 'TDDCToken' -Value $AuthToken -Scope Global }
    if (-not [System.String]::IsNullOrEmpty($Server)) { Set-Variable -Name 'TDDCServer' -Value $Server -Scope Global } 

}

function Get-TDDCServer
{
  (Get-Variable -Name 'TDDCServer').Value
}

function Get-TDDCToken
{
  (Get-Variable -Name 'TDDCToken').Value
}

function Get-TDDCHeaders()
{

  if($Global:TDDCToken -eq $null)
  {
    throw (new-object System.ArgumentException("You must specify an auth-token before you can make requests to TotalDiscovery.com"))
  }

  return @{"X-AUTH-TOKEN"= (Get-TDDCToken) }
}

function Get-TDDCContentType()
{
  return  "application/json"
}

function Read-TDDCPagingRestService
{
  param
  (
  [Parameter( Mandatory=$true,
          Position=0)]
  [String[]]
  $Resource,

  [Parameter( Mandatory=$false,
          Position=1)]
  [Int]
  $PageSize = 5
  )


  $offset = 0
  $headers = Get-TDDCHeaders

  do {
    $query = "$($uri.query)&limit=$pageSize&offset=$offset"
    $tdCall = New-TdCall -Method "Get" -Resource $Resource -Query $query
    
    $uriBuilder = New-Object System.UriBuilder( $tdCall['Uri'] )
    $enumerable =  Split-Path $uriBuilder.Path -Leaf 
    
    $response = Invoke-TdCall $tdCall
    $response.$enumerable | % {
        Write-Output $_
        $offset++
      }
    } while (($response.$enumerable).count -ne 0)

}


function Get-Custodians()
{
  [CmdletBinding()]
  param
  (
  [Parameter( Mandatory=$true,
              Position=0,
              ValueFromPipeline = $true,
              ValueFromPipelineByPropertyName = $true,
              ParameterSetName='byCompany')]
  [String]
  $Company,

  [Parameter( Mandatory=$true,
            Position=0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName='byMatter')]
  [String]
  $Matter,

  [Parameter( Mandatory=$false,
              Position=1)]
  [Int]
  $PageSize = 5
  )

  PROCESS {
    switch ($PsCmdlet.ParameterSetName) 
      { 
      "byMatter"  {  Read-TDDCPagingRestService -Resource @( "matters","$matter","custodians") -PageSize $pageSize; break } 
      "byCompany"  {  Read-TDDCPagingRestService -Resource @( "companies", "$company", "custodians" ) -PageSize $pageSize; break } 
      } 
  }
  
}

function Read-ResponseFromException
{
  param(
    [Parameter(Mandatory=$true,Position=0)]
    [System.Object]
    $e)

    $rs = $e.exception.response.GetResponseStream()
    $Encode = new-object System.Text.UTF8Encoding
    $response = $Encode.GetString($rs.ToArray())
    return $response
}

function New-TdCall( [String] $Method, [string[]] $Resource, [String] $Query, [String] $Body )
{
  Write-Verbose "New-TdCall"
  Write-Verbose " -Verb: $method"
  Write-Verbose " -Resources: $Resource"
  Write-Verbose " -Query: $Query"
  Write-Verbose " -Body: $Body"

  $uriString = "http://$(Get-TDDCServer)/api/v1"
  foreach( $resourcePart in $resource )
  {
    $uriString += "/" + $resourcePart
  }

  $uri = New-Object System.UriBuilder($uriString)
  if( $Global:TDDCProtocol -eq 'http' )
  {
    $uri.Scheme = "http"
    $uri.Port = 80
  } else {
    $uri.Scheme = "https"
    $uri.Port = 443
  }

  if( -Not [System.String]::IsNullOrEmpty($Query) ) 
  {
    $uri.Query = $Query
  }
  Write-Verbose " -Uri: $uri"
  $call = @{
    'Uri' = $uri.Uri;
    'Header' = (Get-TDDCHeaders);
    'ContentType' = (Get-TDDCContentType);
    'Method'= $method
  }

  if( -Not [System.String]::IsNullOrEmpty($Body) ) 
  {
    $call['Body'] = $Body
  }

  return $call
}

function Invoke-TdCall( [Hashtable] $tdCall)
{
  try {
    Write-Verbose "Calling server with $($tdCall|Out-String)"
   
    $response = Invoke-RestMethod @tdCall
    return $response
  }
  catch [System.Net.WebException]
  {
    Write-Verbose "Error: $_"
    
    $response= Read-ResponseFromException -e $_
    $json = ConvertFrom-JSON $response

    if($_.exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized)
    {
      Write-Error -Message "Your credentials are invalid or you are not allowed to perform this operation, please check your credentials and try again" -Exception $_.exception
    } elseif ($_.exception.Response.StatusCode.ToString() -eq '422'){
      $json.errors | % {
        $item = $_.email
          $_.issues | % {
            $message = ''
            $issue = $_
            $issue | gm | where { $_.MemberType -eq 'NoteProperty' } | % {
              $property = $_.Name
              $value = $issue.$property
              $issue.$subject | % {
                $message = "$message $property $value; "
              }
            }
            Write-Warning "$item : $message"
          }
        
      }
    } else {
      Write-Error -Message "An unknown error occourred: $($_.exception.message)"
    }
  }
}

function Set-Custodian
{
  [CmdletBinding()]
  param
    (
    [Parameter( Mandatory=$true,
                Position=0,
                ParameterSetName='byCompany')]
    [String]
    [alias("CompanyID")]
    $Company,

    [Parameter( Mandatory=$true,
                Position=0,
                ParameterSetName='byMatter')]
    [String]
    [alias("MatterID")]
    $Matter,

    [Parameter( Mandatory=$true,
                Position=1,
                ValueFromPipelineByPropertyName = $true)]
    [String]
    $Name,
        [Parameter( ValueFromPipeline=$true,
                Position=2,
                ValueFromPipelineByPropertyName = $true)]
    [alias("email")]
    [String]
    $Emailaddress,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("phone")]
    [String]
    $Officephone,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [String]
    $Title,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("Location")]
    [String]
    $Office,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [String]
    $Department,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("Description")]
    [String]
    $Notes,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("FirstName")]
    [String]
    $GivenName,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("LastName")]
    [String]
    $Surname,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("Manager")]
    [String]
    $SupervisorName,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [String]
    $SupervisorEmail,

    [Int]
    $BatchSize = 100

  )

  Begin 
  {
    switch ($PsCmdlet.ParameterSetName) 
      { 
      "byMatter"  { 
        $id = $matter
        $api_name = 'matters'
        break; } 
      "byCompany"  { 
        $id = $company
        $api_name = 'companies'
        break } 
      }

    $custodians = @()


    function Send-CustodianBatch($custodians, $api_name, $id, $headers)
    {
      $custodians = @{'custodians' = $custodians}
      $body = (ConvertTo-Json $custodians)

      $tdCall = New-TdCall -Method "Post" -Resource @( $api_name, $id, "custodians.json" ) -Body $body
      Invoke-TdCall $tdCall  
    }

  }

  Process
  {

    $custodian = @{"name" = $name; "email" = $emailaddress; "phone" = $officephone; "title" = $title; "location" = $office; "department" = $department; "notes" = $notes; "first_name" = $GivenName; "last_name" = $Surname; "supervisor_name" = $supervisorName; "supervisor_email" = $supervisorEmail}
    
    if ( ($input) -and ($input.Manager) -and $input.Manager.StartsWith("CN=")) 
    {
      Write-Verbose "Looking up manager $($input.Manger)"
      try {
        $manager_identity = Get-ADUser -Identity $input.Manager -Properties EmailAddress
        $custodian['supervisor_email'] = $manager_identity.EmailAddress
        $custodian['supervisor_name'] = $manager_identity.Name
      } catch {
        Write-Warning "Could not find $($input.Manager)"
      }
    }

    $keys = $custodian.keys | % { Write-Output $_}
    $keys | % { if ($custodian.$_ -eq $null ) {$custodian.Remove($_)} }

    Write-Host "Processing $($custodian['Name'])"
    
    $custodians = $custodians + $custodian
    if($custodians.count -eq $batchSize)
    {
      Send-CustodianBatch $custodians $api_name $id $headers
      $custodians = @()
    }

  }

  End
  {
    if($custodians.count -ne 0)
    {
      Send-CustodianBatch $custodians $api_name $id $headers
    }

  }  

}

function Add-Collection 
{
  [CmdletBinding()]
  param(
    [Parameter( Mandatory=$true,
                Position=0)]
    [String]
    [alias("MatterID")]
    $Matter,

    [Parameter( ValueFromPipelineByPropertyName = $true)]
    [alias("id")]
    [String]
    $CustodianId,

    [Int]
    $BatchSize = 100
  )

  Begin 
  {
    $custodians = @()

    function Send-CustodianBatch()
    {
      $collection_options = @{
        'custodian_ids' = $custodians
        'matter_id' = $matter
      }
      $body = (ConvertTo-Json $collection_options)

      $tdCall = New-TdCall -Method "Post" -Resource @( "collections", "create_automated_collections" ) -Body $body
      Invoke-TdCall $tdCall  
    }

  }

  Process
  {
    $custodians += $CustodianId
    if($custodians.count -eq $batchSize)
    {
      Send-CustodianBatch
      $custodians = @()
    } 
  }

  End 
  { 
    if($custodians.count -ne 0)
    {
      Send-CustodianBatch
    }
  }
}

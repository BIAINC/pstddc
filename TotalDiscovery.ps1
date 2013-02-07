Set-Variable -Name 'TDDCServer' -Value 'app.totaldiscovery.com' -Scope Global
Set-Variable -Name 'TDDCProtocol' -Value 'https' -Scope Global

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
  [String]
  $EndPoint,

  [Parameter( Mandatory=$false,
          Position=1)]
  [Int]
  $PageSize = 5
  )


  $offset = 0
  $headers = Get-TDDCHeaders

  do {
    
    $uri = New-Object System.UriBuilder("http://$(Get-TDDCServer)/$endPoint")
    $uri.Query = "$($uri.query)&limit=$pageSize&offset=$offset"
    if( $Global:TDDCProtocol -match 'http' )
    {
      $uri.Scheme = "http"
      $uri.Port = 80
    } else {
      $uri.Scheme = "https"
      $uri.Port = 443
    }

    $enumerable =  Split-Path $uri.Path -Leaf 

    $response = Invoke-RestMethod -Uri $uri.Uri -Header (Get-TDDCHeaders) -Method Get -ContentType (Get-TDDCContentType)
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
      "byMatter"  {  Read-TDDCPagingRestService -endPoint "/api/v1/matters/$matter/custodians" -pageSize $pageSize; break } 
      "byCompany"  {  Read-TDDCPagingRestService -endPoint "/api/v1/companies/$company/custodians" -pageSize $pageSize; break } 
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
    $headers = Get-TDDCHeaders
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
      try {

        $uri = New-Object System.UriBuilder("http://$(Get-TDDCServer)/api/v1/$api_name/$id/custodians.json")

        if( $Global:TDDCProtocol -match 'http' )
        {
          $uri.Scheme = "http"
          $uri.Port = 80
        } else {
          $uri.Scheme = "https"
          $uri.Port = 443
        }


        $custodians = @{'custodians' = $custodians}
        $body = (ConvertTo-Json $custodians)

        Write-Verbose "Calling $uri"
        Write-Verbose " - Verb: POST"
        Write-Verbose " - Body: "
        Write-verbose "$body"

        $response = Invoke-RestMethod -Uri $uri.Uri -Header $headers -Method Post -ContentType (Get-TDDCContentType) -Body $body;
        
      }
      catch [System.Net.WebException]
      {
        $e = $ERROR[0] 
        Write-Verbose "Error: $e"
        $response= Read-ResponseFromException -e $e

        $json = ConvertFrom-JSON $response

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
        
      }
    }

  }

  Process
  {

    $custodian = @{"name" = $name; "email" = $emailaddress; "phone" = $officephone; "title" = $title; "location" = $office; "department" = $department; "notes" = $notes; "first_name" = $GivenName; "last_name" = $Surname; "supervisor_name" = $supervisorName; "supervisor_email" = $supervisorEmail}
    
    if ( ($input) -and ($input.Manager) -and $input.Manager.StartsWith("CN=")) 
    {
      Write-Verbose "Looking up manager $($input.Manger)"
      $manager_identity = Get-ADUser -Identity $input.Manager -Properties EmailAddress
      $custodian['supervisor_email'] = $manager_identity.EmailAddress
      $custodian['supervisor_name'] = $manager_identity.Name
    }

    $keys = $custodian.keys | % { Write-Output $_}
    $keys | % { if ($custodian.$_ -eq $null ) {$custodian.Remove($_)} }


    Write-Verbose "Creating: $($custodian['Name'])"
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


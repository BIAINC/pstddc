$here = Split-Path -Parent (Split-Path -Parent(Split-Path -Parent $MyInvocation.MyCommand.Path))
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")

. "$here\$sut"

Describe "Connect-TDDC" `
{
  Context "Modifying connection parameters" `
  {
   
    It "Should default production api" `
    {
      $Global:TDDCServer.should.be('preserve.catalystsecure.com')   
    }

    It "Should default to a null token" `
    {
      if($Global:TDDCAuthToken -ne $null)
      {
        throw New-Object PesterFailure($null, $Global:TDDCAuthToken)
      }
    }

    It "Should set the server to another address" `
    {
      Connect-TDDC -Server www.google.com -AuthToken abc123

      $Global:TDDCServer.should.be('www.google.com')
      $Global:TDDCToken.should.be('abc123')

      $Global:TDDCServer = 'preserve.catalystsecure.com'
      $Global:TDDCToken = $null

    }

    It "Should set the auth token" `
    {
      Connect-TDDC -AuthToken abc123

      $Global:TDDCToken.should.be('abc123')

      $Global:TDDCToken = $null
    }

    It "Should set the connection port" `
    {
      Connect-TDDC -Port 1234 -AuthToken abc123

      $Global:TDDCPort.should.be(1234)

      $Global:TDDCPort = $null
    }

    It "Should set the protocol" `
    { 
      $PreTestProtocol = $Global:TDDCProtocol
      Connect-TDDC -Protocol 'https' -AuthToken abc123

      $Global:TDDCProtocol.should.be('https')

      Connect-TDDC -Protocol 'http' -AuthToken abc123

      $Global:TDDCProtocol.should.be('http')

      $Global:TDDCProtocol = $PreTestProtocol
    }

    It "Should set both the server and auth token" `
    {
      Connect-TDDC -AuthToken abc123 -Server www.google.com

      $Global:TDDCToken.should.be('abc123')
      $Global:TDDCServer.should.be('www.google.com')
      
      $Global:TDDCToken = $null
      $Global:TDDCServer = 'preserve.catalystsecure.com'
    }
  }
}

Describe "Get-TDDCHeaders" `
{
  It 'Should error if AuthToken is null' `
  {
    $Global:TDDCToken = $null
    $errored = $false
    try {
      Get-TDDCHeaders
    } Catch [System.ArgumentException] {
      $errored = $true;
    }

    $errored.should.be($true)
  }

  It 'Embed the Auth Token in the headers' `
  {
    Connect-TDDC -AuthToken abc123
    $result = Get-TDDCHeaders

    $result['X-AUTH-TOKEN'].should.be('abc123')
  }
  
}

Describe "New-TdCall" `
{
  It 'Should convert encoding to UTF8' `
  {
    $tdCall = New-TdCall -Method "Post" -Resource @( "collections", "create_automated_collections" ) -Body (Get-Content './test/mock_data/codepage-1252' -Encoding String )
    $tdCall['Body'][0].should.be(195)
    $tdCall['Body'][1].should.be(177)
  }
}

Describe "Get-TDDCContentType" `
{
  It 'Should return json' `
  {
    (Get-TDDCContentType).should.be('application/json')
  }
  
}

Describe "New-TdCall" `
{
  It ''
}

Describe "Read-TDDCPagingRestService" `
{
  Context "Reading a pageable rest interface" `
  {
    Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.Query -match "offset=0" } -MockWith {
      $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
      return $custodians
    }

    Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.Query -match "offset=2" } -MockWith {
      $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
      return $custodians
    }

    Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.Query -match "offset=4" } -MockWith {
      $custodians = Get-Content './test/mock_data/custodians_empty.json' -raw | ConvertFrom-Json
      return $custodians
    }

    Connect-TDDC -AuthToken abc123 -server 'localhost'

    It 'Should Enumerate all pages of Custodians' `
    {
      $cust_count = 0
      Get-Custodians -company 1234 | % {
        $cust_count++
      }

      $cust_count.should.be(4)
      Assert-VerifiableMocks
    }

    
  }
}


Describe "Get-Custodians" `
{
  Context "Reading Custodian Information" `
  {
    Connect-TDDC -AuthToken abc123 -server 'localhost'

    It 'Should have defined custodian properties' `
    {
      Mock Invoke-RestMethod -ParameterFilter { $Uri.Query -match "offset=0" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -ParameterFilter { $Uri.Query -match "offset=2" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -ParameterFilter { $Uri.Query -match "offset=4" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians_empty.json' -raw | ConvertFrom-Json
        return $custodians
      }

      $custodian = Get-Custodians -company 1234 | Select -first 1

      $members = ($custodian | gm)

      ($members | Where { $_.Name -eq 'id' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'name' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'email' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'phone' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'title' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'location' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'department' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'notes' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'first_name' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'last_name' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'supervisor_name' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'supervisor_email' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'custodian_number' }).count.should.be(1)
      ($members | Where { $_.Name -eq 'company_id' }).count.should.be(1)
      
    }
  }

  Context "Custodian Lookup by Matter" `
  {
    Connect-TDDC -AuthToken abc123 -server 'localhost'

    It 'Should lookup custodians by matter' `
    {
      Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Uri.Query -match "offset=0" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -Verifiable -ParameterFilter {$Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Uri.Query -match "offset=2" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Uri.Query -match "offset=4" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians_empty.json' -raw | ConvertFrom-Json
        return $custodians
      }

       Mock Invoke-RestMethod  -MockWith {
        Write-Host $uri
      }
      (Get-Custodians -matter 1234).count.should.be(4)
      Assert-VerifiableMocks 
      
    }

  }

  Context "Custodian Lookup by customer" `
  {
    Connect-TDDC -AuthToken abc123 -server 'localhost'

    It 'Should lookup custodians by customer' `
    {
      Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Uri.Query -match "offset=0" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -Verifiable -ParameterFilter {$Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Uri.Query -match "offset=2" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians.json' -raw | ConvertFrom-Json
        return $custodians
      }

      Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Uri.Query -match "offset=4" } -MockWith {
        $custodians = Get-Content './test/mock_data/custodians_empty.json' -raw | ConvertFrom-Json
        return $custodians
      }


 
      (Get-Custodians -company 1234).count.should.be(4)
      Assert-VerifiableMocks

      
    }

  }

}

Describe "Set-Custodian" `
{
  Context "Errors" `
  {
    #It 'Should write warnings to the console' `
    #{
    #  Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Method -eq 'POST'  } -MockWith {
    #    $e = (new-object System.Net.WebException("Yeah, this custodian has errors"))
    #    $ERROR.Add( ( New-Object System.Management.Automation.ErrorRecord($e, $null, 'NotSpecified', $null) ) )
    #    throw $e
    #  }

    #  Mock Read-ResponseFromException -Verifiable -MockWith `
    #  {
    #    $custodians = Get-Content './test/mock_data/with_error.json' -raw
    #    return $custodians
    #  }
    #  Mock Write-Warning -Verifiable -MockWith `
    #  {
    #    $args.should.match('leonora@abbottschiller.ca')
    #    $args.should.match('Email is invalid')
    #    $args.should.match("Name can't be blank")
    #  }

    #  It 'Should write warning to the console' `
    #  {
  
    #      Connect-TDDC -AuthToken abc123 -server 'localhost'
    #      $custodians = @()
    #      1..10 | % { 
    #        $custodian = New-Object PSObject
    #        Add-Member -InputObject $custodian -Name 'Name' -Value "Custodian $_" -Type NoteProperty
    #        Add-Member -InputObject $custodian -Name 'email' -Value "Custodian$_@example.com" -Type NoteProperty
    #        $custodians = $custodians + $custodian
    #        Write-Output $custodian
    #      } | Set-Custodian -matter 1234
    #  
    #    Assert-VerifiableMocks
    #  }
    #  

    #}
  }
  Context "Batch Operations" `
  {
    It 'Upload a custodian to a company in batches' `
    {
     Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Method -eq 'POST'  } -MockWith {
        $error = Get-Content './test/mock_data/empty_error.json' -raw | ConvertFrom-Json
        return $error
     }



      Connect-TDDC -AuthToken abc123 -server 'localhost'
      $custodians = @()
      1..201 | % { 
        $custodian = New-Object PSObject
        Add-Member -InputObject $custodian -Name 'Name' -Value "Custodian $_" -Type NoteProperty
        Add-Member -InputObject $custodian -Name 'email' -Value "Custodian$_@example.com" -Type NoteProperty
        $custodians = $custodians + $custodian
        Write-Output $custodian
      } | Set-Custodian -company 1234

      Assert-MockCalled Invoke-RestMethod -Time 3 -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Method -eq 'POST'  }
      Assert-VerifiableMocks
    }


    It 'Upload a custodian to a matter in batches' `
    {
     Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Method -eq 'POST'  } -MockWith {
        $error = Get-Content './test/mock_data/empty_error.json' -raw | ConvertFrom-Json
        return $error
     }



      Connect-TDDC -AuthToken abc123 -server 'localhost'
      $custodians = @()
      1..201 | % { 
        $custodian = New-Object PSObject
        Add-Member -InputObject $custodian -Name 'Name' -Value "Custodian $_" -Type NoteProperty
        Add-Member -InputObject $custodian -Name 'email' -Value "Custodian$_@example.com" -Type NoteProperty
        $custodians = $custodians + $custodian
        Write-Output $custodian
      } | Set-Custodian -matter 1234

      Assert-MockCalled Invoke-RestMethod -Time 3 -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Method -eq 'POST'  }
      Assert-VerifiableMocks
    }
  }
  Context "Uploads custodians company" `
  {
    
    It 'Upload a custodian to a company' `
    {
     Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/companies/1234" -and $Method -eq 'POST' } -MockWith {
        $error = Get-Content './test/mock_data/empty_error.json' -raw | ConvertFrom-Json
        return $error
     }


      Connect-TDDC -AuthToken abc123 -server 'localhost'

      $response = Set-Custodian -company 1234 -name "Paul Morton" -email "pmorton@biaprotect.com"
      $response.errors.count.should.be(0)
      Assert-VerifiableMocks
    }


    It 'Upload a custodian to a matter' `
    {
     Mock Invoke-RestMethod -Verifiable -ParameterFilter { $Uri.PathAndQuery -match "/api/v1/matters/1234" -and $Method -eq 'POST' } -MockWith {
        $error = Get-Content './test/mock_data/empty_error.json' -raw | ConvertFrom-Json
        return $error
     }

      Connect-TDDC -AuthToken abc123 -server 'localhost'

      $response = Set-Custodian -matter 1234 -name "Paul Morton" -email "pmorton@biaprotect.com"
      $response.errors.count.should.be(0)
      Assert-VerifiableMocks
    }


  }

}

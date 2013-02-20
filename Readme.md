## Pre-Requisites

### Required
  - Powershell v3 (http://www.microsoft.com/en-us/download/details.aspx?id=34595)

#### Optional
  - Active Directory CmdLets - Used for syncing Active Directory 
    - Windows 7 (http://blogs.msdn.com/b/rkramesh/archive/2012/01/17/how-to-add-active-directory-module-in-powershell-in-windows-7.aspx)
    - Windows 2008 (http://www.windowscommandsyntax.com/windows-powershell/how-to-install-the-active-directory-module-for-powershell/)

## Installation

  1. Open Powershell
  2. Install the required version

  - Latest Release Version

  ```powershell
    Invoke-Expression (Invoke-WebRequest https://s3.amazonaws.com/pstddc/Install.ps1).Content
  ```
    - CI Build - Replace <version> with the version you want to deploy
      
  ```powershell
    Invoke-Expression (Invoke-WebRequest https://s3.amazonaws.com/pstddc/ci/<version>/Install.ps1).Content
  ```

__IMPORTANT__

1. In the examples below, you should replace anything enclosed in <> with approprate value. For example <code>&lt;matter id&gt;</code> would be replaced with <code>1</code> if my matter id was one.

2. Once per session, you need to set your authorization token. If you do not set the authorization token, _none_ of the examples below will work

  ```powershell
    Import-Module TotalDiscovery
    Connect-TDDC -AuthToken <Your Auth Token>
  ````
  
3. Your BIA representive will provide you with a <Company> and <AuthToken>

## Examples

### Upload data From a CSV to your company
  1. Download [users.csv](https://github.com/BIAINC/pstddc/raw/master/samples/users.csv) from the [samples folder](https://github.com/BIAINC/pstddc/tree/master/samples)
  2. Import the CSV and sync the custodian details on the company. If the custodian already exists, it will be updated. 

  ```powershell
    Import-CSV <downloaded_csv> | Set-Custodian -Company <Company>
  ```

### Upload data From a CSV to a matter
  1. Download [users.csv](https://github.com/BIAINC/pstddc/raw/master/samples/users.csv) from the [samples folder](https://github.com/BIAINC/pstddc/raw/master/samples/)
  2. Import the CSV and sync the custodian details on the matter. If the custodian already exists, it will be updated. 

  ```powershell
    Import-CSV <downloaded_csv> | Set-Custodian -Matter <Matter>
  ```

### Import data from ActiveDirectory to a matter
  1. **You must be on a machine that has the ActiveDirectory CmdLets installed**
  2.  Find all ActiveDirectory users who are enabled and have a e-mail address field and adds them to a matter
  ```powershell
    Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2)(mail=*))" -Properties OfficePhone,EmailAddress,Title,Office,Department,Description,Manager | Set-Custodian -Matter <matter>
  ```

### Import data from ActiveDirectory to a company
  1. You must be on a machine that has the ActiveDirectory CmdLets installed
  2. Find all ActiveDirectory users who are enabled and have a e-mail address field and adds them to a company
  ```powershell
    Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2)(mail=*))" -Properties OfficePhone,EmailAddress,Title,Office,Department,Description,Manager | Set-Custodian -Company <company>
  ```

  ### Listing custodians in a company
  ```powershell
    Get-Custodians -Company <Company ID>
  ```

  ### Listing custodians in a matter
  ```powershell
    GetCustodians -Matter <Matter ID>
  ```

# Copyright Notice
  ```
Copyright © 2013 Business Intelligence Associates, Inc.
All Rights Reserved
```
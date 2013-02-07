
## Pre-Requisites
  ### Required
    - Powershell v3 (http://www.microsoft.com/en-us/download/details.aspx?id=34595)
  #### Optional
    - Active Directory CmdLets - Used for syncing Active Directory

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

## Examples

** IMPORTANT ***

1. In the examples below, you should replace anything enclosed in <> with approprate value. For example <code><matter id><code> would be replaced with <code>1<code> if my matter id was one.

2. Once per session, you need to set your authorization token. If you do not set the authorization token, _none_ of the examples below will work.

```powershell
  Connect-TDDC -AuthToken <Your Auth Token>
````


### Upload data From a CSV to your company
  1. Download [users.csv](https://github.com/BIAINC/pstddc/raw/master/samples/users.csv) from the [samples folder](https://github.com/BIAINC/pstddc/raw/master/samples/)
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
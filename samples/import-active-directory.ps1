Import-Module TotalDiscovery
Connect-TDDC -AuthToken <Auth Token>
Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2)(mail=*))" -Properties OfficePhone,EmailAddress,Title,Office,Department,Description,Manager | Set-Custodian -Company <company>

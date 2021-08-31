Connect-TDDC -AuthToken '<Your Token>'
Get-Matters -Company <CompanyID> | Get-LegalHolds | Convert-LegalHoldToCustodians | Group-LegalHoldsByCustodian | % {
    $email = $_.email
    $user = Get-ADUser -Filter {EmailAddress -like $email}
    if ($user.count -eq 0) {
        Write-Warning "User not found in active directory $($custodian.email)"
    } else {
        if( $_.is_on_hold ){
            Write-Host "Setting $($email) to ON legal hold status"
            Set-aduser -Replace @{description="OnLegalHold"} -Identity $user
        } else {
            Write-Host "Setting $($email) to OFF legal hold status"
            Set-AdUser -Replace @{description="OffLegalHold"} -Identity $user
        }
    }
}

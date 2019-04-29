#------------------------------------------------------------------------------
#
# Copyright � 2013 Microsoft Corporation.  All rights reserved.
#
# THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED �AS IS� WITHOUT
# WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
# FOR A PARTICULAR PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR 
# RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
# 
# Get-MsolAccountSku | Where {$_.ConsumedUnits -ge 1}
# Modified by AlanPs1
#
#------------------------------------------------------------------------------

Import-Module MSOnline
$cred = Get-Credential
Connect-MsolService -Credential $cred

$oldLicense = "WiggleyWorm12345:ENTERPRISEPACK"
$newLicense = "WiggleyWorm12345:ENTERPRISEPREMIUM"

# Potential to target thos with Phone Stsyem and to disable it after enabling in E5
# $PhoneSystem = "WiggleyWorm12345:MCOEV"
# $PbiStandard = "WiggleyWorm12345:POWER_BI_STANDARD"
# $BizApps = "WiggleyWorm12345:SMB_APPS"

$users = Get-MsolUser -MaxResults 5000 | Where-Object { $_.isLicensed -eq "TRUE" } 

<#

$CSVImport = 'D:\OneDrive - AW Tech Services\Git - Root\Projects\E3-Licensed-users.csv'
$CSVUsers = Import-Csv -Path $CSVImport

$users = foreach ($line in $CSVUsers) {

    Get-MsolUser -UserPrincipalName $line.UserPrincipalName

}

#>

# $User.Licenses

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    foreach ($license in $user.Licenses) {
        if ($license.AccountSkuId -eq $oldLicense) {
            $disabledPlans = @()
            foreach ($licenseStatus in $license.ServiceStatus) {
                $plan = $licenseStatus.ServicePlan.ServiceName
                $status = $licenseStatus.ProvisioningStatus
                if ($status -eq "Disabled") {
                    # We found a disabled service. We might need to translate it.
                    # For example, in an E1 license, Exchange Online is called "EXCHANGE_S_STANDARD", and
                    # in an E3 license it's called "EXCHANGE_ENTERPRISE".

                    if ($plan -eq "BPOS_S_TODO_2") {
                        $disabledPlans += "BPOS_S_TODO_3"
                    }
                    elseif ($plan -eq "FORMS_PLAN_E3") {
                        $disabledPlans += "FORMS_PLAN_E5"
                    }
                    elseif ($plan -eq "STREAM_O365_E3") {
                        $disabledPlans += "STREAM_O365_E5"
                    }
                    elseif ($plan -eq "FLOW_O365_P2") {
                        $disabledPlans += "FLOW_O365_P3"
                    }
                    elseif ($plan -eq "POWERAPPS_O365_P2") {
                        $disabledPlans += "POWERAPPS_O365_P3"
                    }
                    else {
                        # Example: MCOSTANDARD
                        $disabledPlans += $plan
                    }                    
                }
            }
            # Always disabled Services
            # $disabledPlans += "OFFICESUBSCRIPTION"
            # $disabledPlans += "RMS_S_ENTERPRISE"
            $disabledPlans += "MIP_S_CLP2" # Unknown
            $disabledPlans += "ADALLOM_S_O365" # O365 Advanced Security Management
            $disabledPlans += "EQUIVIO_ANALYTICS" # ffice 365 Advanced Compliance
            $disabledPlans += "LOCKBOX_ENTERPRISE" # Customer Lockbox Enterprise
            $disabledPlans += "EXCHANGE_ANALYTICS" # Microsoft MyAnalytics
            $disabledPlans += "ATP_ENTERPRISE" # Exchange Online Advanced Threat Protection
            $disabledPlans += "PAM_ENTERPRISE" # Unknown
            $disabledPlans += "THREAT_INTELLIGENCE" # Office 365 Threat Intelligence
            $disabledPlans += "MCOMEETADV" # Audio Conferencing

            # Below 2 looks likely to be disabled when uncommenting extra script bits
            $disabledPlans += "MCOEV" # Phone System
            $disabledPlans += "BI_AZURE_P2" # Power BI Pro P2

            $disabledPlans = $disabledPlans | select -Unique
            if ($disabledPlans.Length -eq 0) {
                Write-Host("User $upn will go from $oldLicense to $newLicense and will have no options disabled.")
                Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $newLicense -RemoveLicenses $oldLicense 
            }
            else {
                $options = New-MsolLicenseOptions -AccountSkuId $newLicense -DisabledPlans $disabledPlans
                Write-Host("User $upn will go from $oldLicense to $newLicense and will have these options disabled: $disabledPlans")
                Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $newLicense -LicenseOptions $options -RemoveLicenses $oldLicense 
            }

        }

    }

}
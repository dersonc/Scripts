# This Sample Code is provided for the purpose of illustration only and is not intended to be used 
# in a production environment. THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" 
# WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. We grant You a nonexclusive, 
# royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code 
# form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to 
# market Your software product in which the Sample Code is embedded; (ii) to include a valid copyright 
# notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold 
# harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ 
# fees, that arise or result from the use or distribution of the Sample Code.

# This sample script is not supported under any Microsoft standard support program or service. 
# The sample script is provided AS IS without warranty of any kind. Microsoft further disclaims 
# all implied warranties including, without limitation, any implied warranties of merchantability 
# or of fitness for a particular purpose. The entire risk arising out of the use or performance of 
# the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
# or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
# damages whatsoever (including, without limitation, damages for loss of business profits, business 
# interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
# inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
# possibility of such damages.

# Load the Configuration Manager module
Import-Module "$($Env:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
# Connect to the SCCM site
$siteCode = "PS1"
cd "$siteCode`:"

function Green
{
    process { Write-Host $_ -ForegroundColor Green }
}

function Red
{
    process { Write-Host $_ -ForegroundColor Red }
}

# Function to check the package share option
function Check-PackageShareOption {
    param (
        [string]$PackageType,
        [string]$PackageId
    )

    $packageProperties = Get-WmiObject -Namespace "root\SMS\site_$siteCode" -Query "SELECT * FROM SMS_$PackageType WHERE PackageID='$PackageId'"

    if ($packageProperties.PkgFlags -band 0x80) {
        Write-Output "[$PackageType ID: $PackageId - Name: $($packageProperties.Name)] has the 'Copy the content in this package to a package share on distribution points' option enabled." | Red
    } else {
        Write-Output "[$PackageType ID: $PackageId - Name: $($packageProperties.Name)] does not have the 'Copy the content in this package to a package share on distribution points' option enabled." | Green
    }
}

Write-Output "Checking for actions that require the network access account (NAA)"
Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "
Write-Output "Checking distribution points..."

# Get all distribution points
$distributionPoints = Get-CMDistributionPoint
# Loop through each distribution point to check if multicast is enabled
foreach ($dp in $distributionPoints) {
    if ($dp.EnableMulticast) {
        Write-Output "Distribution Point: $($dp.SiteCode) - $($dp.ServerName) has multicast enabled." | Red
    } else {
        Write-Output "Distribution Point: $($dp.SiteCode) - $($dp.ServerName) does not have multicast enabled." | Green
    }
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "

Write-Output "Checking packages..."

# Get all packages
$packages = Get-CMPackage -Fast
# Loop through each package to check the "Copy the content in this package to a package share on distribution points" option
foreach ($package in $packages) {
    Check-PackageShareOption -PackageType "Package" -PackageId $package.PackageID
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "
Write-Output "Checking operating system images..."

# Get all operating system images
$osImages = Get-CMOperatingSystemImage
foreach ($osImage in $osImages) {
    Check-PackageShareOption -PackageType "ImagePackage" -PackageId $osImage.PackageID
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "
Write-Output "Checking operating system upgrade packages..."

# Get all operating system upgrade packages
$osUpgImages = Get-CMOperatingSystemInstaller
foreach ($osUpgImage in $osUpgImages) {
    Check-PackageShareOption -PackageType "OperatingSystemInstallPackage" -PackageId $osUpgImage.PackageID
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "
Write-Output "Checking boot images..."

# Get all boot images
$bootImages = Get-CMBootImage
foreach ($bootImage in $bootImages) {
    Check-PackageShareOption -PackageType "BootImagePackage" -PackageId $bootImage.PackageID
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "
Write-Output "Checking driver packages..."

# Get all driver packages
$driverPackages = Get-CMDriverPackage -Fast
foreach ($driverPackage in $driverPackages) {
    Check-PackageShareOption -PackageType "DriverPackage" -PackageId $driverPackage.PackageID
}

Write-Output " "
Write-Output "-----------------------------------------------"
Write-Output " "

Write-Output "Checking task sequences..."
# Get all task sequences
$taskSequences = Get-CMTaskSequence -Fast
# Loop through each task sequence
foreach ($ts in $taskSequences) {
    Write-Output "Task Sequence [$($ts.Name)]:"

    # Task Sequence properties setting to Run another program first
    $dependentProgram = $false
    $dependentProgram = $ts.DependentProgram
    if ($dependentProgram) {
        Write-Output "Task Sequence properties setting to Run another program first is enabled." | Red
    } else {
        Write-Output "Task Sequence properties setting to Run another program first is disabled." | Green
    }

    # Request State Store task sequence step(s)
    $requestStateStoreAction = $false
    $requestStateStoreAction = $ts | Get-CMTaskSequenceStep | Where { $_.SmsProviderObjectPath -eq 'SMS_TaskSequence_RequestStateStoreAction' }
    if ($requestStateStoreAction) {
        Write-Output "Found Request State Store task sequence step(s)." | Red
    } else {
        Write-Output "Did not find Request State Store task sequence step(s)." | Green
    }

    # Check if the option "Access content directly from the distribution point" is enabled on the Apply Operating System step
    $steps = $ts | Get-CMTSStepApplyOperatingSystem
    foreach ($step in $steps) {
        if ($step.RunfromNet) {
            Write-Output "Step [$($step.Name)] with 'Access content directly from the distribution point' enabled." | Red
        } else {
            Write-Output "Step [$($step.Name)] with 'Access content directly from the distribution point' disabled." | Green
        }
    }
    
    # Check task sequence deployment option to Access content directly from a distribution point when needed by the running task sequence
    $taskSequenceDeployments = $ts | Get-CMTaskSequenceDeployment -Fast
    foreach ($taskSequenceDeployment in $taskSequenceDeployments) {
        # Check the RemoteClientFlags attribute
        $remoteClientFlags = $taskSequenceDeployment.RemoteClientFlags
        # Define the flag value for accessing content directly from a distribution point
        $accessContentDirectlyFlag = 0x00000008
        if ($remoteClientFlags -band $accessContentDirectlyFlag) {
            Write-Output "Deployment [$($taskSequenceDeployment.AdvertisementName)] is configured to access content directly from a distribution point." | Red
        } else {
            Write-Output "Deployment [$($taskSequenceDeployment.AdvertisementName)] is not configured to access content directly from a distribution point." | Green
        }
    }
    
    Write-Output " "
}

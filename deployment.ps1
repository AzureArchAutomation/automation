#############
##FUNCTIONS##
#############

#------------------------------------------------------------------------------

function Select-FromGrid {
    param ([object]$InputObject, [string]$Title)
    $InputObject | 
        Out-GridView `
            -OutputMode Single `
            -Title "Please select $Title" | 
            ForEach-Object {
                $selectedItem = $PSItem
            } 
    Return $selectedItem
}

#------------------------------------------------------------------------------

function Read-HostValidated {
    param ([string]$Prompt, [string]$Pattern, [string]$Default, [bool]$BreakOnEnter, [bool]$AsSecureString)

    $tryAgain = ""

    if ($Default) {
        $Prompt = $Prompt + " ([Enter] to accept default of '$Default')"
    }

    if ($AsSecureString) {
        $params = @{
            AsSecureString = $true
        }
    }
    else {
        $params = @{
            AsSecureString = $false
        }
    }

    do {
        $prompt2 = $tryAgain + $Prompt + ": "
        Write-Host $prompt2 -ForegroundColor Yellow -NoNewline
        $retval = Read-Host @params
        if ([string]::IsNullOrWhiteSpace($retval)) {
            if ($BreakOnEnter -eq $true -or $Default) {
                Break
            }
        }
        $tryAgain = "Try again... "
    }
    while ($retval -notmatch $Pattern)

   if ($Default -and $retval.Length -eq 0) {
        $retval = $Default
    }

    Write-Host ""

    Return $retval
}
#------------------------------------------------------------------------------
#####################
##Import Build File##
#####################

Write-Host "Gathering available deployment files from file share" -ForegroundColor Green
#Browsing file
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
$FileBrowser.filter = "csv (*.csv)| *.csv"
[void]$FileBrowser.ShowDialog()
$FileBrowser.FileName

$build = Import-Csv -Path $FileBrowser.FileName


#######################################
## login to Azure cccount           # #
#######################################

if (-not $connect) {
    Write-Host "Connect to Azure..." -ForegroundColor Green
    $connect = Connect-AzAccount
    if (-not $connect) {
        throw "No connection to Azure. Aborting."
    }
}

Write-Host "Connected to Azure as:" -ForegroundColor Green
$connect | Out-Host

# Prompt user to select subscription for deployment
Write-Host "Select subscription for deployment..." -ForegroundColor Yellow
$selectedSubscription = Select-FromGrid `
    -InputObject (Get-AzSubscription | Select-Object Name, SubscriptionId) `
    -Title "Subscription"

if (-not $selectedSubscription) {
    throw "No subscription selected. Aborting."
}
else {
    Write-Host "Selected subscription:" -ForegroundColor Green
    $selectedSubscription | Out-Host
}

#######################################
# set Azure context                   #
#######################################
Write-Host "Setting context to $($selectedSubscription.SubscriptionId)..." -ForegroundColor Green
$azContext = Set-AzContext -Subscription $selectedSubscription.SubscriptionId
if (-not $azContext) {
    throw "Set context failed. Aborting."
}
else {
    Write-Host "Deployment context:" -ForegroundColor Green
    $azContext | Out-Host
}

#############################
##Set Username and Password##
#############################

$localVmAdminUserName = Read-HostValidated `
   -Prompt "Enter the local admin username for VMs" `
   -Pattern "^[a-z0-9-_]{1,256}$"

$localVmAdminPassword = Read-HostValidated `
   -Prompt "Enter the local admin password for VMs" `
   -Pattern "^.{14,32}$" `
   -AsSecureString $true
Write-Host "[hidden]`n"


#####!DEPLOYMENTS!#####

##########################
##Deploy Resource Groups##
##########################

ForEach ($builds in $build){
    
    New-AzDeployment -Name test -rgName $builds.ResourceGroup  -Location $builds.Location -rgLocation $builds.Location  -TemplateFile C:\temp\deploy_resource_group.json

    }


############################
##Deploy Availability Sets##
############################

ForEach ($builds in $build){
    
    New-AzDeployment -Name test -rgname $builds.ResourceGroup -rgLocation $builds.Location -Location $builds.Location -asName $builds.AvailabilitySet -TemplateFile C:\temp\deploy_availability_set.json

    }


#############################
##Deploy Network Interfaces##
#############################

ForEach ($builds in $build){
    
    New-AzDeployment -Name test -rgname $builds.ResourceGroup -rgLocation $builds.Location -subnetid $builds.subnetid -vmname $builds.servername -Location $builds.Location -TemplateFile C:\temp\deploy_network_interface.json

    }
     
###########################
##Deploy Virtual Machines##
###########################    

ForEach ($builds in $build){    
    
    New-AzResourceGroupDeployment -name test -ResourceGroupNameFromTemplate $builds.ResourceGroup -ResourceGroupName $builds.ResourceGroup -rgname $builds.ResourceGroup -publisher $builds.publisher -offer $builds.offer -sku $builds.sku -subnetID $builds.subNetID -rgLocation $builds.Location -vmname $builds.servername -adminUsername $localVmAdminUserName -adminpassword $localVmAdminPassword -size $builds.size -asname $builds.AvailabilitySet -TemplateFile 'C:\temp\deployvm.json'

     }
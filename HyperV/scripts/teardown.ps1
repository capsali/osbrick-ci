# Loading config

. "C:\OpenStack\osbrick-ci\HyperV\scripts\config.ps1"
. "C:\OpenStack\osbrick-ci\HyperV\scripts\utils.ps1"
. "C:\OpenStack\osbrick-ci\HyperV\scripts\iscsi_utils.ps1"

# end Loading config

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping Nova and Neutron services"
Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

Write-Host "Stopping any python processes that might have been left running"
Stop-Process -Name python -Force
Stop-Process -Name nova-compute -Force
Stop-Process -Name neutron-hyperv-agent -Force

Write-Host "Checking that services and processes have been succesfully stopped"
if (Get-Process -Name nova-compute){
    Throw "Nova is still running on this host"
}else {
    Write-Host "No nova process running."
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}else {
    Write-Host "No neutron process running"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}else {
    Write-Host "No python processes left running"
}

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}else {
    Write-Host "Nova service is in Stopped state."
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}else {
    Write-Host "Neutron service is in Stopped state"
}



Write-Host "Clearing any VMs that might have been left."
Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
Remove-VM * -Force

cleanup_iscsi_targets

if (Get-SMBShare -Name $cinderShareName -ErrorAction SilentlyContinue)
{
    log_message "Removing cinder volume share."
    Remove-SMBShare -Name $cinderShareName -Force
}

if (Test-Path -Path $volumeShareDir)
{
    log_message "Removing cinder volume share dir: $volumeShareDir"
    Remove-Item -Recurse -Force $volumeShareDir
}

if (Test-Path -Path $$cinderMntPoint)
{
    log_message "Removing cinder share mount point: $$cinderMntPoint"
    Remove-Item -Recurse -Force $$cinderMntPoint
}

Write-Host "Cleaning the build folder."
Remove-Item -Recurse -Force $buildDir\*
Write-Host "Cleaning the virtualenv folder."
Remove-Item -Recurse -Force $virtualenv
Write-Host "Cleaning the logs folder."
Remove-Item -Recurse -Force $openstackDir\Logs\*
Write-Host "Cleaning the config folder."
Remove-Item -Recurse -Force $openstackDir\etc\*
Write-Host "Cleaning the Instances folder."
Remove-Item -Recurse -Force $openstackDir\Instances\*
Write-Host "Cleaning eventlog"
cleareventlog
Write-Host "Cleaning up process finished."

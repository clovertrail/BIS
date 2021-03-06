#############################################################
#
# LegacyToVMBusNIC.ps1
#
# Description:
#    Remove a Legacy NIC and add a VMBus NIC to a VM, while
#    keeping the same MAC address.  This way, the VM will
#    be assigned the same IP address by the DHCP server.
#
# Test Params:
#    MAC=001122334455
#
#############################################################
param ([String] $vmName, [String] $hvServer, [String] $testParams)


#############################################################
#
# Main script body
#
#############################################################

$retVal = $False

#
# Check the required input args are present
#
if (-not $vmName)
{
    "Error: null vmName argument"
    return $False
}

if (-not $hvServer)
{
    "Error: null hvServer argument"
    return $False
}

if (-not $testParams)
{
    "Error: null testParams argument"
    return $False
}

#
# Display some info for debugging purposes
#
"VM name     : ${vmName}"
"Server      : ${hvServer}"
"Test params : ${testParams}"

#
# Parse the test params
#
$MAC = $null

$params = $testParams.Split(';')
foreach ($p in $params)
{
    if ($p.Trim().Length -eq 0)
    {
        continue
    }

    $tokens = $p.Trim().Split('=')
    
    if ($tokens.Length -ne 2)
    {
	    "Warn : test parameter '$p' appears malformed, ignoring"
         continue
    }

    if ($tokens[0].Trim() -eq "MAC")
    {
        $mac = $tokens[1].Trim().ToLower()
    }
}

if (-not $MAC)
{
    "Error: MAC test parameter is missing"
    return $False
}

#
# Load the HyperVLib version 2 modules
#
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
}

#
# Find the Legacy NIC with the specific MAC address
#
$legacyNICs = @(Get-VmNic -vm $vmName -server $hvServer -Legacy)
if (-not $legacyNICs)
{
    "Error: VM does not have any Legacy NICs"
    return $False
}

$legacyNIC = $null
$switchName = $null

foreach ($nic in $legacyNICs)
{
    if ($nic.Address -eq $MAC)
    {
        $legacyNIC = $nic
        $switchName = $nic.SwitchName.Trim()
        break
    }
}

if (-not $legacyNic)
{
    "Error: Unable to find NIC with MAC=${MAC}"
    return $False
}

if (-not $switchName -or $switchName.Length -eq 0)
{
    "Error: switch not found, or has a name of zero characters"
    return $False
}

#
# Remove the Legacy NIC
#
$sts = ($legacyNic | Remove-VMNic -VM $vmName -Server $hvServer -Force)
if (-not $sts -or $sts.ToString() -ne "OK")
{
    "Error: Unable to remove the Legacy NIC from the VM"
    return $False
}

#
# Add the VMBus NIC
#
$newNic = Add-VmNic -vm $vmName -VirtualSwitch $switchName -MAC $MAC -Server $hvServer -Force
if ($newNic)
{
    $retVal = $True
}
else
{
    "Error: Unable to add VMBus NIC"
}

return $retVal

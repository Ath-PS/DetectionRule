# Inline software requirements block
$Config = @{
    Software = @(
        @{ Name = 'Name 1';   MinVersion = 'Version 1' }
        @{ Name = 'Name 2';   MinVersion = 'Version 2' }
    )
}

$Software = $Config.Software

# Normalize and map to arrays
[string[]]$RequiredSoftwareNames = @()
[string[]]$RequiredSoftwareMinVersions = @()
foreach ($item in $Software) {
    $name = [string]$item['Name']
    $ver  = [string]$item['MinVersion']
    if ($null -ne $name) { $name = $name.Trim() }
    if ($null -ne $ver)  { $ver  = $ver.Trim() }
    $RequiredSoftwareNames += $name
    $RequiredSoftwareMinVersions += $ver
}

# Ensure arrays are trimmed
$RequiredSoftwareNames = @($RequiredSoftwareNames | ForEach-Object { if ($null -ne $_) { $_.Trim() } else { $_ } })
$RequiredSoftwareMinVersions = @($RequiredSoftwareMinVersions | ForEach-Object { if ($null -ne $_) { $_.Trim() } else { $_ } })

$ErrorActionPreference = 'SilentlyContinue'
$DetectionSuccessful = $Null
$InstalledSoftwareTable = $Null

# Registry uninstall paths
[string[]]$RegistryUninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# Quick helper to try-parse [version]
function Convert-ToVersionOrNull {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $v = $null
    if ([version]::TryParse($s.Trim(), [ref]$v)) { return $v }
    return $null
}

if (($RequiredSoftwareNames.Count) -eq ($RequiredSoftwareMinVersions.Count)) {
    foreach ($RegistryPath in $RegistryUninstallPaths) {
        $RegistryFolders = (Get-ChildItem $RegistryPath -Name -ErrorAction SilentlyContinue)
        $InstalledSoftwareTable += foreach ($Folder in $RegistryFolders) { (Get-ItemProperty -Path (Join-Path -Path $RegistryPath -ChildPath $Folder) -ErrorAction SilentlyContinue) | Select-Object DisplayName, DisplayVersion }
    }

    for ($G = 0; $G -lt ($RequiredSoftwareNames.Count); $G++) {
        $RequiredSoftwareNameItem = $RequiredSoftwareNames[$G]
        $RequiredSoftwareVersionItem = Convert-ToVersionOrNull -s $RequiredSoftwareMinVersions[$G]
        $RequiredSoftwareNameItemExists = $False

        foreach ($Record in $InstalledSoftwareTable) {
            $SoftwareNameInstalledRaw = [string]$Record.DisplayName
            $SoftwareNameInstalled = if ($null -ne $SoftwareNameInstalledRaw) { $SoftwareNameInstalledRaw.Trim() } else { $null }
            $SoftwareNameInstalledNorm = if ($SoftwareNameInstalled) { $SoftwareNameInstalled.ToLowerInvariant() } else { $null }

            $SoftwareVersionInstalledRaw = [string]$Record.DisplayVersion
            $SoftwareVersionInstalled = Convert-ToVersionOrNull -s $SoftwareVersionInstalledRaw

            $RequiredNameNorm = if ($null -ne $RequiredSoftwareNameItem) { $RequiredSoftwareNameItem.Trim().ToLowerInvariant() } else { $null }
            if ($SoftwareNameInstalledNorm -eq $RequiredNameNorm) {
                $RequiredSoftwareNameItemExists = $True
                if (($SoftwareVersionInstalled -ne $null) -and ($RequiredSoftwareVersionItem -ne $null) -and ($SoftwareVersionInstalled -ge $RequiredSoftwareVersionItem) -and (!($DetectionSuccessful -eq $False))) {
                    $DetectionSuccessful = $True
                } else { $DetectionSuccessful = $False }
                break
            }
        }

        if ($RequiredSoftwareNameItemExists -eq $False) { $DetectionSuccessful = $False; break }
    }
} else { $DetectionSuccessful = $False }

if ($DetectionSuccessful) {
    Write-Output "Installed"
    exit 0
} else { Write-Output "NotInstalled"; exit 1 }

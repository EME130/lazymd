# lazy-md installer for Windows
# Usage: irm https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-windows.ps1 | iex

$ErrorActionPreference = "Stop"

$Repo = "EME130/lazymd"
$Binary = "lazy-md"
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "$env:LOCALAPPDATA\lazy-md" }

function Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Err($msg) { Write-Host "Error: $msg" -ForegroundColor Red; exit 1 }

# Detect architecture
$Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
switch ($Arch) {
    "X64"   { $ZigArch = "x86_64" }
    "Arm64" { $ZigArch = "aarch64" }
    default { Err "Unsupported architecture: $Arch. Supported: X64, Arm64" }
}

$Asset = "$Binary-windows-$ZigArch.zip"

Info "Installing $Binary for Windows $ZigArch..."

# Get latest release tag
try {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "lazy-md-installer" }
    $Latest = $Release.tag_name
} catch {
    Err "Could not determine latest release. Check https://github.com/$Repo/releases"
}
Info "Latest release: $Latest"

# Download
$DownloadUrl = "https://github.com/$Repo/releases/download/$Latest/$Asset"
$TmpDir = Join-Path $env:TEMP "lazy-md-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

Info "Downloading $DownloadUrl..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile "$TmpDir\$Asset" -UseBasicParsing
} catch {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Err "Download failed. Asset '$Asset' may not exist for this release.`nTry building from source instead: https://github.com/$Repo#install"
}

# Extract
Info "Extracting..."
Expand-Archive -Path "$TmpDir\$Asset" -DestinationPath $TmpDir -Force

# Install
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Copy-Item "$TmpDir\$Binary.exe" "$InstallDir\$Binary.exe" -Force

# Add to PATH if not already there
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Info "Adding $InstallDir to user PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
}

# Cleanup
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Info "Installed $Binary to $InstallDir\$Binary.exe"
Info "Done! Restart your terminal, then run '$Binary' to get started."

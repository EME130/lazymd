# Installing lazy-md on Windows

## One-liner (PowerShell)

Run in PowerShell (as Administrator is **not** required):

```powershell
irm https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-windows.ps1 | iex
```

This downloads the latest pre-built binary and installs it to `%LOCALAPPDATA%\lazy-md`, then adds it to your user PATH.

To install to a custom directory:

```powershell
$env:INSTALL_DIR = "C:\Tools\lazy-md"; irm https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-windows.ps1 | iex
```

## Manual install (pre-built binary)

1. Go to the [Releases](https://github.com/EME130/lazymd/releases) page
2. Download `lazy-md-windows-x86_64.zip`
3. Extract the zip file
4. Move `lazy-md.exe` to a directory in your PATH, or add its location to PATH:

```powershell
# Create install directory
mkdir "$env:LOCALAPPDATA\lazy-md" -Force

# Copy binary
Copy-Item lazy-md.exe "$env:LOCALAPPDATA\lazy-md\"

# Add to user PATH (persistent)
$path = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$path;$env:LOCALAPPDATA\lazy-md", "User")
```

Restart your terminal after modifying PATH.

## Build from source

### Prerequisites

Install Zig 0.15.1 or later:

**Option 1: winget**

```powershell
winget install zig.zig
```

**Option 2: Scoop**

```powershell
scoop install zig
```

**Option 3: Chocolatey**

```powershell
choco install zig
```

**Option 4: Manual download**

Download from [ziglang.org/download](https://ziglang.org/download/), extract, and add to PATH.

Verify the installation:

```powershell
zig version
# Should output 0.15.1 or later
```

### Build

```powershell
git clone https://github.com/EME130/lazymd.git
cd lazymd
zig build
```

The binary is at `zig-out\bin\lazy-md.exe`. Add it to your PATH or copy it to an existing PATH directory.

## Verify

```powershell
lazy-md --version
```

## Uninstall

```powershell
# Remove binary
Remove-Item "$env:LOCALAPPDATA\lazy-md" -Recurse -Force

# Remove from PATH (open System Properties > Environment Variables > edit user Path)
```

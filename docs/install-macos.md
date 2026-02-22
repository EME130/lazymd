# Installing lazy-md on macOS

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-macos.sh | bash
```

This downloads the latest pre-built binary and installs it to `/usr/local/bin`.

To install to a custom directory:

```bash
INSTALL_DIR=~/.local/bin curl -fsSL https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-macos.sh | bash
```

## Manual install (pre-built binary)

1. Go to the [Releases](https://github.com/EME130/lazymd/releases) page
2. Download the tarball for your Mac:
   - `lazy-md-macos-aarch64.tar.gz` for Apple Silicon (M1/M2/M3/M4)
   - `lazy-md-macos-x86_64.tar.gz` for Intel Macs
3. Extract and install:

```bash
tar -xzf lazy-md-macos-aarch64.tar.gz
sudo cp lazy-md /usr/local/bin/
```

If macOS Gatekeeper blocks the binary, remove the quarantine attribute:

```bash
xattr -d com.apple.quarantine /usr/local/bin/lazy-md
```

## Build from source

### Prerequisites

Install Zig 0.15.1 or later:

```bash
# Option 1: Homebrew
brew install zig

# Option 2: From ziglang.org
# Download from https://ziglang.org/download/ and extract to your PATH
```

Verify the installation:

```bash
zig version
# Should output 0.15.1 or later
```

### Build

```bash
git clone https://github.com/EME130/lazymd.git
cd lazymd
zig build
```

The binary is at `zig-out/bin/lazy-md`. Copy it to your PATH:

```bash
sudo cp zig-out/bin/lazy-md /usr/local/bin/
```

## Verify

```bash
lazy-md --version
```

## Uninstall

```bash
sudo rm /usr/local/bin/lazy-md
```

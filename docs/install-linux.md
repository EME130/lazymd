# Installing lazy-md on Linux

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-linux.sh | bash
```

This downloads the latest pre-built binary and installs it to `/usr/local/bin`.

To install to a custom directory:

```bash
INSTALL_DIR=~/.local/bin curl -fsSL https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-linux.sh | bash
```

## Manual install (pre-built binary)

1. Go to the [Releases](https://github.com/EME130/lazymd/releases) page
2. Download the tarball for your architecture:
   - `lazy-md-linux-x86_64.tar.gz` for Intel/AMD 64-bit
   - `lazy-md-linux-aarch64.tar.gz` for ARM 64-bit
3. Extract and install:

```bash
tar -xzf lazy-md-linux-x86_64.tar.gz
sudo cp lazy-md /usr/local/bin/
```

## Build from source

### Prerequisites

Install Zig 0.15.1 or later:

```bash
# Option 1: From ziglang.org
# Download from https://ziglang.org/download/ and extract to your PATH

# Option 2: Using snap
sudo snap install zig --classic --beta

# Option 3: Using your package manager (if available)
# Arch Linux
sudo pacman -S zig

# Fedora (via COPR)
sudo dnf copr enable sentry/zig
sudo dnf install zig
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

Or install to your local bin:

```bash
mkdir -p ~/.local/bin
cp zig-out/bin/lazy-md ~/.local/bin/
```

Make sure `~/.local/bin` is in your `PATH` (add to `~/.bashrc` or `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Verify

```bash
lazy-md --version
```

## Uninstall

```bash
sudo rm /usr/local/bin/lazy-md
# or
rm ~/.local/bin/lazy-md
```

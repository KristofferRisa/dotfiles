# Coder Setup Guide

This guide explains how to use your dotfiles with [Coder](https://coder.com/) for cloud development environments.

## Overview

The dotfiles repository uses a **two-tier approach** for Coder:

1. **Docker Image**: Pre-installs all dependencies (git, neovim, tmux, bun, bitwarden-cli, etc.)
2. **Startup Script**: Clones dotfiles and links them via GNU Stow

This gives you:
- ⚡ **Fast startup** (~2-5 seconds)
- 🛡️ **Reliability** - tested, cached image
- 🔄 **Flexibility** - update dotfiles without rebuilding images

---

## Quick Start

### Option 1: Use Pre-Built Image (Recommended)

If you've already built and pushed the Docker image:

1. Copy `coder-example.tf` to your Coder templates directory
2. Update the `docker_image` variable to your image URL
3. Create a workspace using the template

### Option 2: Build Your Own Image

#### Step 1: Build the Docker Image

```bash
# Clone this repository (if not already)
git clone https://github.com/kristofferrisa/dotfiles.git
cd dotfiles

# Build the Docker image
docker build -t kristofferrisa/coder-env:latest -f Dockerfile.coder .
```

#### Step 2: Push to Container Registry

**Using Docker Hub:**
```bash
docker login
docker push kristofferrisa/coder-env:latest
```

**Using GitHub Container Registry:**
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Tag and push
docker tag kristofferrisa/coder-env:latest ghcr.io/kristofferrisa/coder-env:latest
docker push ghcr.io/kristofferrisa/coder-env:latest
```

#### Step 3: Configure Coder Template

1. Copy `coder-example.tf` to your Coder templates directory
2. Update the `docker_image` variable:
   ```hcl
   variable "docker_image" {
     default = "ghcr.io/kristofferrisa/coder-env:latest"
   }
   ```
3. Push the template to Coder:
   ```bash
   coder templates push <template-name> coder-example.tf
   ```

#### Step 4: Create Workspace

```bash
coder create my-workspace --template=<template-name>
```

---

## What's Included in the Image

The Docker image (`Dockerfile.coder`) includes:

### Core Tools
- **git** - Version control
- **curl/wget** - Network tools
- **neovim** - Text editor
- **tmux** - Terminal multiplexer
- **zsh** - Shell (with Oh-My-Zsh pre-installed)
- **stow** - GNU Stow for dotfiles management

### Development Tools
- **bun** - Fast JavaScript runtime
- **bitwarden-cli** - Password/secret management
- **jq** - JSON processor
- **ripgrep** - Fast grep alternative
- **fzf** - Fuzzy finder
- **build-essential** - Compilers and build tools

### Pre-configured
- Oh-My-Zsh installed
- Powerlevel10k theme
- Non-root user (`coder`)
- sudo access configured

---

## Dotfiles Installation Process

When a workspace starts, the `startup_script` in the Terraform template:

1. **Clones dotfiles** from GitHub (if not present)
2. **Updates dotfiles** (if already cloned)
3. **Runs install.sh** with `--coder` flag
4. **Links configurations** via GNU Stow

The `--coder` flag tells `install.sh` to:
- Skip package installation (already in image)
- Only link dotfiles
- Install LazyVim (if not present)

---

## Customizing Your Setup

### Adding More Tools to the Image

Edit `Dockerfile.coder` and add packages:

```dockerfile
RUN apt-get update && apt-get install -y \
    # ... existing packages ...
    nodejs \
    npm \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*
```

Rebuild and push:
```bash
docker build -t kristofferrisa/coder-env:latest -f Dockerfile.coder .
docker push kristofferrisa/coder-env:latest
```

### Configuring Git Credentials

Edit the `startup_script` in `coder-example.tf`:

```bash
# Configure git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Using Bitwarden CLI in Coder

The Bitwarden CLI is pre-installed. To use it:

1. **Login** (first time):
   ```bash
   bw login
   ```

2. **Unlock vault** (each session):
   ```bash
   export BW_SESSION=$(bw unlock --raw)
   ```

3. **Retrieve secrets**:
   ```bash
   bw get password github.com
   ```

### Automating Bitwarden Login

Add to `startup_script` in `coder-example.tf`:

```bash
# Unlock Bitwarden vault (requires BW_PASSWORD env var)
if [ -n "$BW_PASSWORD" ]; then
  export BW_SESSION=$(echo $BW_PASSWORD | bw unlock --raw)
  echo "🔐 Bitwarden vault unlocked"
fi
```

Then set `BW_PASSWORD` as a Coder secret:
```bash
coder secrets create BW_PASSWORD
```

---

## Workspace Configuration

### CPU and Memory Limits

Edit `coder-example.tf`:

```hcl
resource "docker_container" "workspace" {
  cpu_shares = 2048      # Increase CPU allocation
  memory     = 8192      # Increase memory to 8GB
  # ...
}
```

### Exposing Applications

To expose a web app running in your workspace:

```hcl
resource "coder_app" "webapp" {
  agent_id     = coder_agent.main.id
  slug         = "webapp"
  display_name = "My Web App"
  url          = "http://localhost:3000"
  icon         = "/icon/application.svg"
}
```

### Adding VS Code in Browser

Uncomment the `code-server` app in `coder-example.tf`:

```hcl
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
}
```

Then install code-server in your Dockerfile:
```dockerfile
RUN curl -fsSL https://code-server.dev/install.sh | sh
```

---

## CI/CD: Auto-Building Docker Images

Create `.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    paths:
      - 'Dockerfile.coder'
      - '.github/workflows/docker-build.yml'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.coder
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/coder-env:latest
            ghcr.io/${{ github.repository_owner }}/coder-env:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Troubleshooting

### Workspace Fails to Start

**Check logs:**
```bash
coder logs my-workspace
```

**Common issues:**
- Docker image not found (check registry URL)
- Network issues cloning dotfiles (check GitHub access)
- Stow conflicts (existing files in ~/.config)

### Dotfiles Not Linking

**Manual fix:**
```bash
cd ~/dotfiles
./install.sh --coder --verbose
```

**Stow conflicts:**
```bash
# Backup existing configs
mv ~/.config ~/.config.backup

# Re-run dotfiles install
cd ~/dotfiles
./install.sh --coder
```

### Slow Workspace Startup

**Diagnosis:**
- Check if using pre-built image (should be ~2-5s)
- If using `./install.sh` without `--coder`, it will reinstall packages (~30s)

**Fix:** Ensure `startup_script` uses `--coder` flag:
```bash
bash ./install.sh --coder
```

### Bitwarden CLI Not Working

**Check installation:**
```bash
bw --version
```

**Manual install:**
```bash
# Download latest
BW_VERSION=$(curl -s https://api.github.com/repos/bitwarden/clients/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/cli-v//')
wget "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip"
unzip "bw-linux-${BW_VERSION}.zip"
sudo mv bw /usr/local/bin/
chmod +x /usr/local/bin/bw
```

---

## Advanced: Multi-Platform Support

To build for both AMD64 and ARM64:

```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t kristofferrisa/coder-env:latest \
  -f Dockerfile.coder \
  --push \
  .
```

---

## Best Practices

1. **Pin versions** in Dockerfile for reproducibility
2. **Use image tags** (not just `latest`) for production
3. **Keep dotfiles public** or use private repo with SSH keys
4. **Test locally** before deploying to Coder
5. **Monitor image size** - keep under 1GB if possible
6. **Use CI/CD** to auto-build images on changes
7. **Document custom changes** in this file

---

## Resources

- [Coder Documentation](https://coder.com/docs)
- [Coder Templates](https://github.com/coder/coder/tree/main/examples/templates)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)

---

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Coder workspace logs: `coder logs <workspace>`
3. Test dotfiles locally: `./install.sh --coder`
4. Open an issue in the dotfiles repository

# Example Coder Terraform Template
# This template creates a workspace using the custom Docker image with pre-installed dependencies

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Variables for customization
variable "dotfiles_repo" {
  description = "Git repository URL for dotfiles"
  type        = string
  default     = "https://github.com/kristofferrisa/dotfiles.git"
}

variable "docker_image" {
  description = "Docker image to use for the workspace"
  type        = string
  # Change this to your image registry and tag
  # Example: "ghcr.io/kristofferrisa/dotfiles:latest"
  default     = "kristofferrisa/coder-env:latest"
}

# Coder agent configuration
data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  arch           = data.coder_workspace.me.access_url != "" ? "amd64" : null
  os             = "linux"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    echo "🚀 Starting workspace initialization..."

    # Clone or update dotfiles repository
    DOTFILES_DIR="$HOME/dotfiles"
    if [ ! -d "$DOTFILES_DIR" ]; then
      echo "📦 Cloning dotfiles repository..."
      git clone --recurse-submodules ${var.dotfiles_repo} "$DOTFILES_DIR"
    else
      echo "🔄 Updating dotfiles repository..."
      cd "$DOTFILES_DIR"
      git pull --recurse-submodules
    fi

    # Run dotfiles installation in Coder mode (skip package installation)
    echo "🔗 Linking dotfiles..."
    cd "$DOTFILES_DIR"
    bash ./install.sh --coder

    # Optional: Configure git (adjust with your details)
    # git config --global user.name "Your Name"
    # git config --global user.email "your.email@example.com"

    # Optional: Bitwarden CLI login (if needed)
    # echo "🔐 Bitwarden CLI is available. Run 'bw login' to authenticate."

    echo "✅ Workspace initialization complete!"
  EOT

  # Environment variables (add your own as needed)
  env = {
    GIT_AUTHOR_NAME     = data.coder_workspace.me.owner
    GIT_COMMITTER_NAME  = data.coder_workspace.me.owner
    GIT_AUTHOR_EMAIL    = data.coder_workspace.me.owner_email
    GIT_COMMITTER_EMAIL = data.coder_workspace.me.owner_email
  }

  # Metadata for display in Coder UI
  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    # uses the coder stat command
    script   = "coder stat cpu"
    interval = 10
    timeout  = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script   = "coder stat mem"
    interval = 10
    timeout  = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script   = "df -h | awk '$6==\"/\" {print $5}'"
    interval = 60
    timeout  = 1
  }
}

# Docker container resource
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = var.docker_image
  name  = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"

  # CPU and memory limits (adjust as needed)
  cpu_shares = 1024
  memory     = 4096

  # Host configuration
  hostname = data.coder_workspace.me.name

  # Inject Coder agent
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  # Volume mounts (optional)
  # volumes {
  #   container_path = "/home/coder/workspace"
  #   host_path      = "/path/on/host"
  # }

  # Keep container running
  command = ["sh", "-c", coder_agent.main.init_script]
}

# Optional: Add a parameter for workspace CPU cores
# resource "coder_parameter" "cpu_cores" {
#   name         = "cpu_cores"
#   display_name = "CPU Cores"
#   description  = "Number of CPU cores to allocate"
#   type         = "number"
#   default      = "2"
#   mutable      = true
# }

# Optional: Add a parameter for workspace memory
# resource "coder_parameter" "memory_gb" {
#   name         = "memory_gb"
#   display_name = "Memory (GB)"
#   description  = "Amount of memory to allocate in GB"
#   type         = "number"
#   default      = "4"
#   mutable      = true
# }

# Example: Expose a web application
# resource "coder_app" "webapp" {
#   agent_id     = coder_agent.main.id
#   slug         = "webapp"
#   display_name = "Web Application"
#   url          = "http://localhost:3000"
#   icon         = "https://cdn.icon-icons.com/icons2/2699/PNG/512/nodejs_logo_icon_169955.png"
# }

# Example: VS Code in browser
# resource "coder_app" "code-server" {
#   agent_id     = coder_agent.main.id
#   slug         = "code-server"
#   display_name = "VS Code"
#   url          = "http://localhost:13337"
#   icon         = "/icon/code.svg"
#   subdomain    = false
#   share        = "owner"
# }

#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

NVIM_INSTALL_DIR="$HOME/.local/nvim"
NVIM_BIN="$HOME/.local/bin/nvim"

install_editors() {
    install_neovim
    install_neovim_config
    install_vscode
    log "Editors ready."
}

install_neovim() {
    step "Installing Neovim"

    local latest_tag
    latest_tag=$(get_latest_github_release "neovim/neovim")

    local installed_version="none"
    if command_exists nvim; then
        installed_version="$(nvim --version | head -1 | sed 's/NVIM //')"
    fi

    if [[ "$installed_version" == "$latest_tag" ]]; then
        log "Neovim $installed_version already up to date."
        return
    fi

    log "Installing Neovim $latest_tag (currently: $installed_version)..."

    local arch
    arch="$(uname -m)"
    local tarball
    case "$arch" in
        x86_64)  tarball="nvim-linux-x86_64.tar.gz" ;;
        aarch64) tarball="nvim-linux-arm64.tar.gz" ;;
        *)       error "No Neovim release for architecture: $arch" ;;
    esac

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    # neovim/neovim releases do not publish checksum files, so we cannot verify the
    # download. We trust the HTTPS connection and GitHub as the distribution channel.
    curl -fsSL \
        "https://github.com/neovim/neovim/releases/download/${latest_tag}/${tarball}" \
        -o "$tmp_dir/nvim.tar.gz"

    tar -xzf "$tmp_dir/nvim.tar.gz" -C "$tmp_dir"

    rm -rf "$NVIM_INSTALL_DIR"
    local extracted
    extracted=$(find "$tmp_dir" -maxdepth 1 -type d -name "nvim-*" | head -1)
    mv "$extracted" "$NVIM_INSTALL_DIR"

    mkdir -p "$HOME/.local/bin"
    ln -sf "$NVIM_INSTALL_DIR/bin/nvim" "$NVIM_BIN"
    trap - RETURN
    log "Neovim $latest_tag installed."
}

# Set NVIM_CONFIG_REPO to your fork of kickstart.nvim before running,
# or export it in your environment. Falls back to upstream if not set.
# Fork first at: https://github.com/nvim-lua/kickstart.nvim
install_neovim_config() {
    step "Installing Neovim config (kickstart.nvim)"

    local config_dir="$HOME/.config/nvim"
    local repo="${NVIM_CONFIG_REPO:-https://github.com/nvim-lua/kickstart.nvim.git}"

    if [[ -d "$config_dir/.git" ]]; then
        log "Neovim config already exists, pulling updates..."
        git -C "$config_dir" pull --quiet --rebase
        return
    fi

    if [[ -d "$config_dir" ]]; then
        warn "~/.config/nvim exists but is not a git repo — leaving it in place."
        warn "Remove it manually if you want kickstart.nvim installed there."
        return
    fi

    log "Cloning $repo → $config_dir"
    git clone --depth=1 "$repo" "$config_dir"

    log "Neovim config installed."
    log "On first launch, Neovim will install all plugins automatically."
    if [[ "$repo" == *"nvim-lua/kickstart.nvim"* ]]; then
        warn "You are using the upstream kickstart.nvim repo."
        warn "Fork it on GitHub and rerun with NVIM_CONFIG_REPO=https://github.com/YOURUSERNAME/kickstart.nvim.git"
        warn "so your config changes are versioned under your own account."
    fi
}

install_vscode() {
    step "Installing VS Code"

    # Verify fingerprint from: https://packages.microsoft.com/keys/microsoft.asc
    # Run the lookup command in ensure_apt_key's header comment, then set below.
    ensure_apt_key \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "/etc/apt/keyrings/packages.microsoft.gpg" \
        "BC528686B50D79E339D3721CEB3E94ADBE1229CF"

    # Remove legacy .list format if present (migrated to deb822 .sources)
    [[ -f /etc/apt/sources.list.d/vscode.list ]] && sudo rm /etc/apt/sources.list.d/vscode.list

    ensure_apt_source \
        "/etc/apt/sources.list.d/vscode.sources" \
        "Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /etc/apt/keyrings/packages.microsoft.gpg"

    if command_exists code; then
        log "VS Code already installed, upgrading..."
        apt_upgrade code
    else
        apt_install code
        log "VS Code installed."
    fi

    install_vscode_extensions
}

install_vscode_extensions() {
    step "Installing VS Code extensions"
    local -a extensions=(
        "golang.go"                          # Go
        "ms-azuretools.vscode-docker"        # Docker
        "hashicorp.terraform"                # Terraform
        "ms-kubernetes-tools.vscode-kubernetes-tools"
        "geequlim.godot-tools"               # Godot / GDScript (official godotengine org)
        "eamodio.gitlens"
        "ms-vscode-remote.remote-containers"
        "esbenp.prettier-vscode"
    )
    for ext in "${extensions[@]}"; do
        code --install-extension "$ext" --force 2>/dev/null && log "  $ext" || warn "  Failed to install $ext"
    done
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_editors; }

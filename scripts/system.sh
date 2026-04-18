#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_system() {
    require_ubuntu
    step "Installing base system packages"

    sudo mkdir -p /etc/apt/keyrings

    # Remove legacy vscode.list if vscode.sources already exists — apt rejects both together
    if [[ -f /etc/apt/sources.list.d/vscode.list ]] && [[ -f /etc/apt/sources.list.d/vscode.sources ]]; then
        sudo rm /etc/apt/sources.list.d/vscode.list
    fi

    # Remove stale hashicorp.list if it references a distro the repo doesn't support
    if [[ -f /etc/apt/sources.list.d/hashicorp.list ]]; then
        local hc_distro
        hc_distro=$(awk '{print $3}' /etc/apt/sources.list.d/hashicorp.list 2>/dev/null || true)
        if [[ -n "$hc_distro" ]] && ! curl -fsSL --head "https://apt.releases.hashicorp.com/dists/${hc_distro}/Release" &>/dev/null; then
            sudo rm /etc/apt/sources.list.d/hashicorp.list
        fi
    fi

    apt_update

    apt_install \
        curl \
        wget \
        git \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        unzip \
        zip \
        jq \
        tree \
        htop \
        xclip \
        fontconfig \
        ripgrep \
        fd-find \
        bat \
        fzf

    mkdir -p "$HOME/.local/bin"

    # Ubuntu ships these tools with different binary names
    if ! command_exists fd && command_exists fdfind; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
    if ! command_exists bat && command_exists batcat; then
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    fi

    log "Base system packages ready."
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_system; }

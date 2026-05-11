#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_terminal() {
    require_ubuntu
    install_ghostty
    configure_ghostty
    set_default_terminal
    log "Terminal setup complete."
}

install_ghostty() {
    step "Installing Ghostty"

    # Ghostty is in the official Ubuntu repos from 26.04 onwards (universe).
    # For older releases (e.g. 24.04) it is not packaged, so we add the community
    # PPA maintained by mkasberg as a fallback.
    if apt-cache show ghostty &>/dev/null 2>&1; then
        # Clean up PPA if it was added by an earlier bootstrap run and is no longer needed
        [[ ! -f /etc/apt/sources.list.d/ghostty.sources ]] || sudo rm /etc/apt/sources.list.d/ghostty.sources
        [[ ! -f /etc/apt/keyrings/ghostty.gpg ]]           || sudo rm /etc/apt/keyrings/ghostty.gpg
    else
        log "Ghostty not in official repos — adding community PPA..."

        # Verify fingerprint from: https://launchpad.net/~mkasberg/+archive/ubuntu/ghostty-ubuntu
        # Run the lookup command in ensure_apt_key's header comment, then set below.
        ensure_apt_key \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0721FDF5FECB88DC6920361657C8EF455CEAE491" \
            "/etc/apt/keyrings/ghostty.gpg" \
            "0721FDF5FECB88DC6920361657C8EF455CEAE491"

        local codename
        codename=$(lsb_release -cs)

        ensure_apt_source \
            "/etc/apt/sources.list.d/ghostty.sources" \
            "Types: deb
URIs: https://ppa.launchpadcontent.net/mkasberg/ghostty-ubuntu/ubuntu
Suites: ${codename}
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/ghostty.gpg"
    fi

    if command_exists ghostty; then
        log "Ghostty already installed, upgrading if available..."
        apt_upgrade ghostty
    else
        apt_install ghostty
        log "Ghostty installed."
    fi
}

configure_ghostty() {
    step "Configuring Ghostty"
    local config_dir="$HOME/.config/ghostty"
    local config_file="$config_dir/config"
    local repo_config="$SCRIPT_DIR/../config/ghostty/config"

    mkdir -p "$config_dir"

    if [[ -f "$config_file" ]]; then
        log "Ghostty config already exists — leaving it in place."
        return
    fi

    if [[ -f "$repo_config" ]]; then
        cp "$repo_config" "$config_file"
        log "Ghostty config installed to $config_file"
    else
        warn "No config/ghostty/config found in repo — skipping config install."
    fi
}

set_default_terminal() {
    step "Setting Ghostty as default terminal"

    if ! command_exists ghostty; then
        warn "Ghostty not found — skipping default terminal config."
        return
    fi

    local ghostty_bin
    ghostty_bin="$(command -v ghostty)"

    if ! update-alternatives --list x-terminal-emulator 2>/dev/null | grep -qF "$ghostty_bin"; then
        sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$ghostty_bin" 50
    fi
    sudo update-alternatives --set x-terminal-emulator "$ghostty_bin"
    log "x-terminal-emulator → $ghostty_bin"

    if command_exists gsettings; then
        gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
        gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
        log "GNOME default terminal set to Ghostty."
    else
        warn "gsettings not available — GNOME Ctrl+Alt+T shortcut not updated."
    fi
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_terminal; }

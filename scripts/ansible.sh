#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_ansible() {
    require_ubuntu
    step "Installing Ansible"

    if command_exists ansible; then
        log "Ansible already installed, upgrading if available..."
        apt_upgrade ansible
    else
        apt_install ansible
    fi

    log "Ansible $(ansible --version | head -1) installed."
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_ansible; }

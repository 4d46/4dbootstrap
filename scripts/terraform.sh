#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_terraform() {
    require_ubuntu
    step "Installing Terraform"

    # Fingerprint source: https://developer.hashicorp.com/terraform/install
    ensure_apt_key \
        "https://apt.releases.hashicorp.com/gpg" \
        "/usr/share/keyrings/hashicorp-archive-keyring.gpg" \
        "798AEC654E5C15428C8E42EEAA16FCBCA621E701"

    local distro
    distro="$(lsb_release -cs)"
    # Fall back to noble if Hashicorp doesn't yet have a repo for this distro
    if ! curl -fsSL --head "https://apt.releases.hashicorp.com/dists/${distro}/Release" &>/dev/null; then
        warn "Hashicorp apt repo has no release for '${distro}', using 'noble' instead."
        distro="noble"
    fi

    ensure_apt_source \
        "/etc/apt/sources.list.d/hashicorp.list" \
        "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${distro} main"

    if command_exists terraform; then
        log "Terraform already installed, upgrading..."
        apt_upgrade terraform
    else
        apt_install terraform
    fi

    log "Terraform $(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1) installed."
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_terraform; }

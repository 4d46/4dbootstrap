#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

OP_KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
OP_SOURCE="/etc/apt/sources.list.d/1password.list"
OP_POLICY_DIR="/etc/debsig/policies/AC2D62742012EA22"
OP_DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg"

install_onepassword() {
    require_ubuntu
    step "Installing 1Password"

    setup_apt_repo
    apt_update
    install_packages
    post_install_hints

    log "1Password setup complete."
}

setup_apt_repo() {
    if [[ -f "$OP_KEYRING" ]] && [[ -f "$OP_SOURCE" ]]; then
        return
    fi

    log "Adding 1Password apt repository..."

    # Verify fingerprint from: https://support.1password.com/install-linux/
    # Run the lookup command in ensure_apt_key's header comment, then set below.
    # Note: 1Password's repo setup is non-standard so we call ensure_apt_key then
    # separately install the debsig key — both should use the same fingerprint.
    ensure_apt_key \
        "https://downloads.1password.com/linux/keys/1password.asc" \
        "$OP_KEYRING" \
        "3FEF9748469ADBE15DA7CA80AC2D62742012EA22"

    echo "deb [arch=amd64 signed-by=$OP_KEYRING] https://downloads.1password.com/linux/debian/amd64 stable main" \
        | sudo tee "$OP_SOURCE" > /dev/null

    # debsig package verification policy
    sudo mkdir -p "$OP_POLICY_DIR"
    curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol \
        | sudo tee "${OP_POLICY_DIR}/1password.pol" > /dev/null

    # debsig needs its own copy of the same key — copy from the already-verified keyring
    sudo mkdir -p "$(dirname "$OP_DEBSIG_KEYRING")"
    sudo cp "$OP_KEYRING" "$OP_DEBSIG_KEYRING"
}

install_packages() {
    local -a to_install=()

    command_exists 1password      || to_install+=("1password")
    command_exists op             || to_install+=("1password-cli")

    if [[ ${#to_install[@]} -eq 0 ]]; then
        log "1Password and CLI already installed, upgrading..."
        apt_upgrade 1password 1password-cli
    else
        apt_install "${to_install[@]}"
    fi
}

post_install_hints() {
    echo
    log "1Password CLI usage:"
    log "  Sign in:          op signin"
    log "  Read a secret:    op read 'op://Vault/Item/field'"
    log "  Inject env vars:  op run --env-file=.env.op -- your-command"
    log "  SSH agent:        Settings → Developer → Use the SSH agent"
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_onepassword; }

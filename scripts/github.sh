#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_github() {
    require_ubuntu
    step "Installing GitHub CLI (gh)"

    # Verify fingerprint from: https://cli.github.com/
    # Run the lookup command in ensure_apt_key's header comment, then set below.
    ensure_apt_key \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "/etc/apt/keyrings/githubcli-archive-keyring.gpg" \
        "2C6106201985B60E6C7AC87323F3D4EA75716059"

    ensure_apt_source \
        "/etc/apt/sources.list.d/github-cli.list" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

    if command_exists gh; then
        log "gh $(gh --version | head -1) already installed, upgrading..."
        apt_upgrade gh
    else
        apt_install gh
        log "gh $(gh --version | head -1) installed."
    fi

    post_install_hints
}

post_install_hints() {
    echo
    log "To authenticate gh with 1Password (once op is set up):"
    log "  op read 'op://Personal/GitHub/token' | gh auth login --with-token"
    log ""
    log "Or interactively (choose SSH when prompted — uses your 1Password SSH agent):"
    log "  gh auth login"
    log ""
    log "Useful commands:"
    log "  gh repo clone owner/repo"
    log "  gh pr create"
    log "  gh pr list"
    log "  gh issue list"
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_github; }

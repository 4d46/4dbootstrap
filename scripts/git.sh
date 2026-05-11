#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_git() {
    require_ubuntu

    step "Installing git (latest via PPA)"
    if ! command_exists git; then
        sudo add-apt-repository -y ppa:git-core/ppa
        apt_update
        apt_install git
    else
        # PPA may already be registered; upgrade silently
        apt_upgrade git
        log "git $(git --version) already installed."
    fi

    step "Applying sensible git defaults"
    git config --global init.defaultBranch      main
    git config --global pull.rebase             true
    git config --global rebase.autoStash        true
    git config --global core.autocrlf          input
    git config --global fetch.prune             true
    git config --global diff.colorMoved        zebra

    # Set editor to nvim if available, fall back to vim
    if command_exists nvim; then
        git config --global core.editor nvim
    else
        git config --global core.editor vim
    fi

    configure_git_identity
    install_delta
    configure_delta

    log "git setup complete."
}

install_delta() {
    step "Installing delta"
    if command_exists delta; then
        apt_upgrade git-delta
        log "delta $(delta --version) already installed."
    else
        apt_install git-delta
        log "delta installed."
    fi
}

configure_delta() {
    step "Configuring delta as git pager"

    if ! command_exists delta; then
        warn "delta not found — skipping git pager config."
        return
    fi

    git config --global core.pager                 'delta'
    git config --global interactive.diffFilter      'delta --color-only'
    git config --global delta.navigate              true
    git config --global merge.conflictstyle         diff3
    log "git pager set to delta."
}

# Expected 1Password item structure:
#   Vault : System Credentials  (override with OP_GIT_VAULT)
#   Item  : Git Identity  (override with OP_GIT_ITEM)
#   Fields: 'name' and 'email'
#
# Create it once with:
#   op item create --category=login --title="Git Identity" \
#     "--vault=System Credentials" name="Your Name" email=you@example.com
configure_git_identity() {
    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || true)"
    current_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ -n "$current_name" && -n "$current_email" ]]; then
        log "Git identity already configured: $current_name <$current_email>"
        return
    fi

    local vault="${OP_GIT_VAULT:-System Credentials}"
    local item="${OP_GIT_ITEM:-Git Identity}"

    if command_exists op && op whoami &>/dev/null 2>&1; then
        log "Reading git identity from 1Password ($vault/$item)..."

        local op_name op_email
        op_name="$(op read  "op://${vault}/${item}/name"  2>/dev/null || true)"
        op_email="$(op read "op://${vault}/${item}/email" 2>/dev/null || true)"

        if [[ -n "$op_name" ]]; then
            git config --global user.name "$op_name"
            log "user.name set to: $op_name"
        else
            warn "Could not read 'name' field from op://${vault}/${item}"
        fi

        if [[ -n "$op_email" ]]; then
            git config --global user.email "$op_email"
            log "user.email set to: $op_email"
        else
            warn "Could not read 'email' field from op://${vault}/${item}"
        fi
    else
        warn "1Password CLI not available or not signed in — git identity not configured."
        warn "After running the onepassword module and signing in, rerun:"
        warn "  op signin && ./bootstrap.sh git"
    fi
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_git; }

#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# 1Password item that holds system-specific SSH host entries.
# Create it once with:
#   op item create \
#     --category="Secure Note" \
#     --title="SSH Hosts" \
#     --vault=Personal \
#     "config[text]=Host myserver
#       HostName 192.168.1.100
#       User mark"
OP_SSH_VAULT="${OP_SSH_VAULT:-Personal}"
OP_SSH_ITEM="${OP_SSH_ITEM:-SSH Hosts}"
OP_SSH_FIELD="${OP_SSH_FIELD:-config}"

SSH_CONFIG="$HOME/.ssh/config"
OP_HOSTS_BEGIN="# BEGIN 1password-ssh-hosts"
OP_HOSTS_END="# END 1password-ssh-hosts"

install_ssh() {
    command_exists 1password || command_exists op \
        || warn "1Password not yet installed — SSH agent config will be written but keys won't be available until after the onepassword module runs."

    step "Configuring SSH directory"
    setup_ssh_dir

    step "Writing base SSH config"
    write_base_config

    step "Applying SSH host entries from 1Password"
    apply_ssh_hosts

    post_install_hints
    log "SSH configuration complete."
}

setup_ssh_dir() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local authorized_keys="$HOME/.ssh/authorized_keys"
    if [[ ! -f "$authorized_keys" ]]; then
        touch "$authorized_keys"
        chmod 600 "$authorized_keys"
    fi
}

write_base_config() {
    local agent_socket
    if is_mac; then
        agent_socket="~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
        agent_socket="~/.1password/agent.sock"
    fi

    # Only write if the base block is not already present
    if grep -q "IdentityAgent" "$SSH_CONFIG" 2>/dev/null; then
        log "Base SSH config already present."
        return
    fi

    # Prepend base config, preserving any existing content below it
    local existing=""
    [[ -f "$SSH_CONFIG" ]] && existing=$(cat "$SSH_CONFIG")

    cat > "$SSH_CONFIG" << EOF
# ── 1Password SSH agent ───────────────────────────────────────────────────────
# Requires: 1Password app → Settings → Developer → Use the SSH agent
Host *
    IdentityAgent ${agent_socket}
    ServerAliveInterval 60
    ServerAliveCountMax 3

# ── GitHub ────────────────────────────────────────────────────────────────────
Host github.com
    User git
    IdentityAgent ${agent_socket}

EOF

    # Re-append any pre-existing content
    if [[ -n "$existing" ]]; then
        echo "$existing" >> "$SSH_CONFIG"
    fi

    chmod 600 "$SSH_CONFIG"
    log "Base SSH config written."
}

apply_ssh_hosts() {
    if ! command_exists op || ! op whoami &>/dev/null 2>&1; then
        warn "1Password CLI not available or not signed in — skipping custom SSH host entries."
        warn "Store your host entries at: op://${OP_SSH_VAULT}/${OP_SSH_ITEM}/${OP_SSH_FIELD}"
        warn "Then rerun: ./bootstrap.sh ssh"
        return
    fi

    local hosts_config
    hosts_config=$(op read "op://${OP_SSH_VAULT}/${OP_SSH_ITEM}/${OP_SSH_FIELD}" 2>/dev/null || true)

    if [[ -z "$hosts_config" ]]; then
        log "No SSH host entries found at op://${OP_SSH_VAULT}/${OP_SSH_ITEM}/${OP_SSH_FIELD} — skipping."
        return
    fi

    # Remove any previously applied 1Password block and replace it
    if grep -q "$OP_HOSTS_BEGIN" "$SSH_CONFIG" 2>/dev/null; then
        local tmp
        tmp=$(mktemp)
        sed "/${OP_HOSTS_BEGIN}/,/${OP_HOSTS_END}/d" "$SSH_CONFIG" > "$tmp"
        mv "$tmp" "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi

    cat >> "$SSH_CONFIG" << EOF

${OP_HOSTS_BEGIN}
# Auto-applied from op://${OP_SSH_VAULT}/${OP_SSH_ITEM}/${OP_SSH_FIELD}
# Do not edit this block manually — changes will be overwritten on next rerun.
${hosts_config}
${OP_HOSTS_END}
EOF

    log "SSH host entries applied from 1Password."
}

post_install_hints() {
    echo
    log "Next steps to complete SSH setup:"
    log "  1. Open 1Password → Settings → Developer → enable 'Use the SSH agent'"
    log "  2. Create an SSH key: 1Password app → New Item → SSH Key"
    log "     Or via CLI: op item create --category='SSH Key' --title='GitHub' --vault=${OP_SSH_VAULT}"
    log "  3. Copy the public key to GitHub: Settings → SSH Keys"
    log "     op read 'op://${OP_SSH_VAULT}/GitHub/public key'"
    log "  4. Test: ssh -T git@github.com"
    log "  5. Store remote server entries in 1Password and rerun: ./bootstrap.sh ssh"
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_ssh; }

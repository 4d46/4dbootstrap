#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

diff_config() {
    local label="$1"
    local repo_file="$2"
    local local_file="$3"

    step "Config: $label"

    if [[ ! -f "$repo_file" ]]; then
        warn "Repo file not found: $repo_file"
        return
    fi

    if [[ ! -f "$local_file" ]]; then
        warn "Local file not found (not yet installed): $local_file"
        return
    fi

    if diff -q "$repo_file" "$local_file" &>/dev/null; then
        log "Identical."
    elif command_exists delta; then
        { diff -u \
            --label "repo:  $repo_file" \
            --label "local: $local_file" \
            "$repo_file" "$local_file" || true; } | delta
    else
        diff -u \
            --label "repo:  $repo_file" \
            --label "local: $local_file" \
            "$repo_file" "$local_file" || true
    fi
}

diff_config "ghostty"  "$SCRIPT_DIR/../config/ghostty/config"  "$HOME/.config/ghostty/config"
diff_config "p10k"     "$SCRIPT_DIR/../config/p10k.zsh"        "$HOME/.p10k.zsh"
diff_config "mise"     "$SCRIPT_DIR/../config/mise.toml"        "$HOME/.config/mise/config.toml"

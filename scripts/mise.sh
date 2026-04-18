#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

MISE_BIN="$HOME/.local/bin/mise"
MISE_GLOBAL_CONFIG="$HOME/.config/mise/config.toml"
BOOTSTRAP_MISE_CONFIG="$SCRIPT_DIR/../config/mise.toml"

install_mise() {
    step "Installing mise version manager"

    local latest_tag
    latest_tag=$(get_latest_github_release "jdx/mise")

    if [[ -x "$MISE_BIN" ]]; then
        local installed
        installed=$("$MISE_BIN" --version | awk '{print $1}') \
            || error "mise binary exists but failed to report version."
        if [[ "$installed" == "${latest_tag#v}" ]]; then
            log "mise $installed already up to date."
        else
            log "mise $installed installed, self-updating to $latest_tag..."
            if ! "$MISE_BIN" self-update --yes; then
                warn "mise self-update failed — current version ($installed) kept. Rerun bootstrap to retry."
            fi
        fi
    else
        download_and_install_mise "$latest_tag"
        log "mise $latest_tag installed."
    fi

    step "Applying global tool versions"
    mkdir -p "$(dirname "$MISE_GLOBAL_CONFIG")"
    if [[ ! -f "$MISE_GLOBAL_CONFIG" ]] || ! diff -q "$BOOTSTRAP_MISE_CONFIG" "$MISE_GLOBAL_CONFIG" > /dev/null 2>&1; then
        cp "$BOOTSTRAP_MISE_CONFIG" "$MISE_GLOBAL_CONFIG"
        log "Global mise config updated → $MISE_GLOBAL_CONFIG"
    else
        log "Global mise config already up to date."
    fi

    step "Installing configured runtimes (this may take a few minutes)"
    "$MISE_BIN" upgrade --yes

    log "mise setup complete."
    log "Runtimes are activated via .zshrc on next shell open."
}

download_and_install_mise() {
    local version="$1"

    local mise_arch
    case "$(uname -m)" in
        x86_64)        mise_arch="x64" ;;
        aarch64|arm64) mise_arch="arm64" ;;
        *)             error "Unsupported architecture for mise: $(uname -m)" ;;
    esac

    local filename="mise-${version}-linux-${mise_arch}.tar.gz"
    local base_url="https://github.com/jdx/mise/releases/download/${version}"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    log "Downloading mise ${version}..."
    curl -fsSL "${base_url}/${filename}"        -o "$tmp_dir/${filename}"
    curl -fsSL "${base_url}/SHASUMS256.txt"     -o "$tmp_dir/SHASUMS256.txt"

    verify_sha256 "$tmp_dir/${filename}" "$tmp_dir/SHASUMS256.txt"

    tar -xzf "$tmp_dir/${filename}" -C "$tmp_dir"

    local extracted_bin
    extracted_bin=$(find "$tmp_dir" -name "mise" -type f | head -1)
    [[ -n "$extracted_bin" ]] || error "Could not find mise binary in downloaded archive."

    mkdir -p "$HOME/.local/bin"
    install -m 755 "$extracted_bin" "$HOME/.local/bin/mise"
    trap - RETURN
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_mise; }

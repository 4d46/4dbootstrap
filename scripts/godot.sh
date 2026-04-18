#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

GODOT_INSTALL_DIR="$HOME/.local/share/godot"
GODOT_BIN="$HOME/.local/bin/godot"
GODOT_VERSION_FILE="$GODOT_INSTALL_DIR/installed_version"

install_godot() {
    step "Installing Godot Engine"

    local latest_tag
    latest_tag=$(get_latest_github_release "godotengine/godot")

    local installed_version="none"
    if [[ -f "$GODOT_VERSION_FILE" ]]; then
        installed_version=$(cat "$GODOT_VERSION_FILE")
    fi

    if [[ "$installed_version" == "$latest_tag" ]]; then
        log "Godot $installed_version already up to date."
        return
    fi

    log "Installing Godot $latest_tag (currently: $installed_version)..."

    # Godot release filenames use the tag directly, e.g. "4.3-stable"
    local filename="Godot_v${latest_tag}_linux.x86_64.zip"
    local url="https://github.com/godotengine/godot/releases/download/${latest_tag}/${filename}"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    local sums_url="https://github.com/godotengine/godot/releases/download/${latest_tag}/SHA512-SUMS.txt"

    curl -fsSL "$url"      -o "$tmp_dir/$filename"
    curl -fsSL "$sums_url" -o "$tmp_dir/SHA512-SUMS.txt"

    verify_sha512 "$tmp_dir/$filename" "$tmp_dir/SHA512-SUMS.txt"

    unzip -q "$tmp_dir/$filename" -d "$tmp_dir/extracted"

    mkdir -p "$GODOT_INSTALL_DIR"
    find "$tmp_dir/extracted" -name "Godot_v*_linux.x86_64" -exec cp {} "$GODOT_INSTALL_DIR/godot" \;
    chmod +x "$GODOT_INSTALL_DIR/godot"
    echo "$latest_tag" > "$GODOT_VERSION_FILE"

    mkdir -p "$HOME/.local/bin"
    ln -sf "$GODOT_INSTALL_DIR/godot" "$GODOT_BIN"

    trap - RETURN
    create_desktop_entry "$latest_tag"

    log "Godot $latest_tag installed."
    log "Launch with 'godot' or find it in your application menu."
    warn "For C# scripting, also run: mise use -g dotnet@latest"
}

create_desktop_entry() {
    local version="$1"
    local desktop_file="$HOME/.local/share/applications/godot.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=Godot Engine ${version}
Comment=Multi-platform 2D and 3D game engine
Exec=${GODOT_INSTALL_DIR}/godot %f
Icon=godot
Type=Application
Categories=Development;IDE;Game;
MimeType=application/x-godot-project;
StartupWMClass=Godot
EOF
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_godot; }

#!/usr/bin/env bash
# Shared utilities — source this file, do not execute directly.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
step()  { echo -e "${BLUE}${BOLD}>>>>${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

is_ubuntu() { [[ -f /etc/os-release ]] && grep -q '^ID=ubuntu' /etc/os-release; }
is_mac()    { [[ "$(uname -s)" == "Darwin" ]]; }

get_arch() {
    case "$(uname -m)" in
        x86_64)        echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac
}

check_not_root() {
    [[ "$EUID" -ne 0 ]] || error "Do not run as root. Run as a regular user with sudo access."
}

check_sudo() {
    sudo -v 2>/dev/null || error "sudo access is required. Run 'sudo -v' to authenticate first."
}

require_ubuntu() {
    if is_mac; then
        warn "macOS support not yet implemented for this module. Skipping."
        exit 0
    fi
    is_ubuntu || error "This script requires Ubuntu."
}

apt_install() {
    sudo apt-get install -y --no-install-recommends "$@"
}

# Upgrade only already-installed packages — never pulls in new ones.
apt_upgrade() {
    sudo apt-get install -y --only-upgrade --no-install-recommends "$@"
}

apt_update() {
    sudo apt-get update -qq
}

# Download and install an apt signing key.
# Usage: ensure_apt_key <key_url> <keyfile> <expected_fingerprint>
#
# To look up a key's fingerprint before committing it:
#   tmpdir=$(mktemp -d)
#   curl -fsSL <key_url> | GNUPGHOME="$tmpdir" gpg --import 2>/dev/null
#   GNUPGHOME="$tmpdir" gpg --fingerprint --with-colons | awk -F: '/^fpr/{print $10; exit}'
#   rm -rf "$tmpdir"
ensure_apt_key() {
    local key_url="$1"
    local keyfile="$2"
    local expected_fingerprint="$3"

    [[ -f "$keyfile" ]] && return

    sudo mkdir -p "$(dirname "$keyfile")"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    log "Downloading GPG key..."
    curl -fsSL "$key_url" -o "$tmp_dir/key.asc"

    # Import into a throwaway GPG home — never touches the user's real keyring
    local tmp_gpg_home="$tmp_dir/gnupg"
    mkdir -p "$tmp_gpg_home"
    chmod 700 "$tmp_gpg_home"
    GNUPGHOME="$tmp_gpg_home" gpg --import "$tmp_dir/key.asc" 2>/dev/null

    local actual_fingerprint
    actual_fingerprint=$(GNUPGHOME="$tmp_gpg_home" gpg \
        --fingerprint --with-colons 2>/dev/null \
        | awk -F: '/^fpr/{print $10; exit}')

    local normalized_expected
    normalized_expected=$(echo "$expected_fingerprint" | tr -d ' ')

    if [[ "$actual_fingerprint" != "$normalized_expected" ]]; then
        error "GPG fingerprint mismatch for key from $key_url.
  Expected: $normalized_expected
  Got:      $actual_fingerprint
  The key may have changed or been tampered with. Aborting."
    fi

    log "GPG fingerprint verified."

    # Dearmor and install only after fingerprint passes
    gpg --dearmor < "$tmp_dir/key.asc" | sudo tee "$keyfile" > /dev/null
    sudo chmod 644 "$keyfile"
    trap - RETURN
}

ensure_apt_source() {
    local sourcefile="$1"
    local content="$2"
    if [[ ! -f "$sourcefile" ]]; then
        echo "$content" | sudo tee "$sourcefile" > /dev/null
        apt_update
    fi
}

# Append a line to a file only if that exact line is not already present.
add_line_if_missing() {
    local file="$1"
    local line="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Insert a line immediately before the p10k instant-prompt preamble so it executes before
# p10k captures stdout. Removes any existing occurrence first, making re-runs idempotent.
# If the preamble is not yet present (first bootstrap run before p10k has initialised),
# the line is placed at the top of the file and will be repositioned on the next run.
add_line_before_p10k_preamble() {
    local file="$1"
    local line="$2"
    local tmp
    tmp=$(mktemp)

    if grep -q 'Enable Powerlevel10k instant prompt' "$file" 2>/dev/null; then
        awk -v ins="$line" '
            BEGIN { inserted = 0 }
            /Enable Powerlevel10k instant prompt/ && !inserted { print ins; inserted = 1 }
            $0 != ins { print }
        ' "$file" > "$tmp" && mv "$tmp" "$file"
    else
        { echo "$line"; grep -vxF "$line" "$file" || true; } > "$tmp"
        mv "$tmp" "$file"
    fi
}

# Fetch the latest release tag from a public GitHub repo.
# Exits with an error if the tag cannot be determined (network failure, rate limit, etc.)
get_latest_github_release() {
    local repo="$1"
    local tag
    tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"tag_name"' \
        | head -1 \
        | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -n "$tag" ]] || error "Failed to get latest release for ${repo}. Check network or GitHub API rate limit (60 req/hr unauthenticated)."
    echo "$tag"
}

command_exists() {
    command -v "$1" &>/dev/null
}

# Verify a file's SHA256 checksum.
# Accepts a checksum file in either "hash  filename", bare-hash, or multi-entry SUMS format.
verify_sha256() {
    local file="$1"
    local checksum_file="$2"

    local expected actual
    if grep -qF "$(basename "$file")" "$checksum_file" 2>/dev/null; then
        expected=$(grep -F "$(basename "$file")" "$checksum_file" | awk '{print $1}')
    else
        expected=$(awk '{print $1}' "$checksum_file")
    fi
    actual=$(sha256sum "$file" | awk '{print $1}')

    if [[ "$actual" != "$expected" ]]; then
        error "SHA256 mismatch for $(basename "$file").
  Expected: $expected
  Got:      $actual"
    fi
    log "Checksum verified: $(basename "$file")"
}

# Verify a file's SHA512 checksum.
# Accepts either a single-entry checksum file or a multi-entry SUMS file
# (in which case it greps for the specific filename).
verify_sha512() {
    local file="$1"
    local checksum_file="$2"

    local expected actual
    if grep -qF "$(basename "$file")" "$checksum_file" 2>/dev/null; then
        expected=$(grep -F "$(basename "$file")" "$checksum_file" | awk '{print $1}')
    else
        expected=$(awk '{print $1}' "$checksum_file")
    fi

    actual=$(sha512sum "$file" | awk '{print $1}')

    if [[ "$actual" != "$expected" ]]; then
        error "SHA512 mismatch for $(basename "$file").
  Expected: $expected
  Got:      $actual"
    fi
    log "Checksum verified: $(basename "$file")"
}

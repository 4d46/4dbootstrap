#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_docker() {
    require_ubuntu
    step "Installing Docker CE"

    # Fingerprint source: https://docs.docker.com/engine/install/ubuntu/
    ensure_apt_key \
        "https://download.docker.com/linux/ubuntu/gpg" \
        "/etc/apt/keyrings/docker.gpg" \
        "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"

    local arch
    arch="$(dpkg --print-architecture)"
    local codename
    codename="$(lsb_release -cs)"

    ensure_apt_source \
        "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable"

    if command_exists docker; then
        log "Docker $(docker --version) already installed, upgrading..."
        apt_upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        log "Docker installed."
    fi

    ensure_docker_group
    log "Docker setup complete."
}

ensure_docker_group() {
    if ! groups "$USER" | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        warn "Added '$USER' to the docker group. Log out and back in before running Docker without sudo."
    else
        log "User '$USER' already in docker group."
    fi
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_docker; }

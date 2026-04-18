#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Track the stable kubectl minor version here; bump when upgrading.
K8S_VERSION="v1.30"

install_kubernetes() {
    require_ubuntu
    install_kubectl
    install_minikube
    install_helm
    log "Kubernetes tools ready."
}

install_kubectl() {
    step "Installing kubectl"

    # Verify fingerprint from: https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key
    # Note: this key is version-specific — re-verify when bumping K8S_VERSION.
    # Run the lookup command in ensure_apt_key's header comment, then set below.
    ensure_apt_key \
        "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
        "/etc/apt/keyrings/kubernetes-apt-keyring.gpg" \
        "DE15B14486CD377B9E876E1A234654DA9A296436"

    ensure_apt_source \
        "/etc/apt/sources.list.d/kubernetes.list" \
        "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /"

    if command_exists kubectl; then
        log "kubectl already installed, upgrading..."
        apt_upgrade kubectl
    else
        apt_install kubectl
    fi

    log "kubectl $(kubectl version --client --short 2>/dev/null || kubectl version --client) installed."
}

install_minikube() {
    step "Installing minikube"

    local arch latest
    arch="$(get_arch)"
    latest="$(get_latest_github_release "kubernetes/minikube")"

    if command_exists minikube; then
        local current
        current="$(minikube version --short 2>/dev/null | grep -oP 'v[\d.]+')"
        if [[ "$current" == "$latest" ]]; then
            log "minikube $current already up to date."
            return
        fi
        log "Updating minikube $current → $latest..."
    else
        log "Installing minikube $latest..."
    fi

    local base_url="https://github.com/kubernetes/minikube/releases/download/${latest}"
    local filename="minikube-linux-${arch}"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    curl -fsSL "${base_url}/${filename}"        -o "$tmp_dir/minikube"
    curl -fsSL "${base_url}/${filename}.sha256" -o "$tmp_dir/minikube.sha256"

    verify_sha256 "$tmp_dir/minikube" "$tmp_dir/minikube.sha256"

    sudo install "$tmp_dir/minikube" /usr/local/bin/minikube
    trap - RETURN
    log "minikube $(minikube version --short) installed."
}

install_helm() {
    step "Installing helm"

    local latest_tag
    latest_tag=$(get_latest_github_release "helm/helm")

    if command_exists helm; then
        local installed
        installed="$(helm version --short 2>/dev/null | grep -oP 'v[\d.]+')"
        if [[ "$installed" == "$latest_tag" ]]; then
            log "helm $installed already up to date."
            return
        fi
        log "Updating helm $installed → $latest_tag..."
    else
        log "Installing helm $latest_tag..."
    fi

    download_and_install_helm "$latest_tag"
    log "helm $(helm version --short) installed."
}

download_and_install_helm() {
    local version="$1"
    local arch
    arch="$(get_arch)"  # returns amd64/arm64

    local filename="helm-${version}-linux-${arch}.tar.gz"
    local base_url="https://get.helm.sh"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    log "Downloading helm ${version}..."
    curl -fsSL "${base_url}/${filename}"           -o "$tmp_dir/${filename}"
    curl -fsSL "${base_url}/${filename}.sha256sum" -o "$tmp_dir/${filename}.sha256sum"

    verify_sha256 "$tmp_dir/${filename}" "$tmp_dir/${filename}.sha256sum"

    tar -xzf "$tmp_dir/${filename}" -C "$tmp_dir"
    sudo install -m 755 "$tmp_dir/linux-${arch}/helm" /usr/local/bin/helm
    trap - RETURN
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_kubernetes; }

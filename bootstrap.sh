#!/usr/bin/env bash
# Main bootstrap entry point.
# Usage:
#   ./bootstrap.sh               -  run all modules in order
#   ./bootstrap.sh docker mise   -  run specific modules only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

MODULES=(
    system
    shell
    git
    github
    mise
    editors
    terminal
    docker
    kubernetes
    terraform
    ansible
    onepassword
    env
    ssh
    godot
)

run_module() {
    local module="$1"
    local script="$SCRIPT_DIR/scripts/${module}.sh"

    if [[ ! -f "$script" ]]; then
        error "Module script not found: $script"
    fi

    echo
    step "Module: $module"
    bash "$script"
}

main() {
    check_not_root
    check_sudo

    echo
    log "Starting 4D Bootstrap"
    log "Platform: $(uname -s) $(uname -m)"

    local -a modules_to_run
    if [[ $# -gt 0 ]]; then
        modules_to_run=("$@")
    else
        modules_to_run=("${MODULES[@]}")
    fi

    for module in "${modules_to_run[@]}"; do
        run_module "$module"
    done

    echo
    log "Bootstrap complete."
    warn "Restart your terminal to activate all changes, or run: source ~/.zshrc"
}

main "$@"

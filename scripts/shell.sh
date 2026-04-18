#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

install_shell() {
    require_ubuntu

    step "Installing zsh"
    if ! command_exists zsh; then
        apt_install zsh
    else
        log "zsh $(zsh --version) already installed."
    fi

    step "Installing oh-my-zsh"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        # Standard oh-my-zsh install method — trusts HTTPS and the official ohmyzsh/ohmyzsh repo.
        # RUNZSH/CHSH/KEEP_ZSHRC prevent the installer changing shell or overwriting .zshrc.
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log "oh-my-zsh installed."
    else
        log "oh-my-zsh already installed, pulling updates..."
        git -C "$HOME/.oh-my-zsh" pull --quiet --rebase
    fi

    step "Installing powerlevel10k theme"
    local p10k_dir="$ZSH_CUSTOM_DIR/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    else
        git -C "$p10k_dir" pull --quiet --rebase
    fi

    step "Installing zsh plugins"
    local plugins_dir="$ZSH_CUSTOM_DIR/plugins"
    local -a plugin_repos=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-completions"
    )
    for repo in "${plugin_repos[@]}"; do
        local name="${repo##*/}"
        local dir="$plugins_dir/$name"
        if [[ ! -d "$dir" ]]; then
            git clone --depth=1 "https://github.com/${repo}.git" "$dir"
        else
            git -C "$dir" pull --quiet --rebase
        fi
    done

    step "Configuring .zshrc"
    configure_zshrc

    step "Installing InconsolataGo Nerd Font"
    install_nerd_font "InconsolataGo"

    step "Configuring Ptyxis font"
    configure_ptyxis_font "InconsolataGo Nerd Font Mono" "13"

    step "Restoring powerlevel10k config"
    restore_p10k_config

    step "Setting zsh as default shell"
    local zsh_path
    zsh_path="$(command -v zsh)"
    if ! grep -qx "$zsh_path" /etc/shells; then
        echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
    fi
    if [[ "$SHELL" != "$zsh_path" ]]; then
        chsh -s "$zsh_path"
        warn "Default shell changed to zsh — takes effect on next login."
    else
        log "zsh is already the default shell."
    fi

    log "Shell setup complete."
    log "To apply changes in your current terminal without opening a new one, run: source ~/.zshrc"
}

configure_zshrc() {
    local zshrc="$HOME/.zshrc"

    # oh-my-zsh may not have created .zshrc yet if KEEP_ZSHRC=yes and none existed
    if [[ ! -f "$zshrc" ]]; then
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$zshrc"
    fi

    # Set theme
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"

    # Set plugins
    sed -i 's|^plugins=.*|plugins=(git z zsh-autosuggestions zsh-syntax-highlighting zsh-completions)|' "$zshrc"

    # Ensure ~/.local/bin is in PATH before oh-my-zsh sources
    add_line_if_missing "$zshrc" 'export PATH="$HOME/.local/bin:$PATH"'

    # mise activation (added after oh-my-zsh source block)
    add_line_if_missing "$zshrc" '# mise — version manager'
    add_line_if_missing "$zshrc" '[[ -x "$HOME/.local/bin/mise" ]] && eval "$($HOME/.local/bin/mise activate zsh)"'

    # load-secrets function (reads from 1Password into shell memory, never writes to disk)
    add_line_if_missing "$zshrc" '# 1Password shell secrets'
    add_line_if_missing "$zshrc" '[[ ! -f ~/.config/op/load-secrets.zsh ]] || source ~/.config/op/load-secrets.zsh'

    # Secrets warning must run before the p10k instant-prompt preamble captures stdout
    add_line_before_p10k_preamble "$zshrc" '[[ -n "$SECRETS_LOADED" ]] || echo "Secrets not loaded. Run: load-secrets"'

    # powerlevel10k config
    add_line_if_missing "$zshrc" '# powerlevel10k'
    add_line_if_missing "$zshrc" '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'
}

install_nerd_font() {
    local font_name="$1"
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"

    if find "$fonts_dir" -iname "${font_name}*.ttf" | grep -q .; then
        log "$font_name Nerd Font already installed."
        return
    fi

    log "Downloading $font_name Nerd Font..."
    local latest_tag
    latest_tag=$(get_latest_github_release "ryanoasis/nerd-fonts")

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    curl -fsSL \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${latest_tag}/${font_name}.zip" \
        -o "$tmp_dir/${font_name}.zip"

    unzip -q "$tmp_dir/${font_name}.zip" -d "$tmp_dir/fonts"
    find "$tmp_dir/fonts" -name "*.ttf" -exec cp {} "$fonts_dir/" \;

    fc-cache -f
    trap - RETURN
    log "$font_name Nerd Font installed."
}

configure_ptyxis_font() {
    local font_name="$1"
    local font_size="$2"

    if ! command_exists gsettings; then
        warn "gsettings not available — skipping Ptyxis font config."
        return
    fi

    if ! dpkg -l ptyxis 2>/dev/null | grep -q '^ii'; then
        warn "Ptyxis not installed — skipping font config."
        return
    fi

    gsettings set org.gnome.Ptyxis use-system-font false
    gsettings set org.gnome.Ptyxis font-name "${font_name} ${font_size}"
    log "Ptyxis font set to: ${font_name} ${font_size}"
}

restore_p10k_config() {
    local repo_config="$SCRIPT_DIR/../config/p10k.zsh"
    local target="$HOME/.p10k.zsh"

    if [[ -f "$target" ]]; then
        log "~/.p10k.zsh already exists — leaving it in place."
        return
    fi

    if [[ -f "$repo_config" ]]; then
        cp "$repo_config" "$target"
        log "Restored p10k config from repo — wizard will be skipped on first launch."
    else
        warn "No config/p10k.zsh found in repo."
        warn "The powerlevel10k wizard will run on your first zsh session."
        warn "Afterwards, copy ~/.p10k.zsh to config/p10k.zsh and commit it to skip the wizard in future."
    fi
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || { check_not_root && check_sudo && install_shell; }

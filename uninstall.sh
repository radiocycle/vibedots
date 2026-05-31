#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  Dotfiles uninstaller — removes deployed configs and restores backup
#  Usage: bash uninstall.sh [--auto]
# ─────────────────────────────────────────────────────────────────

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}  ::${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}  !${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC}  $*"; }
header()  { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }
dim()     { echo -e "${DIM}     $*${NC}"; }

AUTO=false
[[ "$1" == "--auto" ]] && AUTO=true

ask() {
    local question="$1" default="${2:-y}"
    if $AUTO; then [[ "$default" == "y" ]] && return 0 || return 1; fi
    local prompt; [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"
    echo -en "${CYAN}  ?${NC}  $question $prompt "
    read -r answer; answer="${answer:-$default}"
    [[ "${answer,,}" == "y" ]]
}

# ── Banner ────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${RED}"
cat << 'EOF'
   ██╗   ██╗███╗   ██╗██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗
   ██║   ██║████╗  ██║██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║
   ██║   ██║██╔██╗ ██║██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║
   ██║   ██║██║╚██╗██║██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║
   ╚██████╔╝██║ ╚████║██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
    ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
echo -e "${NC}"
echo -e "  ${BOLD}Dotfiles uninstaller${NC}"
echo -e "  ${DIM}Removes deployed configs — packages are NOT touched${NC}"
echo

warn "This removes deployed dotfiles from ~/.config/ and your home directory."
warn "Packages installed by install.sh will NOT be removed."
echo
ask "Continue with uninstall?" "n" || { echo; info "Aborted."; exit 0; }

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Stop running bar processes ─────────────────────────────────
header "Stop bar processes"

for proc in qs waybar; do
    if pgrep -x "$proc" &>/dev/null; then
        if ask "Kill running $proc?" "y"; then
            pkill -x "$proc" && success "Killed $proc" || warn "Could not kill $proc"
        fi
    else
        dim "$proc not running"
    fi
done

# ── 2. Remove deployed configs ────────────────────────────────────
header "Remove deployed configs"

CONFIGS=(
    hypr quickshell foot fuzzel mako waypaper wlogout
    fastfetch matugen waybar Kvantum gtk-3.0 gtk-4.0 qtengine spicetify
)

if ask "Remove dotfile configs from ~/.config/?" "y"; then
    for cfg in "${CONFIGS[@]}"; do
        target="$HOME/.config/$cfg"
        if [[ -e "$target" ]]; then
            rm -rf "$target" && dim "removed: $target"
        fi
    done
    [[ -f "$HOME/.config/starship.toml" ]] && rm -f "$HOME/.config/starship.toml" && dim "removed: starship.toml"
    success "Configs removed"
fi

# ── 3. Remove home files ──────────────────────────────────────────
header "Remove home files"

if ask "Remove .zshrc and custom scripts in ~/.local/bin/?" "y"; then
    [[ -f "$HOME/.zshrc" ]] && rm -f "$HOME/.zshrc" && dim "removed: ~/.zshrc"
    for b in zerochan-wallpaper; do
        [[ -f "$HOME/.local/bin/$b" ]] && rm -f "$HOME/.local/bin/$b" && dim "removed: ~/.local/bin/$b"
    done
    success "Home files removed"
fi

# ── 4. Restore backup ─────────────────────────────────────────────
header "Restore backup"

LATEST_BACKUP="$(ls -dt "$HOME"/.config-backup-* 2>/dev/null | head -1)"

if [[ -n "$LATEST_BACKUP" ]]; then
    info "Latest backup found: $LATEST_BACKUP"
    if ask "Restore configs from this backup?" "y"; then
        for item in "$LATEST_BACKUP"/*/; do
            [[ -d "$item" ]] || continue
            name="$(basename "$item")"
            cp -r "$item" "$HOME/.config/$name" && dim "restored: $name"
        done
        [[ -f "$LATEST_BACKUP/zshrc.bak" ]] && cp "$LATEST_BACKUP/zshrc.bak" "$HOME/.zshrc" && dim "restored: .zshrc"
        success "Backup restored from $LATEST_BACKUP"
    fi
else
    warn "No backup found in $HOME/.config-backup-*"
fi

# ── 5. Disable SDDM (optional) ───────────────────────────────────
header "Services (optional)"

if ask "Disable SDDM display manager?" "n"; then
    sudo systemctl disable sddm && success "SDDM disabled" || warn "Failed"
fi

# ── Done ──────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  Uninstall complete!${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
[[ -n "$LATEST_BACKUP" ]] && echo -e "  ${BOLD}Backup:${NC} $LATEST_BACKUP" && echo
echo -e "  ${DIM}Packages were not removed. To remove manually:${NC}"
echo -e "  ${DIM}yay -Rns hyprland quickshell waybar foot fuzzel mako matugen wlogout${NC}"
echo

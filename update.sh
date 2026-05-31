#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  Dotfiles updater — pulls latest changes and redeploys configs
#  Usage: bash update.sh [--auto] [--no-packages]
# ─────────────────────────────────────────────────────────────────

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}  ::${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}  !${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC}  $*"; }
header()  { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }
dim()     { echo -e "${DIM}     $*${NC}"; }

AUTO=false; SKIP_PKGS=false
for arg in "$@"; do
    [[ "$arg" == "--auto" ]]        && AUTO=true
    [[ "$arg" == "--no-packages" ]] && SKIP_PKGS=true
done

ask() {
    local question="$1" default="${2:-y}"
    if $AUTO; then [[ "$default" == "y" ]] && return 0 || return 1; fi
    local prompt; [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"
    echo -en "${CYAN}  ?${NC}  $question $prompt "
    read -r answer; answer="${answer:-$default}"
    [[ "${answer,,}" == "y" ]]
}

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Banner ────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
   ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
   ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
   ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗
   ██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝
   ╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗
    ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
EOF
echo -e "${NC}"
echo -e "  ${BOLD}Dotfiles updater${NC}"
echo -e "  ${DIM}Pulls latest changes from git and redeploys${NC}"
echo

# ── Pre-flight ────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then error "git not found"; exit 1; fi
if [[ ! -d "$DOTS_DIR/.git" ]]; then error "$DOTS_DIR is not a git repository"; exit 1; fi

info "Dotfiles directory: $DOTS_DIR"
info "Current branch: $(git -C "$DOTS_DIR" branch --show-current)"
echo

# ── 1. Pull latest ────────────────────────────────────────────────
header "Pull latest changes"

REMOTE_URL="$(git -C "$DOTS_DIR" remote get-url origin 2>/dev/null || echo "unknown")"
info "Remote: $REMOTE_URL"

if ! git -C "$DOTS_DIR" diff --quiet 2>/dev/null; then
    warn "You have local uncommitted changes in $DOTS_DIR"
    git -C "$DOTS_DIR" diff --stat
    echo
    ask "Continue anyway (local changes may be overwritten)?" "n" || { info "Aborted."; exit 0; }
fi

info "Fetching..."
git -C "$DOTS_DIR" fetch origin

BEHIND="$(git -C "$DOTS_DIR" rev-list HEAD..origin/main --count 2>/dev/null || echo 0)"
if [[ "$BEHIND" -eq 0 ]]; then
    success "Already up to date"
else
    info "$BEHIND new commit(s) available:"
    git -C "$DOTS_DIR" log HEAD..origin/main --oneline | sed 's/^/     /'
    echo
    if ask "Pull $BEHIND commit(s)?" "y"; then
        git -C "$DOTS_DIR" pull --ff-only origin main && success "Pulled latest changes" || {
            error "Pull failed — run 'git pull' manually in $DOTS_DIR"; exit 1
        }
    fi
fi

# ── 2. Update packages (optional) ────────────────────────────────
if ! $SKIP_PKGS; then
    header "Update packages"

    if ask "Run system update (yay -Syu)?" "y"; then
        NOCONFIRM=""; $AUTO && NOCONFIRM="--noconfirm"
        if command -v yay &>/dev/null; then
            yay -Syu $NOCONFIRM && success "System updated" || warn "Update had errors"
        else
            sudo pacman -Syu $NOCONFIRM && success "System updated" || warn "Update had errors"
        fi
    fi
fi

# ── 3. Redeploy configs ───────────────────────────────────────────
header "Redeploy configs"

deploy_item() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    dim "→ $dst"
}

if ask "Redeploy configs from $DOTS_DIR/config/ to ~/.config/?" "y"; then
    for item in "$DOTS_DIR/config"/*/; do
        [[ -d "$item" ]] || continue
        name="$(basename "$item")"
        deploy_item "$item" "$HOME/.config/$name"
    done
    for f in starship.toml spotify-flags.conf; do
        [[ -f "$DOTS_DIR/config/$f" ]] && deploy_item "$DOTS_DIR/config/$f" "$HOME/.config/$f"
    done
    success "Configs deployed"
fi

if [[ -d "$DOTS_DIR/home" ]]; then
    if ask "Redeploy home files (.zshrc, scripts)?" "y"; then
        [[ -f "$DOTS_DIR/home/.zshrc" ]] && deploy_item "$DOTS_DIR/home/.zshrc" "$HOME/.zshrc"
        mkdir -p "$HOME/.local/bin"
        for f in "$DOTS_DIR/home/.local/bin/"*; do
            [[ -f "$f" ]] || continue
            deploy_item "$f" "$HOME/.local/bin/$(basename "$f")"
            chmod +x "$HOME/.local/bin/$(basename "$f")" 2>/dev/null || true
        done
        success "Home files deployed"
    fi
fi

# ── 4. Reload running services ────────────────────────────────────
header "Reload services"

if pgrep -x Hyprland &>/dev/null || pgrep -x hyprland &>/dev/null; then
    if ask "Reload Hyprland config?" "y"; then
        hyprctl reload && success "Hyprland reloaded" || warn "hyprctl reload failed"
    fi
fi

if pgrep -x qs &>/dev/null; then
    if ask "Restart Quickshell bar?" "y"; then
        pkill -x qs; sleep 0.5
        QML_XHR_ALLOW_FILE_READ=1 qs --daemonize &>/dev/null
        success "Quickshell restarted"
    fi
fi

if pgrep -x waybar &>/dev/null; then
    if ask "Restart Waybar?" "y"; then
        pkill -x waybar; sleep 0.3
        waybar &>/dev/null &
        success "Waybar restarted"
    fi
fi

if pgrep -x mako &>/dev/null; then
    if ask "Reload mako notifications?" "y"; then
        makoctl reload && success "Mako reloaded" || warn "makoctl reload failed"
    fi
fi

APPLY_THEME="$HOME/.config/hypr/scripts/apply-theme.sh"
if [[ -f "$APPLY_THEME" ]]; then
    CURRENT_WP="$(grep '^wallpaper' "$HOME/.config/waypaper/config.ini" 2>/dev/null | cut -d= -f2 | tr -d ' ' | head -1)"
    if [[ -f "$CURRENT_WP" ]]; then
        if ask "Re-apply matugen color theme?" "y"; then
            bash "$APPLY_THEME" "$CURRENT_WP" && success "Theme applied" || warn "Theme apply failed"
        fi
    fi
fi

# ── Done ──────────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  Update complete!${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
info "Tip: ${BOLD}bash update.sh --no-packages${NC} to skip yay -Syu next time"
echo

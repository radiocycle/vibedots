#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  Dotfiles installer for Arch Linux
#  Usage: bash install.sh [--auto]
# ─────────────────────────────────────────────────────────────────

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}  ::${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}  !${NC}  $*"; }
error()   { echo -e "${RED}  ✗${NC}  $*"; }
header()  { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }
dim()     { echo -e "${DIM}     $*${NC}"; }

# ── Parse args ────────────────────────────────────────────────────
AUTO=false
for arg in "$@"; do
    [[ "$arg" == "--auto" ]]       && AUTO=true
done

# ── Helpers ───────────────────────────────────────────────────────
ask() {
    # ask <question> <default: y/n>
    local question="$1" default="${2:-y}"
    if $AUTO; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    local prompt
    [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"
    echo -en "${CYAN}  ?${NC}  $question $prompt "
    read -r answer
    answer="${answer:-$default}"
    [[ "${answer,,}" == "y" ]]
}

confirm_or_exit() {
    ask "$1" "y" || { echo; warn "Skipped."; return 1; }
    return 0
}

step() {
    # step <number> <total> <description>
    echo -e "\n${BOLD}  [$1/$2]${NC} $3"
}

# ── Banner ────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
   ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
   ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
   ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
   ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
   ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
   ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
EOF
echo -e "${NC}"
echo -e "  ${BOLD}Arch Linux dotfiles installer${NC}"
echo -e "  ${DIM}Hyprland + Quickshell + foot + fuzzel + matugen${NC}"
echo

# ── Mode & bar selection ──────────────────────────────────────────
if ! $AUTO; then
    echo -e "  ${BOLD}Mode:${NC}"
    echo -e "   ${CYAN}1${NC}) Interactive  — confirm each step"
    echo -e "   ${CYAN}2${NC}) Automatic    — install everything without prompts"
    echo -en "\n  Choice [1/2]: "
    read -r mode_choice
    [[ "$mode_choice" == "2" ]] && AUTO=true
    echo
fi

$AUTO && info "Running in ${BOLD}automatic${NC} mode" || info "Running in ${BOLD}interactive${NC} mode"


# ── Pre-flight checks ─────────────────────────────────────────────
header "Pre-flight checks"

# Must be Arch
if ! command -v pacman &>/dev/null; then
    error "pacman not found — this script is for Arch Linux only."
    exit 1
fi
success "Arch Linux detected"

# Not root
if [[ "$EUID" -eq 0 ]]; then
    error "Do not run as root. Run as your normal user."
    exit 1
fi
success "Running as user: $USER"

# Internet
if ! ping -c1 -W3 archlinux.org &>/dev/null; then
    error "No internet connection."
    exit 1
fi
success "Internet connection OK"

# Confirm start
echo
if ! $AUTO; then
    ask "Ready to begin installation?" "y" || { echo; exit 0; }
fi

TOTAL_STEPS=10

# ── Step 1: Backup ────────────────────────────────────────────────
step 1 $TOTAL_STEPS "Backup existing configs"

BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

CONFIGS_TO_BACKUP=(
    hypr foot fuzzel mako waypaper wlogout
    fastfetch matugen starship.toml
)

DO_BACKUP=false
for cfg in "${CONFIGS_TO_BACKUP[@]}"; do
    [[ -e "$HOME/.config/$cfg" ]] && DO_BACKUP=true && break
done

if $DO_BACKUP; then
    if ask "Back up existing configs to $BACKUP_DIR?" "y"; then
        mkdir -p "$BACKUP_DIR"
        for cfg in "${CONFIGS_TO_BACKUP[@]}"; do
            src="$HOME/.config/$cfg"
            [[ -e "$src" ]] && cp -r "$src" "$BACKUP_DIR/" && dim "backed up: $cfg"
        done
        [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$BACKUP_DIR/zshrc.bak"
        success "Backup saved to $BACKUP_DIR"
    else
        warn "Skipping backup"
    fi
else
    info "Nothing to back up"
fi

# ── Step 2: yay ───────────────────────────────────────────────────
step 2 $TOTAL_STEPS "AUR helper (yay)"

if command -v yay &>/dev/null; then
    success "yay already installed ($(yay --version | head -1))"
else
    if ask "Install yay?" "y"; then
        info "Building yay from AUR..."
        sudo pacman -S --needed --noconfirm git base-devel
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$tmp/yay"
        cd "$tmp/yay" && makepkg -si --noconfirm
        cd "$HOME" && rm -rf "$tmp"
        success "yay installed"
    fi
fi

# ── Step 3: Pacman packages ───────────────────────────────────────
step 3 $TOTAL_STEPS "Core packages (pacman)"

PKGS_PACMAN=(
    # Hyprland
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    hyprland-guiutils hyprlock wlogout hyprpicker

    # Display manager
    sddm

    # Terminal & shell
    foot zsh zsh-autosuggestions zsh-syntax-highlighting
    zsh-history-substring-search zsh-completions starship

    # Launcher & notifications
    fuzzel mako libnotify

    # Bar (both installed, toggle with Super+Shift+B)
    waybar

    # Audio
    pipewire pipewire-audio pipewire-pulse wireplumber

    # Screenshots & clipboard
    grim slurp wl-clipboard cliphist

    # Network & Bluetooth
    networkmanager network-manager-applet bluez bluez-utils

    # Power & brightness
    power-profiles-daemon brightnessctl upower

    # Media
    playerctl

    # System tools
    btop fastfetch socat

    # Auth
    polkit-gnome gnome-keyring seahorse

    # Themes, icons, fonts
    adw-gtk3 papirus-icon-theme
    qt6ct qt5ct breeze breeze5
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

    # Qt Wayland
    qt5-wayland qt6-wayland

    # Python & misc
    python python-playwright jq zip unzip
)

echo
info "Packages to install (${#PKGS_PACMAN[@]} total):"
dim "${PKGS_PACMAN[*]}"
echo

if ask "Install pacman packages?" "y"; then
    NOCONFIRM=""
    $AUTO && NOCONFIRM="--noconfirm"
    sudo pacman -S --needed $NOCONFIRM "${PKGS_PACMAN[@]}"
    success "Pacman packages installed"
else
    warn "Skipping pacman packages"
fi

# ── Step 4: AUR packages ──────────────────────────────────────────
step 4 $TOTAL_STEPS "AUR packages"

PKGS_AUR=(
    awww
    waypaper
    matugen
    zen-browser-bin
    spotify
    spicetify-cli
    spicetify-marketplace-bin
    bibata-cursor-theme
)

if command -v yay &>/dev/null; then
    echo
    info "AUR packages (${#PKGS_AUR[@]} total):"
    dim "${PKGS_AUR[*]}"
    echo

    if ask "Install AUR packages?" "y"; then
        NOCONFIRM=""
        $AUTO && NOCONFIRM="--noconfirm"
        yay -S --needed $NOCONFIRM "${PKGS_AUR[@]}"
        success "AUR packages installed"
    else
        warn "Skipping AUR packages"
    fi
else
    error "yay not found — skipping AUR packages"
fi

# ── Step 5: Playwright Chromium ───────────────────────────────────
step 5 $TOTAL_STEPS "Playwright Chromium (zerochan wallpaper script)"

if python3 -c "from playwright.sync_api import sync_playwright" &>/dev/null; then
    if ask "Install Playwright Chromium (~115MB)?" "y"; then
        playwright install chromium && success "Chromium installed" || warn "Failed — run 'playwright install chromium' manually"
    fi
else
    warn "python-playwright not found — skipping"
fi

# ── Step 6: Oh My Zsh ─────────────────────────────────────────────
step 6 $TOTAL_STEPS "Oh My Zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
    success "Oh My Zsh already installed"
else
    if ask "Install Oh My Zsh?" "y"; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh My Zsh installed"
    fi
fi

# ── Step 7: Default shell ─────────────────────────────────────────
step 7 $TOTAL_STEPS "Default shell"

CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
ZSH_PATH="$(command -v zsh)"

if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
    success "zsh is already default shell"
else
    if ask "Set zsh as default shell (current: ${CURRENT_SHELL##*/})?" "y"; then
        sudo chsh -s "$ZSH_PATH" "$USER"
        success "Shell changed to zsh (takes effect on next login)"
    fi
fi

# ── Step 8: System services ───────────────────────────────────────
step 8 $TOTAL_STEPS "System services"

declare -A SERVICES=(
    [bluetooth]="Bluetooth daemon"
    [NetworkManager]="Network Manager"
    [power-profiles-daemon]="Power profiles"
)

for svc in "${!SERVICES[@]}"; do
    desc="${SERVICES[$svc]}"
    if systemctl is-enabled "$svc" &>/dev/null; then
        success "$desc ($svc) already enabled"
    else
        if ask "Enable $desc ($svc)?" "y"; then
            sudo systemctl enable --now "$svc" && success "Enabled $svc" || warn "Could not enable $svc"
        fi
    fi
done

if ! systemctl is-enabled sddm &>/dev/null; then
    if ask "Enable SDDM display manager?" "y"; then
        sudo systemctl enable sddm && success "SDDM enabled"
    fi
else
    success "SDDM already enabled"
fi

# ── Step 9: User groups ───────────────────────────────────────────
step 9 $TOTAL_STEPS "User groups"

GROUPS_TO_ADD=(input video audio)
GROUPS_NEEDED=()

for grp in "${GROUPS_TO_ADD[@]}"; do
    id -nG "$USER" | grep -qw "$grp" || GROUPS_NEEDED+=("$grp")
done

if [[ ${#GROUPS_NEEDED[@]} -eq 0 ]]; then
    success "Already in all required groups"
else
    info "Missing groups: ${GROUPS_NEEDED[*]}"
    if ask "Add user to groups: ${GROUPS_NEEDED[*]}?" "y"; then
        sudo usermod -aG "$(IFS=,; echo "${GROUPS_NEEDED[*]}")" "$USER"
        success "Groups added (takes effect on next login)"
    fi
fi

# ── Step 10: Spicetify ────────────────────────────────────────────
step 10 $TOTAL_STEPS "Spicetify"

if command -v spicetify &>/dev/null && [[ -d /opt/spotify ]]; then
    if ask "Configure Spicetify with caelestia theme?" "y"; then
        sudo chmod a+wr /opt/spotify 2>/dev/null || true
        sudo chmod a+wr /opt/spotify/Apps -R 2>/dev/null || true
        spicetify config current_theme caelestia color_scheme caelestia \
            custom_apps marketplace 2>/dev/null || true
        spicetify backup apply 2>/dev/null && success "Spicetify configured" || warn "Run 'spicetify apply' manually after Spotify first launch"
    fi
else
    info "Spotify/Spicetify not found — skipping"
fi

# ── Step 11: Deploy dotfiles ──────────────────────────────────────
header "Deploy dotfiles"

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deploy_item() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    dim "→ $dst"
}

if [[ -d "$DOTS_DIR/config" ]]; then
    if ask "Deploy configs from $DOTS_DIR/config/ to ~/.config/?" "y"; then
        for item in "$DOTS_DIR/config"/*/; do
            [[ -d "$item" ]] || continue
            name="$(basename "$item")"
            deploy_item "$item" "$HOME/.config/$name"
        done
        for f in starship.toml spotify-flags.conf; do
            [[ -f "$DOTS_DIR/config/$f" ]] && deploy_item "$DOTS_DIR/config/$f" "$HOME/.config/$f"
        done
        success "Configs deployed to ~/.config/"
    fi
fi

if [[ -d "$DOTS_DIR/home" ]]; then
    if ask "Deploy home files (.zshrc, scripts) from $DOTS_DIR/home/?" "y"; then
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

if [[ -d "$DOTS_DIR/config/spicetify-theme" ]] && command -v spicetify &>/dev/null; then
    if ask "Deploy Spicetify caelestia theme?" "y"; then
        SPICE="$HOME/.config/spicetify/Themes/caelestia"
        mkdir -p "$SPICE"
        cp -r "$DOTS_DIR/config/spicetify-theme/." "$SPICE/"
        success "Spicetify theme deployed"
    fi
fi

# ── Summary ───────────────────────────────────────────────────────
echo
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  Installation complete!${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "   ${CYAN}1.${NC} ${BOLD}Reboot${NC}"
echo -e "   ${CYAN}2.${NC} After login, set a wallpaper via waypaper"
echo -e "   ${CYAN}3.${NC} Colors will auto-apply via:"
echo -e "      ${DIM}~/.config/hypr/scripts/apply-theme.sh${NC}"
echo
if $DO_BACKUP && [[ -d "$BACKUP_DIR" ]]; then
    echo -e "  ${BOLD}Backup:${NC} $BACKUP_DIR"
    echo
fi
echo -e "  ${BOLD}Key configs:${NC}"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/hypr/"         "Hyprland (keybinds, rules, scripts)"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/foot/"          "Terminal"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/fuzzel/"        "App launcher"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/mako/"          "Notifications"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/matugen/"       "Color scheme templates"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/wlogout/"       "Session manager"
printf "   ${DIM}%-28s${NC} %s\n" "~/.config/fastfetch/"     "Fetch config"
printf "   ${DIM}%-28s${NC} %s\n" "~/.local/bin/"            "Custom scripts"
echo

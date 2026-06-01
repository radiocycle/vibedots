#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  vibedots apply.sh — применяет ~/.config/vibedots/shell.json
#  к Waybar и Hyprland без перезапуска
#  Использование: bash ~/.config/vibedots/apply.sh
# ─────────────────────────────────────────────────────────────────

CONF="$HOME/.config/vibedots/shell.json"
CSS_OUT="$HOME/.config/waybar/vibedots-override.css"
WB_CFG="$HOME/.config/waybar/config.jsonc"

[[ -f "$CONF" ]] || { echo "shell.json not found: $CONF"; exit 1; }

# ── Парсим JSON через Python ──────────────────────────────────────
eval "$(python3 << 'PYEOF'
import json, os
d = json.load(open(os.path.expanduser('~/.config/vibedots/shell.json')))
b = d.get('bar', {})
h = d.get('hyprland', {})
op   = b.get('opacity', 0.85)
ht   = b.get('height', 44)
pills = b.get('pills', True)
wop  = h.get('window_opacity', 0.92)
wrop = h.get('window_rounding', 8)
wiop = round(wop * 0.93, 2)
print(f'BAR_OPACITY={op}')
print(f'BAR_HEIGHT={ht}')
print(f'BAR_PILLS={"true" if pills else "false"}')
print(f'WIN_OPACITY={wop}')
print(f'WIN_INACTIVE={wiop}')
print(f'WIN_ROUNDING={wrop}')
PYEOF
)"

# ── Hyprland ──────────────────────────────────────────────────────
if pgrep -x Hyprland &>/dev/null || pgrep -x hyprland &>/dev/null; then
    hyprctl keyword decoration:rounding         "$WIN_ROUNDING"  &>/dev/null
    hyprctl keyword decoration:active_opacity   "$WIN_OPACITY"   &>/dev/null
    hyprctl keyword decoration:inactive_opacity "$WIN_INACTIVE"  &>/dev/null
fi

# ── Waybar: высота (обновить height в config.jsonc) ──────────────
if [[ -f "$WB_CFG" ]]; then
    python3 - "$WB_CFG" "$BAR_HEIGHT" << 'PYEOF'
import sys, re
path, height = sys.argv[1], sys.argv[2]
with open(path) as f: raw = f.read()
raw = re.sub(r'("height"\s*:\s*)\d+', rf'\g<1>{height}', raw)
with open(path, 'w') as f: f.write(raw)
PYEOF
fi

# ── Waybar: CSS-оверрайд ──────────────────────────────────────────
cat > "$CSS_OUT" << CSSEOF
/* vibedots-override.css — сгенерировано apply.sh, не редактировать вручную */

window#waybar {
    background-color: alpha(@background, ${BAR_OPACITY});
}
CSSEOF

if [[ "$BAR_PILLS" == "false" ]]; then
    cat >> "$CSS_OUT" << 'CSSEOF'

/* Pills отключены */
#pulseaudio, #backlight, #battery, #network,
#bluetooth, #power-profiles-daemon,
#tray, #custom-playerctl, #language,
#clock, #temperature, #cpu, #memory {
    background: transparent;
    border-radius: 0;
    border: none;
    box-shadow: none;
}
CSSEOF
fi

# ── Перезагрузить Waybar ──────────────────────────────────────────
if pgrep -x waybar &>/dev/null; then
    pkill -SIGUSR2 waybar
fi

echo "✓ Applied: opacity=${BAR_OPACITY} height=${BAR_HEIGHT}px pills=${BAR_PILLS} | win_opacity=${WIN_OPACITY} rounding=${WIN_ROUNDING}px"

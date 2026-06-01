#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  vibedots apply.sh — применяет ~/.config/vibedots/shell.json
#  к Waybar и Hyprland
#  Использование: bash ~/.config/vibedots/apply.sh
# ─────────────────────────────────────────────────────────────────

CONF="$HOME/.config/vibedots/shell.json"
CSS_OUT="$HOME/.config/waybar/vibedots-override.css"
WB_CFG="$HOME/.config/waybar/config.jsonc"
LOOK_CONF="$HOME/.config/hypr/conf/look.conf"

[[ -f "$CONF" ]] || { echo "shell.json not found: $CONF"; exit 1; }

# ── Парсим JSON ───────────────────────────────────────────────────
eval "$(python3 << 'PYEOF'
import json, os
d = json.load(open(os.path.expanduser('~/.config/vibedots/shell.json')))
b = d.get('bar', {})
h = d.get('hyprland', {})
tf = lambda v: 'true' if v else 'false'
print(f'BAR_OPACITY={b.get("opacity", 0.85)}')
print(f'BAR_HEIGHT={b.get("height", 44)}')
print(f'BAR_PILLS={tf(b.get("pills", True))}')
wop = h.get('window_opacity', 0.92)
print(f'WIN_OPACITY={wop}')
print(f'WIN_INACTIVE={round(wop * 0.93, 2)}')
print(f'WIN_ROUNDING={h.get("window_rounding", 8)}')
print(f'HYP_BLUR={tf(h.get("blur", True))}')
print(f'HYP_BLUR_SIZE={h.get("blur_size", 8)}')
print(f'HYP_BLUR_PASSES={h.get("blur_passes", 2)}')
print(f'HYP_BLUR_VIBRANCY={h.get("blur_vibrancy", 0.2)}')

# Читаем background из colors.css для rgba()
import re
try:
    css = open(os.path.expanduser('~/.config/waybar/colors.css')).read()
    m = re.search(r'@define-color background\s+(#[0-9a-fA-F]{6})', css)
    if m:
        hx = m.group(1)
        r,g,b = int(hx[1:3],16), int(hx[3:5],16), int(hx[5:7],16)
        print(f'BG_RGBA="{r},{g},{b}"')
    else:
        print('BG_RGBA="26,17,17"')
except:
    print('BG_RGBA="26,17,17"')
PYEOF
)"

HYPR_RUNNING=false
{ pgrep -x Hyprland || pgrep -x hyprland; } &>/dev/null && HYPR_RUNNING=true

# ── look.conf: обновить blur + blurls для персистентности ─────────
python3 - "$LOOK_CONF" \
    "$HYP_BLUR" "$HYP_BLUR_SIZE" "$HYP_BLUR_PASSES" "$HYP_BLUR_VIBRANCY" \
    "$BAR_BLUR" << 'PYEOF'
import sys, re
path, blur, size, passes, vibrancy, bar_blur = sys.argv[1:]
with open(path) as f: c = f.read()

# Обновить поля только внутри блока blur { ... }
def upd_blur(text, field, val):
    def replacer(m):
        return re.sub(rf'(\b{field}\s*=\s*)[\w.]+', rf'\g<1>{val}', m.group(0))
    return re.sub(r'blur\s*\{{[^}}]+\}}', replacer, text, flags=re.DOTALL)

c = upd_blur(c, 'enabled',  blur)
c = upd_blur(c, 'size',     size)
c = upd_blur(c, 'passes',   passes)
c = upd_blur(c, 'vibrancy', vibrancy)

# blurls = waybar
c = re.sub(r'\n# Blur layer surfaces\nblurls = waybar\n?', '', c)
if bar_blur == 'true':
    c = c.rstrip('\n') + '\n\n# Blur layer surfaces\nblurls = waybar\n'

with open(path, 'w') as f: f.write(c)
PYEOF

# ── Hyprland: применить немедленно через keyword ──────────────────
if $HYPR_RUNNING; then
    hyprctl keyword decoration:rounding         "$WIN_ROUNDING"      &>/dev/null
    hyprctl keyword decoration:active_opacity   "$WIN_OPACITY"       &>/dev/null
    hyprctl keyword decoration:inactive_opacity "$WIN_INACTIVE"      &>/dev/null
    hyprctl keyword decoration:blur:enabled     "$HYP_BLUR"          &>/dev/null
    hyprctl keyword decoration:blur:size        "$HYP_BLUR_SIZE"     &>/dev/null
    hyprctl keyword decoration:blur:passes      "$HYP_BLUR_PASSES"   &>/dev/null
    hyprctl keyword decoration:blur:vibrancy    "$HYP_BLUR_VIBRANCY" &>/dev/null
fi

# ── Waybar: высота ────────────────────────────────────────────────
if [[ -f "$WB_CFG" ]]; then
    python3 - "$WB_CFG" "$BAR_HEIGHT" << 'PYEOF'
import sys, re
path, height = sys.argv[1], sys.argv[2]
with open(path) as f: raw = f.read()
raw = re.sub(r'("height"\s*:\s*)\d+', rf'\g<1>{height}', raw)
with open(path, 'w') as f: f.write(raw)
PYEOF
fi

# ── Waybar CSS ────────────────────────────────────────────────────
cat > "$CSS_OUT" << CSSEOF
/* vibedots-override.css — сгенерировано apply.sh */

window#waybar {
    background-color: rgba(${BG_RGBA}, ${BAR_OPACITY});
}
CSSEOF

if [[ "$BAR_PILLS" == "true" ]]; then
    cat >> "$CSS_OUT" << 'CSSEOF'

/* Pills включены — скрыть сепараторы */
#custom-sep {
    font-size: 0px;
    min-width: 0;
    margin: 0;
    padding: 0;
}
CSSEOF
else
    cat >> "$CSS_OUT" << 'CSSEOF'

/* Pills отключены — убрать фон и обводку, показать сепараторы */
#workspaces, #custom-playerctl, #window,
#pulseaudio, #backlight, #battery, #network,
#bluetooth, #power-profiles-daemon,
#tray, #hyprland-language, #language {
    background: transparent;
    border-radius: 0;
    border: none;
    box-shadow: none;
    margin: 0 1px;
    padding: 0 8px;
}

#custom-sep {
    font-size: 15px;
    min-width: 4px;
    padding: 0 4px;
    margin: 0;
}
CSSEOF
fi

# ── Перезапустить Waybar (полный — нужен для blur) ────────────────
if pgrep -x waybar &>/dev/null; then
    pkill -x waybar
    sleep 0.4
    waybar &>/dev/null &
fi

echo "✓ bar: opacity=${BAR_OPACITY} height=${BAR_HEIGHT}px pills=${BAR_PILLS} blur=${BAR_BLUR}"
echo "✓ hyprland: opacity=${WIN_OPACITY} rounding=${WIN_ROUNDING}px blur=${HYP_BLUR} size=${HYP_BLUR_SIZE} passes=${HYP_BLUR_PASSES} vibrancy=${HYP_BLUR_VIBRANCY}"

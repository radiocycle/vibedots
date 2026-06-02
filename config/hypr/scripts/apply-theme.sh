#!/bin/bash
WALLPAPER=$(grep '^wallpaper = ' ~/.config/waypaper/config.ini | head -1 | cut -d= -f2 | xargs | sed "s|~|$HOME|g")

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Wallpaper not found: $WALLPAPER"
    exit 1
fi

# Generate all matugen templates
matugen -t scheme-tonal-spot image "$WALLPAPER" --prefer saturation -q

# Dump JSON palette
TMP=$(mktemp /tmp/matugen.XXXX.json)
matugen -t scheme-tonal-spot image "$WALLPAPER" --prefer saturation --json hex 2>/dev/null > "$TMP"

# Kitty colors
python3 $HOME/.config/hypr/scripts/gen-kitty-colors.py "$TMP"

# Kvantum colors via Python
python3 - "$TMP" << 'PYEOF'
import sys, json, os

data = json.load(open(sys.argv[1]))
c = data["colors"]

def h(key): return c[key]["default"]["color"]

theme_dir = os.path.expanduser("~/.config/Kvantum/MatugenDark")
os.makedirs(theme_dir, exist_ok=True)

# Write KDE-format .colors file
colors_content = f"""[ColorEffects:Disabled]
Color={h("on_surface_variant")[1:]}

[Colors:Button]
BackgroundNormal={h("surface_container_high")[1:]}
BackgroundAlternate={h("surface_container")[1:]}
ForegroundNormal={h("on_surface")[1:]}
ForegroundInactive={h("on_surface_variant")[1:]}
DecorationFocus={h("primary")[1:]}
DecorationHover={h("primary")[1:]}

[Colors:Selection]
BackgroundNormal={h("primary")[1:]}
ForegroundNormal={h("on_primary")[1:]}

[Colors:Tooltip]
BackgroundNormal={h("surface_container_high")[1:]}
ForegroundNormal={h("on_surface")[1:]}

[Colors:View]
BackgroundNormal={h("surface_container_low")[1:]}
BackgroundAlternate={h("surface_container")[1:]}
ForegroundNormal={h("on_surface")[1:]}
ForegroundInactive={h("on_surface_variant")[1:]}
ForegroundLink={h("tertiary")[1:]}
DecorationFocus={h("primary")[1:]}

[Colors:Window]
BackgroundNormal={h("surface")[1:]}
BackgroundAlternate={h("surface_container")[1:]}
ForegroundNormal={h("on_surface")[1:]}
ForegroundInactive={h("on_surface_variant")[1:]}
DecorationFocus={h("primary")[1:]}
"""

with open(f"{theme_dir}/MatugenDark.colors", "w") as f:
    f.write(colors_content)

# Write kvantum theme config (references the colors file)
kvconfig = """[General]
author=matugen
comment=Material You dynamic theme
x11drag=all
alt_mnemonic=true
left_tabs=true
attach_active_tab=false
mirror_doc_tabs=true
group_toolbar_buttons=false
spread_progressbar=true
composite=true
menu_shadow_depth=6
tooltip_shadow_depth=6
splitter_width=7
scroll_width=12
scroll_min_extent=36
slider_width=4
slider_handle_width=18
slider_handle_length=18
tickless_slider_handle_size=18
center_toolbar_handle=true
filled_focus_rectangle=false
button_contents_shift=false
tooltip_delay=-1
vertical_spin_indicators=false
spin_button_width=16

[Hacks]
transparent_dolphin_view=false
blur_konsole=false
"""

with open(f"{theme_dir}/MatugenDark.kvconfig", "w") as f:
    f.write(kvconfig)

print("Kvantum MatugenDark theme written")
PYEOF

rm -f "$TMP"

# Update hyprlock wallpaper path
sed -i "s|^    path = .*|    path = $WALLPAPER|" ~/.config/hypr/hyprlock.conf

# Update hyprlock + wlogout colors from generated palette
python3 $HOME/.config/hypr/scripts/update-lock-theme.py

# spicetify apply убрано — запускай вручную: spicetify apply

# Reload apps
makoctl reload        2>/dev/null
hyprctl reload        2>/dev/null
pkill -SIGUSR2 waybar 2>/dev/null

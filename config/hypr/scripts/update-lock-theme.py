#!/usr/bin/env python3
import re, os

colors_file = os.path.expanduser("~/.config/hypr/colors.conf")
foot_colors = os.path.expanduser("~/.config/foot/colors")
lock_file   = os.path.expanduser("~/.config/hypr/hyprlock.conf")
wlogout_css = os.path.expanduser("~/.config/wlogout/style.css")

def var_hex(var):
    with open(colors_file) as f:
        for line in f:
            m = re.match(rf'\${var}\s*=\s*rgba\(([0-9a-f]{{6}})', line)
            if m: return m.group(1)
    return None

def foot_fg():
    if not os.path.exists(foot_colors): return "dee4e0"
    with open(foot_colors) as f:
        for line in f:
            m = re.match(r'foreground=([0-9a-f]{6})', line)
            if m: return m.group(1)
    return "dee4e0"

def hex_to_rgb(h):
    return f"{int(h[0:2],16)}, {int(h[2:4],16)}, {int(h[4:6],16)}"

primary  = var_hex("color_primary")  or "85d6c2"
surface  = var_hex("color_surface")  or "0e1513"
error    = var_hex("color_error")    or "ffb4ab"
on_surf  = foot_fg()

# ── hyprlock ────────────────────────────────────────────────
content = open(lock_file).read()
content = re.sub(r'(outer_color\s*=\s*)rgba\([0-9a-f]+\)',  f'\\1rgba({primary}cc)', content)
content = re.sub(r'(inner_color\s*=\s*)rgba\([0-9a-f]+\)',  f'\\1rgba({surface}88)', content)
content = re.sub(r'(font_color\s*=\s*)rgba\([0-9a-f]+\)',   f'\\1rgba({on_surf}ff)', content)
content = re.sub(r'(check_color\s*=\s*)rgba\([0-9a-f]+\)',  f'\\1rgba({primary}ff)', content)
content = re.sub(r'(fail_color\s*=\s*)rgba\([0-9a-f]+\)',   f'\\1rgba({error}ff)',   content)
content = re.sub(r'(color = rgba\()[0-9a-f]+(ff\))', f'\\g<1>{on_surf}\\2', content)
content = re.sub(r'(color = rgba\()[0-9a-f]+(cc\))', f'\\g<1>{primary}\\2', content)
content = re.sub(r'(color = rgba\()[0-9a-f]+(88\))', f'\\g<1>{on_surf}\\2', content)
content = re.sub(r'(color = rgba\()[0-9a-f]+(99\))', f'\\g<1>{primary}\\2', content)
open(lock_file, 'w').write(content)

# ── wlogout ──────────────────────────────────────────────────
rgb_surf    = hex_to_rgb(surface)
rgb_primary = hex_to_rgb(primary)
rgb_on_surf = hex_to_rgb(on_surf)

css = f"""* {{
    background-image: none;
    font-family: "JetBrainsMono Nerd Font Mono";
}}

window {{
    background-color: rgba({rgb_surf}, 0.88);
}}

button {{
    color: rgba({rgb_on_surf}, 1.0);
    background-color: rgba({rgb_on_surf}, 0.04);
    border-style: solid;
    border-width: 2px;
    border-color: rgba({rgb_primary}, 0.3);
    border-radius: 12px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 35%;
    font-size: 14px;
    margin: 10px;
}}

button:focus, button:active, button:hover {{
    background-color: rgba({rgb_primary}, 0.2);
    border-color: rgba({rgb_primary}, 0.8);
    color: rgba({rgb_on_surf}, 1.0);
    outline-style: none;
}}

#lock      {{ background-image: image(url("/usr/share/wlogout/icons/lock.png")); }}
#logout    {{ background-image: image(url("/usr/share/wlogout/icons/logout.png")); }}
#suspend   {{ background-image: image(url("/usr/share/wlogout/icons/suspend.png")); }}
#hibernate {{ background-image: image(url("/usr/share/wlogout/icons/hibernate.png")); }}
#shutdown  {{ background-image: image(url("/usr/share/wlogout/icons/shutdown.png")); }}
#reboot    {{ background-image: image(url("/usr/share/wlogout/icons/reboot.png")); }}
"""
open(wlogout_css, 'w').write(css)

print("hyprlock + wlogout colors updated")

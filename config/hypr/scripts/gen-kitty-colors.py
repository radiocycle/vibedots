#!/usr/bin/env python3
import sys, json, colorsys, os

data = json.load(open(sys.argv[1]))
c = data["colors"]

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(int(r*255), int(g*255), int(b*255))

def make_color(target_hue_deg, saturation=0.65, value=0.80):
    """Create a color at a specific hue with given saturation/value."""
    h = target_hue_deg / 360.0
    return rgb_to_hex(*colorsys.hsv_to_rgb(h, saturation, value))

def lighten(hex_color, amount=0.12):
    r, g, b = hex_to_rgb(hex_color)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    v = min(1.0, v + amount)
    s = max(0.0, s - 0.05)
    return rgb_to_hex(*colorsys.hsv_to_rgb(h, s, v))

# Derive saturation hint from source color to match wallpaper vibe
src = c["source_color"]["default"]["color"]
sr, sg, sb = hex_to_rgb(src)
_, src_sat, src_val = colorsys.rgb_to_hsv(sr, sg, sb)
sat = max(0.55, min(0.80, src_sat + 0.1))

# Yellow: fixed at 45° (warm amber/gold)
yellow     = make_color(45,  sat, 0.88)
br_yellow  = lighten(yellow)

# Magenta: fixed at 300° (purple-pink)
magenta    = make_color(300, sat, 0.78)
br_magenta = lighten(magenta)

out = f"""foreground            {c["on_surface"]["default"]["color"]}
background            {c["surface"]["default"]["color"]}
selection_foreground  {c["on_primary_container"]["default"]["color"]}
selection_background  {c["primary_container"]["default"]["color"]}

cursor                {c["primary"]["default"]["color"]}
cursor_text_color     {c["on_primary"]["default"]["color"]}

url_color             {c["tertiary"]["default"]["color"]}

# Black
color0   {c["surface_container_highest"]["default"]["color"]}
color8   {c["surface_bright"]["default"]["color"]}
# Red
color1   {c["error"]["default"]["color"]}
color9   {c["on_error_container"]["default"]["color"]}
# Green  (primary hue)
color2   {c["primary"]["default"]["color"]}
color10  {c["on_primary_container"]["default"]["color"]}
# Yellow  (fixed 45deg warm amber)
color3   {yellow}
color11  {br_yellow}
# Blue  (tertiary)
color4   {c["tertiary"]["default"]["color"]}
color12  {c["tertiary_fixed"]["default"]["color"]}
# Magenta  (fixed 300deg purple-pink)
color5   {magenta}
color13  {br_magenta}
# Cyan  (secondary)
color6   {c["secondary"]["default"]["color"]}
color14  {c["secondary_fixed"]["default"]["color"]}
# White
color7   {c["on_surface_variant"]["default"]["color"]}
color15  {c["on_surface"]["default"]["color"]}
"""

path = os.path.expanduser("~/.config/kitty/colors.conf")
with open(path, "w") as f:
    f.write(out)
print(f"kitty colors: {path}")

#!/usr/bin/env python3
"""Generate the Broadsheet app icon set for macOS."""

from PIL import Image, ImageDraw
import math
import os

OUTPUT_DIR = "Broadsheet/Assets.xcassets/AppIcon.appiconset"

# macOS icon sizes: (point_size, scale, pixel_size)
ICON_SIZES = [
    (16, 1, 16),
    (16, 2, 32),
    (32, 1, 32),
    (32, 2, 64),
    (128, 1, 128),
    (128, 2, 256),
    (256, 1, 256),
    (256, 2, 512),
    (512, 1, 512),
    (512, 2, 1024),
]

# Colors
GREEN = (22, 163, 74)       # #16a34a - accent green
DARK = (26, 26, 26)         # #1a1a1a - primary text
WHITE = (255, 255, 255)
OFF_WHITE = (247, 247, 245) # #f7f7f5
LIGHT_GREEN = (22, 163, 74, 40)


def draw_rounded_rect(draw, bbox, radius, fill):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = bbox
    # Use pieslice for corners and rectangles for the body
    draw.pieslice([x0, y0, x0 + 2*radius, y0 + 2*radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*radius, y0, x1, y0 + 2*radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*radius, x0 + 2*radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*radius, y1 - 2*radius, x1, y1], 0, 90, fill=fill)
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x0 + radius, y1 - radius], fill=fill)
    draw.rectangle([x1 - radius, y0 + radius, x1, y1 - radius], fill=fill)


def draw_icon(size):
    """Draw the Broadsheet icon at the given pixel size."""
    # Work at 4x for antialiasing, then downscale
    scale = 4
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background - rounded square (macOS style)
    margin = int(s * 0.02)
    corner_radius = int(s * 0.22)
    draw_rounded_rect(draw, [margin, margin, s - margin, s - margin], corner_radius, WHITE)

    cx, cy = s // 2, s // 2

    # --- Newspaper page, large and filling most of the icon ---
    paper_w = int(s * 0.62)
    paper_h = int(s * 0.72)
    paper_cx = cx - int(s * 0.04)
    paper_cy = cy - int(s * 0.04)

    # Shadow
    shadow_offset = int(s * 0.012)
    shadow_color = (195, 195, 190)
    draw_rounded_rect(
        draw,
        [paper_cx - paper_w // 2 + shadow_offset,
         paper_cy - paper_h // 2 + shadow_offset,
         paper_cx + paper_w // 2 + shadow_offset,
         paper_cy + paper_h // 2 + shadow_offset],
        int(s * 0.025),
        shadow_color
    )

    # Main paper
    px0 = paper_cx - paper_w // 2
    py0 = paper_cy - paper_h // 2
    px1 = paper_cx + paper_w // 2
    py1 = paper_cy + paper_h // 2
    draw_rounded_rect(draw, [px0, py0, px1, py1], int(s * 0.025), OFF_WHITE)

    # Fold line
    fold_y = paper_cy
    fold_t = max(1, int(s * 0.004))
    draw.rectangle(
        [px0 + int(s * 0.04), fold_y - fold_t, px1 - int(s * 0.04), fold_y + fold_t],
        fill=(215, 215, 210)
    )

    # Content lines on the newspaper
    line_color = (190, 190, 185)
    lx0 = px0 + int(s * 0.06)
    lx1 = px1 - int(s * 0.06)
    line_h = max(1, int(s * 0.009))

    # Headline bar (green)
    hl_y = py0 + int(s * 0.055)
    hl_h = max(2, int(s * 0.028))
    draw.rectangle([lx0, hl_y, lx1, hl_y + hl_h], fill=GREEN)

    # A few body lines in top half
    body_y = hl_y + hl_h + int(s * 0.03)
    spacing = int(s * 0.024)
    widths_top = [0.55, 1.0, 0.8, 1.0, 0.6]
    for i, w in enumerate(widths_top):
        ly = body_y + i * spacing
        if ly + line_h > fold_y - int(s * 0.02):
            break
        draw.rectangle([lx0, ly, lx0 + int((lx1 - lx0) * w), ly + line_h], fill=line_color)

    # Small green section bar + lines in bottom half
    bot_y = fold_y + int(s * 0.03)
    bar_h = max(2, int(s * 0.02))
    draw.rectangle([lx0, bot_y, lx0 + int((lx1 - lx0) * 0.3), bot_y + bar_h], fill=GREEN)

    bot_body = bot_y + bar_h + int(s * 0.025)
    widths_bot = [1.0, 0.75, 1.0]
    for i, w in enumerate(widths_bot):
        ly = bot_body + i * spacing
        if ly + line_h > py1 - int(s * 0.04):
            break
        draw.rectangle([lx0, ly, lx0 + int((lx1 - lx0) * w), ly + line_h], fill=line_color)

    # --- Large, prominent RSS signal badge ---
    # Positioned bottom-right, overlapping the newspaper substantially
    badge_r = int(s * 0.20)
    badge_cx = cx + int(s * 0.18)
    badge_cy = cy + int(s * 0.18)

    # White ring around badge for separation
    ring_r = badge_r + int(s * 0.02)
    draw.ellipse(
        [badge_cx - ring_r, badge_cy - ring_r,
         badge_cx + ring_r, badge_cy + ring_r],
        fill=WHITE
    )

    # Green circle
    draw.ellipse(
        [badge_cx - badge_r, badge_cy - badge_r,
         badge_cx + badge_r, badge_cy + badge_r],
        fill=GREEN
    )

    # RSS icon inside - centered in the green circle
    # The RSS icon's visual center is between the dot and outer arc,
    # so we offset the origin point from badge center to visually center it
    rss_ox = badge_cx - int(s * 0.085)
    rss_oy = badge_cy + int(s * 0.085)

    # Dot
    dot_r = int(s * 0.038)
    draw.ellipse(
        [rss_ox - dot_r, rss_oy - dot_r, rss_ox + dot_r, rss_oy + dot_r],
        fill=WHITE
    )

    # Arc 1 (inner)
    arc1_r = int(s * 0.105)
    arc_w = max(4, int(s * 0.035))
    draw.arc(
        [rss_ox - arc1_r, rss_oy - arc1_r, rss_ox + arc1_r, rss_oy + arc1_r],
        start=270, end=360, fill=WHITE, width=arc_w
    )

    # Arc 2 (outer)
    arc2_r = int(s * 0.17)
    draw.arc(
        [rss_ox - arc2_r, rss_oy - arc2_r, rss_ox + arc2_r, rss_oy + arc2_r],
        start=270, end=360, fill=WHITE, width=arc_w
    )

    # Downscale with high-quality resampling
    img = img.resize((size, size), Image.LANCZOS)
    return img


def generate_contents_json():
    """Generate the Contents.json with filenames."""
    images = []
    for pt_size, scale, px_size in ICON_SIZES:
        if scale == 1:
            filename = f"AppIcon-{pt_size}x{pt_size}.png"
        else:
            filename = f"AppIcon-{pt_size}x{pt_size}@{scale}x.png"
        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{pt_size}x{pt_size}"
        })
    return {
        "images": images,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for pt_size, scale, px_size in ICON_SIZES:
        img = draw_icon(px_size)
        if scale == 1:
            filename = f"AppIcon-{pt_size}x{pt_size}.png"
        else:
            filename = f"AppIcon-{pt_size}x{pt_size}@{scale}x.png"
        filepath = os.path.join(OUTPUT_DIR, filename)
        img.save(filepath, "PNG")
        print(f"  {filename} ({px_size}x{px_size}px)")

    # Write Contents.json
    import json
    contents = generate_contents_json()
    contents_path = os.path.join(OUTPUT_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"\n  Contents.json updated")
    print(f"\nAll icons saved to {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()

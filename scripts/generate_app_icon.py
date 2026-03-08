#!/usr/bin/env python3
"""Generate app icon PNGs from the brand design.

Produces a 1024x1024 PNG matching the favicon.svg design:
- Rounded rectangle background with forest green gradient
- Gold-gradient roof triangle
- White house body
- Mint-green door and windows

Usage:
    python scripts/generate_app_icon.py
"""
import math
from PIL import Image, ImageDraw

SIZE = 1024
SCALE = SIZE / 200  # Original SVG viewBox is 200x200


def scaled(val):
    return int(val * SCALE)


def draw_rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    r = radius
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.pieslice([x0, y0, x0 + 2 * r, y0 + 2 * r], 180, 270, fill=fill)
    draw.pieslice([x1 - 2 * r, y0, x1, y0 + 2 * r], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2 * r, x0 + 2 * r, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2 * r, y1 - 2 * r, x1, y1], 0, 90, fill=fill)


def create_gradient_image(size, color1, color2, direction='diagonal'):
    """Create a gradient image."""
    img = Image.new('RGBA', size)
    pixels = img.load()
    w, h = size
    for y in range(h):
        for x in range(w):
            if direction == 'diagonal':
                t = (x / w + y / h) / 2
            else:
                t = y / h
            r = int(color1[0] + (color2[0] - color1[0]) * t)
            g = int(color1[1] + (color2[1] - color1[1]) * t)
            b = int(color1[2] + (color2[2] - color1[2]) * t)
            pixels[x, y] = (r, g, b, 255)
    return img


def main():
    # Colors from the brand palette
    forest_deep = (0x1A, 0x3C, 0x2E)
    forest_mid = (0x2D, 0x6A, 0x4F)
    gold_warm = (0xE5, 0xA0, 0x4A)
    gold_ember = (0xC9, 0x87, 0x2A)
    forest_mist = (0xD8, 0xF3, 0xDC)
    white = (255, 255, 255)

    # Create the background gradient
    img = create_gradient_image((SIZE, SIZE), forest_mid, forest_deep, 'diagonal')
    draw = ImageDraw.Draw(img)

    # Mask to rounded rectangle
    mask = Image.new('L', (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = scaled(42)
    draw_rounded_rect(mask_draw, (0, 0, SIZE, SIZE), corner_radius, fill=255)

    # Apply the rounded mask
    bg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bg.paste(img, (0, 0), mask)
    img = bg
    draw = ImageDraw.Draw(img)

    # House body (white rectangle) - from SVG: x=58, y=102, w=84, h=60
    body_x = scaled(58)
    body_y = scaled(102)
    body_w = scaled(84)
    body_h = scaled(60)
    body_r = scaled(4)
    draw_rounded_rect(draw, (body_x, body_y, body_x + body_w, body_y + body_h), body_r,
                       fill=(*white, int(0.92 * 255)))

    # Roof (gold triangle) - from SVG: points="100,42 152,102 48,102"
    roof_points = [
        (scaled(100), scaled(42)),
        (scaled(152), scaled(102)),
        (scaled(48), scaled(102)),
    ]
    # Create a gradient for the roof
    roof_img = create_gradient_image((SIZE, SIZE), gold_warm, gold_ember, 'diagonal')
    roof_mask = Image.new('L', (SIZE, SIZE), 0)
    roof_mask_draw = ImageDraw.Draw(roof_mask)
    roof_mask_draw.polygon(roof_points, fill=255)
    img.paste(roof_img, (0, 0), roof_mask)
    draw = ImageDraw.Draw(img)

    # Door (forest green rectangle) - from SVG: x=82, y=126, w=36, h=36
    door_x = scaled(82)
    door_y = scaled(126)
    door_w = scaled(36)
    door_h = scaled(36)
    door_r = scaled(4)
    draw_rounded_rect(draw, (door_x, door_y, door_x + door_w, door_y + door_h), door_r,
                       fill=(*forest_mid, 255))

    # Left window - from SVG: x=63, y=110, w=15, h=13
    win_color = (*forest_mist, int(0.8 * 255))
    lw_x, lw_y, lw_w, lw_h = scaled(63), scaled(110), scaled(15), scaled(13)
    lw_r = scaled(2)
    draw_rounded_rect(draw, (lw_x, lw_y, lw_x + lw_w, lw_y + lw_h), lw_r, fill=win_color)

    # Right window - from SVG: x=122, y=110, w=15, h=13
    rw_x, rw_y, rw_w, rw_h = scaled(122), scaled(110), scaled(15), scaled(13)
    draw_rounded_rect(draw, (rw_x, rw_y, rw_x + rw_w, rw_y + rw_h), lw_r, fill=win_color)

    # Save the icon
    output_path = 'my_app/assets/images/app_icon_1024.png'
    img.save(output_path, 'PNG')
    print(f'✅ Generated {output_path} ({SIZE}x{SIZE})')

    # Also generate web favicon PNG for older browsers
    favicon_32 = img.resize((32, 32), Image.LANCZOS)
    favicon_32.save('static/img/favicon-32.png', 'PNG')
    print('✅ Generated static/img/favicon-32.png (32x32)')

    favicon_180 = img.resize((180, 180), Image.LANCZOS)
    favicon_180.save('static/img/apple-touch-icon.png', 'PNG')
    print('✅ Generated static/img/apple-touch-icon.png (180x180)')

    favicon_192 = img.resize((192, 192), Image.LANCZOS)
    favicon_192.save('static/img/icon-192.png', 'PNG')
    print('✅ Generated static/img/icon-192.png (192x192)')

    favicon_512 = img.resize((512, 512), Image.LANCZOS)
    favicon_512.save('static/img/icon-512.png', 'PNG')
    print('✅ Generated static/img/icon-512.png (512x512)')


if __name__ == '__main__':
    main()

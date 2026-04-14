#!/usr/bin/env python3
"""Generate the default OpenGraph / Twitter share image.

Produces static/img/og-default.jpg at 1200x630 with the brand's forest-green
gradient background, the logo mark, and the headline tagline.

Usage:
    python scripts/generate_og_image.py
"""
from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 1200, 630
OUTPUT_PATH = 'static/img/og-default.jpg'

# Brand palette (matches the SVG logo)
FOREST_DEEP = (0x11, 0x5E, 0x66)
FOREST_MID = (0x19, 0x74, 0x7E)
GOLD_WARM = (0xD8, 0x94, 0x3B)
GOLD_EMBER = (0xD5, 0x91, 0x37)
MIST = (0xD1, 0xE8, 0xE2)
WHITE = (255, 255, 255)


def create_gradient(size, color1, color2):
    """Create a diagonal gradient image."""
    img = Image.new('RGB', size)
    pixels = img.load()
    w, h = size
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            r = int(color1[0] + (color2[0] - color1[0]) * t)
            g = int(color1[1] + (color2[1] - color1[1]) * t)
            b = int(color1[2] + (color2[2] - color1[2]) * t)
            pixels[x, y] = (r, g, b)
    return img


def load_font(size):
    """Load a system serif font with a sans-serif fallback."""
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVu-Serif-Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def main():
    img = create_gradient((WIDTH, HEIGHT), FOREST_MID, FOREST_DEEP)
    draw = ImageDraw.Draw(img, 'RGBA')

    # House logo mark — scaled and positioned to the left
    # Original SVG viewBox is roughly 90x100, scale up ~4.2x to ~378 height
    cx, cy, scale = 230, 250, 3.6

    def s(v):
        return int(v * scale)

    # House body
    body = (cx - s(27), cy - s(4), cx + s(27), cy + s(34))
    draw.rectangle(body, fill=(*WHITE, 38))

    # Roof — gold triangle
    roof = [
        (cx, cy - s(38)),
        (cx + s(35), cy - s(4)),
        (cx - s(35), cy - s(4)),
    ]
    # Approximate gradient with two-tone fill
    draw.polygon(roof, fill=GOLD_WARM)

    # Door
    door = (cx - s(10), cy + s(12), cx + s(10), cy + s(34))
    draw.rectangle(door, fill=(*MIST, 230))
    draw.ellipse((cx + s(5), cy + s(22), cx + s(7), cy + s(24)), fill=FOREST_DEEP)

    # Windows
    draw.rectangle((cx - s(23), cy + s(2), cx - s(13), cy + s(11)),
                   fill=(*WHITE, 100))
    draw.rectangle((cx + s(13), cy + s(2), cx + s(23), cy + s(11)),
                   fill=(*WHITE, 100))

    # Chimney
    draw.rectangle((cx + s(17), cy - s(28), cx + s(25), cy - s(10)), fill=FOREST_DEEP)

    # Headline text
    title_font = load_font(78)
    sub_font = load_font(36)
    tag_font = load_font(28)

    text_x = 460
    draw.text((text_x, 180), 'For Sale', font=title_font, fill=WHITE)
    draw.text((text_x, 270), 'By Owner', font=title_font, fill=MIST)

    # Divider line
    draw.line((text_x, 380, text_x + 600, 380), fill=(*WHITE, 80), width=2)

    draw.text((text_x, 400), 'Sell direct. Keep more.', font=sub_font, fill=MIST)
    draw.text((text_x, 460),
              'No estate agent fees. No commission. List free.',
              font=tag_font, fill=(*WHITE, 220))

    # Domain footer
    footer_font = load_font(22)
    draw.text((text_x, 540), 'for-sale-by-owner.co.uk',
              font=footer_font, fill=(*MIST, 200))

    img.save(OUTPUT_PATH, 'JPEG', quality=88, optimize=True, progressive=True)
    print(f'Generated {OUTPUT_PATH} ({WIDTH}x{HEIGHT})')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Store graphics for "Human or AI?": Google Play and App Store screenshots
with headlines, and the Google Play feature graphic.

    python3 store/make_store_graphics.py

Sources are full-resolution emulator screenshots in store/source/ (1080x2400).
Needs Pillow and macOS (SF Pro and Hiragino Sans from /System/Library/Fonts).
Headlines come in English, Polish and Japanese (COPY); the game UI is English.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "source"
ICON = ROOT / "icon-512.png"
FONT = "/System/Library/Fonts/SFNS.ttf"
JA_FONTS = {900: "/System/Library/Fonts/ヒラギノ角ゴシック W9.ttc", 700: "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc"}

BG = (124, 58, 237)  # #7C3AED, a stronger take on the app's "AI" violet
RAY = (142, 82, 245)  # lighter violet for the rays behind the phone
WHITE = (255, 255, 255)
YELLOW = (251, 191, 36)  # the app's combo colour

# Parts of a source screenshot that are blown up and pulled out of the phone
# ("breakouts"), in source pixels (1080x2400): box, corner radius, tilt.
PANEL_RADIUS = 52
AI_STAMP = ((276, 1671, 806, 1798), 64, -5)
HUMAN_STAMP_VIDEO = ((284, 1524, 796, 1650), 64, -5)
REVEAL_PANEL = ((43, 1889, 1038, 2311), PANEL_RADIUS, 0)
MUSIC_PANEL = ((43, 1831, 1038, 2311), PANEL_RADIUS, 0)
SCORE_CARD = ((55, 588, 1028, 1350), 70, 0)

# Order = order in the store. Screenshot 1 carries the main reason to download.
# (slug, source, breakout)
SHOTS = [
    ("01-spot-ai-fakes", "reveal-image.jpg", AI_STAMP),
    ("02-learn-the-tells", "reveal-tip.jpg", REVEAL_PANEL),
    ("03-test-your-ears", "music.jpg", MUSIC_PANEL),
    ("04-watch-closely", "video.jpg", HUMAN_STAMP_VIDEO),
    ("05-beat-your-best", "game-over.jpg", SCORE_CARD),
]

# Text per store language: for every shot (white words, yellow words,
# descriptor), the gap between the two headline parts, and the tagline of the
# feature graphic.
COPY = {
    "en-US": {
        "gap": " ",
        "shots": [
            ("SPOT", "AI FAKES", "IN PHOTOS, VIDEOS & MUSIC"),
            ("LEARN", "THE TELLS", "A QUICK TIP AFTER EVERY ANSWER"),
            ("TEST", "YOUR EARS", "AI SONG OR REAL ARTIST?"),
            ("WATCH", "CLOSELY", "REAL FOOTAGE OR AI CLIP?"),
            ("BEAT", "YOUR BEST", "SEE WHAT YOU SPOT AND MISS"),
        ],
        "tagline": ("Spot AI fakes in photos,", "videos and music."),
    },
    "pl-PL": {
        "gap": " ",
        "shots": [
            ("WYŁAP", "FAŁSZYWKI AI", "ZDJĘCIA, FILMY I MUZYKA"),
            ("POZNAJ", "ZNAKI AI", "WSKAZÓWKA PO KAŻDEJ ODPOWIEDZI"),
            ("WYTĘŻ", "SŁUCH", "AI CZY PRAWDZIWY ARTYSTA?"),
            ("PATRZ", "UWAŻNIE", "PRAWDZIWE NAGRANIE CZY AI?"),
            ("POBIJ", "SWÓJ REKORD", "SPRAWDŹ SWOJĄ SKUTECZNOŚĆ"),
        ],
        "tagline": ("Wyłap fałszywki AI na zdjęciach,", "w filmach i w muzyce."),
    },
    "ja-JP": {
        "gap": "",
        "shots": [
            ("AIの", "フェイクを見抜け", "写真・動画・音楽で勝負"),
            ("毎回", "ヒント付き", "AIを見抜くコツが身につく"),
            ("耳で", "聞き分けろ", "AIの曲?本物のアーティスト?"),
            ("目を", "凝らせ", "本物の映像?それともAI動画?"),
            ("自己ベストを", "更新せよ", "得意・苦手がひと目でわかる"),
        ],
        "tagline": ("写真・動画・音楽の", "AIフェイクを見抜け。"),
    },
}

# (folder, width, height, device style, languages). English is the default
# listing; Polish and Japanese get their own Google Play sets.
SETS = [
    ("google-play/phone", 1080, 1920, "android", "en-US"),
    ("google-play/pl-PL/phone", 1080, 1920, "android", "pl-PL"),
    ("google-play/ja-JP/phone", 1080, 1920, "android", "ja-JP"),
    ("app-store/iphone-6.9", 1320, 2868, "iphone", "en-US"),
    ("app-store/iphone-6.5", 1242, 2688, "iphone", "en-US"),
]

LANG = "en-US"  # language of the text being drawn; set per set

SS = 3  # supersampling for smooth device edges


def font(size, weight=900):
    if LANG == "ja-JP":
        return ImageFont.truetype(JA_FONTS[900 if weight >= 850 else 700], size)
    f = ImageFont.truetype(FONT, size)
    # Axes of SF Pro: width, optical size, grade, weight.
    f.set_variation_by_axes([100, min(96, max(17, size)), 400, weight])
    return f


def text_width(text, f):
    return f.getbbox(text)[2] - f.getbbox(text)[0]


def fit_size(texts, max_w, start, weight):
    """Largest size at which every text fits on one line; shared by the whole set."""
    size = start
    while size > 10 and any(text_width(t, font(size, weight)) > max_w for t in texts):
        size -= 2
    return size


def wrap(text, f, max_w):
    if " " not in text:
        return [text]
    lines, line = [], ""
    for word in text.split():
        test = f"{line} {word}".strip()
        if line and text_width(test, f) > max_w:
            lines.append(line)
            line = word
        else:
            line = test
    lines.append(line)
    return lines


def rounded_mask(size, radius, inset=0):
    w, h = size
    big = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (inset * SS, inset * SS, (w - inset) * SS - 1, (h - inset) * SS - 1), radius * SS, fill=255
    )
    return big.resize((w, h), Image.LANCZOS)


def ios_status_bar(screen):
    """Replaces the Android status bar with an iPhone one (time, Dynamic Island, icons)."""
    w, h = screen.size
    bar_h = round(w * 0.125)
    # Extend the app background upwards over the old status bar.
    row = screen.crop((0, bar_h, w, bar_h + 1)).resize((w, bar_h))
    screen.paste(row, (0, 0))
    d = ImageDraw.Draw(screen)
    cy = round(w * 0.062)
    f = font(round(w * 0.043), 640)
    d.text((round(w * 0.135), cy), "9:41", font=f, fill=WHITE, anchor="mm")
    # Battery
    bw, bh = round(w * 0.06), round(w * 0.028)
    bx = round(w * 0.87) - bw // 2
    d.rounded_rectangle((bx, cy - bh // 2, bx + bw, cy + bh // 2), round(bh * 0.3), outline=(255, 255, 255, 140), width=max(2, w // 400))
    pad = max(3, w // 300)
    d.rounded_rectangle((bx + pad, cy - bh // 2 + pad, bx + bw - pad, cy + bh // 2 - pad), round(bh * 0.2), fill=WHITE)
    d.rounded_rectangle((bx + bw + 2, cy - bh // 6, bx + bw + 2 + max(3, w // 260), cy + bh // 6), 2, fill=(255, 255, 255, 140))
    # Wi-Fi: three arcs
    wx, wy = round(w * 0.785), cy + round(w * 0.012)
    for i, r in enumerate((w * 0.032, w * 0.022, w * 0.012)):
        r = round(r)
        if i < 2:
            d.arc((wx - r, wy - r, wx + r, wy + r), 225, 315, fill=WHITE, width=max(3, round(w * 0.0065)))
        else:
            d.pieslice((wx - r, wy - r, wx + r, wy + r), 225, 315, fill=WHITE)
    # Signal bars
    sx = round(w * 0.69)
    for i in range(4):
        bar = round(w * 0.008 + i * w * 0.0055)
        x = sx + i * round(w * 0.0105)
        d.rounded_rectangle((x, cy + round(w * 0.013) - bar, x + round(w * 0.0075), cy + round(w * 0.013)), 2, fill=WHITE)
    # Dynamic Island
    iw, ih = round(w * 0.29), round(w * 0.085)
    top = round(w * 0.022)
    d.rounded_rectangle(((w - iw) // 2, top, (w + iw) // 2, top + ih), ih // 2, fill=(0, 0, 0))
    return screen


def device(shot, screen_w, style):
    """The screenshot inside a phone frame, as RGBA."""
    src = Image.open(SRC / shot).convert("RGB")
    screen_h = round(screen_w * src.height / src.width)
    screen = src.resize((screen_w, screen_h), Image.LANCZOS)

    if style == "iphone":
        screen = ios_status_bar(screen)
        bezel, radius, rim = round(screen_w * 0.032), round(screen_w * 0.125), round(screen_w * 0.009)
    else:
        bezel, radius, rim = round(screen_w * 0.024), round(screen_w * 0.075), round(screen_w * 0.007)

    w, h = screen_w + 2 * bezel, screen_h + 2 * bezel
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Metal rim, then the black glass edge.
    body.paste((58, 58, 70, 255), (0, 0, w, h), rounded_mask((w, h), radius + bezel))
    body.paste((10, 10, 13, 255), (0, 0, w, h), rounded_mask((w, h), radius + bezel, inset=rim))
    body.paste(screen, (bezel, bezel), rounded_mask((screen_w, screen_h), radius))

    if style == "android":
        d = ImageDraw.Draw(body)
        r = round(screen_w * 0.017)
        cx, cy = w // 2, bezel + round(screen_w * 0.032)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(5, 5, 8))
    else:
        # Side buttons
        d = ImageDraw.Draw(body)
        bw = max(3, rim)
        for y0, y1 in ((0.17, 0.21), (0.25, 0.33), (0.35, 0.43)):
            d.rectangle((0, round(h * y0), bw, round(h * y1)), fill=(70, 70, 82, 255))
        d.rectangle((w - bw, round(h * 0.27), w, round(h * 0.38)), fill=(70, 70, 82, 255))
    return body


def rays(canvas, center, count=28):
    """Sunburst behind the phone: alternating wedges of two violets."""
    W, H = canvas.size
    big = Image.new("RGB", (W * 2, H * 2), BG)
    d = ImageDraw.Draw(big)
    cx, cy = center[0] * 2, center[1] * 2
    r = (W + H) * 2
    step = 360 / count
    for i in range(0, count, 2):
        d.pieslice((cx - r, cy - r, cx + r, cy + r), i * step, (i + 1) * step, fill=RAY)
    canvas.paste(big.resize((W, H), Image.LANCZOS), (0, 0))


def sparkle(d, cx, cy, r, color):
    """Four-point star."""
    k = r * 0.22
    d.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)], fill=color)


def breakout_piece(shot, spec, width):
    """A UI element cut out of the screenshot, scaled to [width], rounded and tilted."""
    box, radius, tilt = spec
    src = Image.open(SRC / shot).convert("RGB").crop(box)
    k = width / src.width
    piece = src.resize((width, round(src.height * k)), Image.LANCZOS).convert("RGBA")
    piece.putalpha(rounded_mask(piece.size, round(radius * k)))
    if tilt:
        piece = piece.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return piece


def paste_with_shadow(canvas, item, xy, blur, strength=0.45):
    x, y = xy
    alpha = item.split()[3]
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    mask = Image.new("L", canvas.size, 0)
    mask.paste(alpha.point(lambda a: a * strength), (x, y + blur // 2))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(item, (x, y))


def screenshot_set(folder, W, H, style, lang):
    global LANG
    LANG = lang
    copy = COPY[lang]
    gap = copy["gap"]
    out = ROOT / folder
    out.mkdir(parents=True, exist_ok=True)
    max_w = round(W * 0.9)
    verb_size = fit_size([f"{a}{gap}{b}" for a, b, _ in copy["shots"]], max_w, round(W * 0.14), 900)
    # Descriptors stay on one line where possible: shrink a little before wrapping.
    descs = [desc for _, _, desc in copy["shots"]]
    desc_size = max(fit_size(descs, round(W * 0.86), round(W * 0.05), 760), round(W * 0.042))
    df = font(desc_size, 760)
    # The phone sits at the same height on every shot of the set.
    desc_lines = max(len(wrap(desc, df, round(W * 0.86))) for _, _, desc in copy["shots"])
    ascent, descent = font(verb_size, 900).getmetrics()
    head = round(ascent * 0.92) + round(descent * 0.75) + round(verb_size * 0.1)
    top = round(H * 0.045) + head + round(desc_size * 1.22) * desc_lines + round(H * 0.028)
    for (slug, shot, spec), (white, yellow, desc) in zip(SHOTS, copy["shots"]):
        canvas = Image.new("RGBA", (W, H), BG + (255,))
        rays(canvas, (W // 2, round(H * 0.56)))
        d = ImageDraw.Draw(canvas)
        y = round(H * 0.045)
        vf = font(verb_size, 900)
        # Headline: first word(s) white, the rest in yellow.
        space = text_width(f"{white}{gap}", vf) - text_width(white, vf) if gap else 0
        total = text_width(white, vf) + space + text_width(yellow, vf)
        x = (W - total) // 2
        # Both parts on one baseline, so accents (Ż, Ó) do not push a part down.
        ascent, descent = vf.getmetrics()
        base = y + round(ascent * 0.92)
        d.text((x, base), white, font=vf, fill=WHITE, anchor="ls")
        d.text((x + text_width(white, vf) + space, base), yellow, font=vf, fill=YELLOW, anchor="ls")
        y = base + round(descent * 0.75) + round(verb_size * 0.1)
        for line in wrap(desc, df, round(W * 0.86)):
            d.text((W // 2, y), line, font=df, fill=WHITE, anchor="mt")
            y += round(desc_size * 1.22)

        # The bottom of the phone runs off the canvas; the breakout repeats
        # the part that matters, blown up, in front of it.
        src = Image.open(SRC / shot)
        # Sized so that every breakout sits right on top of its original.
        screen_w = round(W * (0.64 if style == "android" else 0.8))
        phone = device(shot, screen_w, style)
        px = (W - phone.width) // 2
        paste_with_shadow(canvas, phone, (px, top), round(W * 0.03))

        bezel = round(screen_w * (0.032 if style == "iphone" else 0.024))
        scale = screen_w / src.width
        box = spec[0]
        piece_w = round(W * (0.8 if spec[1] >= 60 and box[3] - box[1] < 200 else 0.92))
        piece = breakout_piece(shot, spec, piece_w)
        cy = top + bezel + round((box[1] + box[3]) / 2 * scale)
        cy = min(cy, H - piece.height // 2 - round(H * 0.012))
        paste_with_shadow(canvas, piece, ((W - piece.width) // 2, cy - piece.height // 2), round(W * 0.028), 0.6)

        d = ImageDraw.Draw(canvas)
        sparkle(d, round(W * 0.07), cy - piece.height // 2 - round(W * 0.03), round(W * 0.03), YELLOW)
        sparkle(d, round(W * 0.93), cy + piece.height // 2 + round(W * 0.02), round(W * 0.024), WHITE)
        sparkle(d, round(W * 0.9), top + round(W * 0.06), round(W * 0.018), WHITE)
        canvas.convert("RGB").save(out / f"{slug}.png", optimize=True)
        print(out / f"{slug}.png", (W, H))


def feature_graphic(lang):
    global LANG
    W, H = 1024, 500
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    rays(canvas, (760, 330), count=32)
    d = ImageDraw.Draw(canvas)

    icon = Image.open(ICON).convert("RGB").resize((104, 104), Image.LANCZOS)
    canvas.paste(icon, (64, 86), rounded_mask((104, 104), 24))
    LANG = "en-US"  # the name stays English in every language
    tf = font(76, 900)
    d.text((60, 214), "Human or", font=tf, fill=WHITE)
    d.text((60 + text_width("Human or ", tf), 214), "AI?", font=tf, fill=YELLOW)
    LANG = lang
    sf = font(30 if lang != "ja-JP" else 28, 760)
    for i, line in enumerate(COPY[lang]["tagline"]):
        d.text((64, 318 + i * 40), line, font=sf, fill=WHITE)

    back = device("music.jpg", 214, "android")
    front = device("reveal-image.jpg", 236, "android")
    paste_with_shadow(canvas, back, (W - back.width - 34, 112), 16)
    fx, fy = W - front.width - 200, 46
    paste_with_shadow(canvas, front, (fx, fy), 18)
    # The phone's own stamp, blown up right on top of it.
    stamp = breakout_piece("reveal-image.jpg", AI_STAMP, 330)
    box = AI_STAMP[0]
    sy = fy + round(236 * 0.024) + round((box[1] + box[3]) / 2 * 236 / 1080)
    paste_with_shadow(canvas, stamp, (fx + front.width // 2 - stamp.width // 2, sy - stamp.height // 2), 12, 0.6)
    d = ImageDraw.Draw(canvas)
    sparkle(d, 560, 70, 16, YELLOW)
    sparkle(d, 990, 70, 11, WHITE)
    sparkle(d, 520, 440, 10, WHITE)
    out = ROOT / "google-play" / ("" if lang == "en-US" else lang) / "feature-graphic.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, optimize=True)
    print(out, (W, H))


if __name__ == "__main__":
    for folder, W, H, style, lang in SETS:
        screenshot_set(folder, W, H, style, lang)
    for lang in COPY:
        feature_graphic(lang)

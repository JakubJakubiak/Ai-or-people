#!/usr/bin/env python3
"""30-second vertical promo (TikTok / Reels / Shorts) for "Human or AI?".

    python3 store/video/make_promo.py <gameplay.mp4>

The gameplay recording is a 1080x2400 emulator capture
(`adb shell screenrecord`). Output: store/video/promo-30s.mp4 (1080x1920,
30 fps, H.264 + AAC). The music and sound effects are synthesised here, so
the video has no third-party audio; on TikTok/Instagram a trending sound can
be laid on top instead.
"""
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import make_store_graphics as g  # noqa: E402  (fonts, colours, rays, masks)

W, H, FPS = 1080, 1920, 30
SRC_W, SRC_H = 1080, 2400
OUT = HERE / "promo-30s.mp4"
BPM = 120
SR = 44100

# Media card inside the game screen (source pixels), used for full-bleed shots.
CARD = (43, 530, 1037, 1880)

# Timeline. Each scene: (kind, start in source seconds, duration, captions)
# captions: list of (from, to, white, yellow) in scene seconds.
SCENES = [
    ("hook", 27.0, 2.5, [(0.0, 2.5, "CAN YOU SPOT", "THE AI?")]),
    ("quiz", 28.4, 4.0, [(0.0, 2.1, "HUMAN", "OR AI?"), (2.1, 4.0, "IT'S", "AI.")]),
    ("phone", 64.5, 3.0, [(0.0, 1.9, "AND", "THIS ONE?"), (1.9, 3.0, "100%", "REAL")]),
    ("phone", 134.4, 3.0, [(0.0, 1.9, "TOO", "PERFECT?"), (1.9, 3.0, "AI.", "AGAIN.")]),
    ("phone", 90.4, 3.0, [(0.0, 1.9, "AI MUSIC", "TOO"), (1.9, 3.0, "REAL", "ARTIST")]),
    ("fail", 69.0, 3.0, [(0.0, 1.9, "EASY,", "RIGHT?"), (1.9, 3.0, "WRONG.", "IT WAS AI")]),
    ("montage", 0, 3.0, [(0.0, 3.0, "PHOTOS · VIDEOS", "· MUSIC")]),
    ("tip", 30.9, 3.0, [(0.0, 3.0, "LEARN", "THE TELLS")]),
    ("end", 0, 5.5, []),
]
MONTAGE = [111.9, 154.5, 160.0, 142.0, 25.1]  # reveal frames, 0.6 s each
# Scene-relative moments that get a sound effect.
DING = {1: 2.1, 2: 1.9, 3: 1.9, 4: 1.9}
BUZZ = {5: 1.9}


def read_frames(video, start, dur):
    """Frames of the gameplay recording as PIL images (30 fps)."""
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-t", f"{dur:.3f}", "-i", str(video),
           "-vf", f"fps={FPS}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = SRC_W * SRC_H * 3
    frames = []
    while True:
        b = p.stdout.read(size)
        if len(b) < size:
            break
        frames.append(Image.frombuffer("RGB", (SRC_W, SRC_H), b))
    p.wait()
    n = round(dur * FPS)
    while len(frames) < n:
        frames.append(frames[-1])
    return frames[:n]


def ease_out_back(t):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2


class Stage:
    """Things drawn on every frame: rotating rays, phone body, captions."""

    def __init__(self):
        big = Image.new("RGB", (2600, 2600), g.BG)
        d = ImageDraw.Draw(big)
        for i in range(0, 36, 2):
            d.pieslice((-1300, -1300, 3900, 3900), i * 10, (i + 1) * 10, fill=g.RAY)
        self.rays = big
        self.screen_w = 780
        self.screen_h = round(self.screen_w * SRC_H / SRC_W)
        self.bezel = round(self.screen_w * 0.024)
        self.radius = round(self.screen_w * 0.075)
        pw, ph = self.screen_w + 2 * self.bezel, self.screen_h + 2 * self.bezel
        body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        body.paste((58, 58, 70, 255), (0, 0, pw, ph), g.rounded_mask((pw, ph), self.radius + self.bezel))
        body.paste((10, 10, 13, 255), (0, 0, pw, ph), g.rounded_mask((pw, ph), self.radius + self.bezel, inset=6))
        self.body = body
        self.screen_mask = g.rounded_mask((self.screen_w, self.screen_h), self.radius)
        alpha = body.split()[3]
        sh = Image.new("L", (pw + 120, ph + 120), 0)
        sh.paste(alpha.point(lambda a: a * 0.5), (60, 80))
        self.shadow = sh.filter(ImageFilter.GaussianBlur(30))
        self.phone_top = 420

    def background(self, t):
        ang = t * 6  # slow spin
        r = self.rays.rotate(ang, resample=Image.BILINEAR)
        cx, cy = 1300, 1300
        return r.crop((cx - W // 2, cy - round(H * 0.56), cx + W // 2, cy - round(H * 0.56) + H)).convert("RGBA")

    def phone(self, canvas, frame, scale=1.0, focus_y=None, shake=0):
        """Draws the phone with [frame] on its screen. [scale] > 1 zooms into
        the phone around source row [focus_y]."""
        sw, shh = self.screen_w, self.screen_h
        screen = frame.resize((sw, shh), Image.BILINEAR)
        ph = self.body.copy()
        ph.paste(screen, (self.bezel, self.bezel), self.screen_mask)
        x = (W - ph.width) // 2 + shake
        y = self.phone_top
        if scale != 1.0:
            nw, nh = round(ph.width * scale), round(ph.height * scale)
            ph = ph.resize((nw, nh), Image.BILINEAR)
            fy = self.phone_top + self.bezel + (focus_y or SRC_H / 2) * shh / SRC_H
            x = (W - nw) // 2 + shake
            y = round(fy - (fy - self.phone_top) * scale)
        else:
            canvas.paste((0, 0, 0, 255), (x - 60, y - 60), self.shadow)
        canvas.alpha_composite(ph, (x, y))

    def stacked(self, canvas, white, yellow, age, y):
        """Hook headline: two big lines, white over yellow."""
        t = min(age / 0.22, 1.0)
        s = 0.6 + 0.4 * ease_out_back(t)
        for k, (text, colour) in enumerate(((white, g.WHITE), (yellow, g.YELLOW))):
            size = 170
            while g.text_width(text, g.font(size, 900)) > W * 0.9:
                size -= 6
            f = g.font(round(size * s), 900)
            d = ImageDraw.Draw(canvas)
            cy = y + k * 190
            d.text((W // 2, cy + 10), text, font=f, fill=(20, 6, 50, 170), anchor="mm")
            d.text((W // 2, cy), text, font=f, fill=colour, anchor="mm")

    def caption(self, canvas, white, yellow, age, y=120, backing=False):
        """Two-part headline that pops in (scale overshoot) when it appears."""
        t = min(age / 0.22, 1.0)
        s = 0.6 + 0.4 * ease_out_back(t)
        size = 120
        f = g.font(size, 900)
        gap = g.text_width(f"{white} ", f) - g.text_width(white, f)
        tw = g.text_width(white, f) + gap + g.text_width(yellow, f)
        while tw > W * 0.92 and size > 60:
            size -= 6
            f = g.font(size, 900)
            gap = g.text_width(f"{white} ", f) - g.text_width(white, f)
            tw = g.text_width(white, f) + gap + g.text_width(yellow, f)
        asc, desc = f.getmetrics()
        layer = Image.new("RGBA", (tw + 60, asc + desc + 60), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        base = 30 + asc
        for dx, dy in ((0, 8),):
            d.text((30 + dx, base + dy), white, font=f, fill=(30, 10, 70, 160), anchor="ls")
            d.text((30 + g.text_width(white, f) + gap + dx, base + dy), yellow, font=f, fill=(30, 10, 70, 160), anchor="ls")
        d.text((30, base), white, font=f, fill=g.WHITE, anchor="ls")
        d.text((30 + g.text_width(white, f) + gap, base), yellow, font=f, fill=g.YELLOW, anchor="ls")
        if backing:
            pill = Image.new("RGBA", layer.size, (0, 0, 0, 0))
            ImageDraw.Draw(pill).rounded_rectangle((0, 10, layer.width - 1, layer.height - 10), 40, fill=(76, 29, 149, 235))
            pill.alpha_composite(layer)
            layer = pill
        if s != 1.0:
            layer = layer.resize((max(1, round(layer.width * s)), max(1, round(layer.height * s))), Image.BILINEAR)
        canvas.alpha_composite(layer, ((W - layer.width) // 2, y + round((asc + desc + 60) * (1 - s) / 2)))


def flash(canvas, age):
    """Short white flash at a cut."""
    if age < 0.1:
        a = round(200 * (1 - age / 0.1))
        canvas.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, a)))


def full_bleed(frame, zoom):
    card = frame.crop(CARD)
    s = H / card.height * zoom
    img = card.resize((round(card.width * s), round(card.height * s)), Image.BILINEAR)
    x0, y0 = (img.width - W) // 2, (img.height - H) // 2
    out = img.crop((x0, y0, x0 + W, y0 + H)).convert("RGBA")
    grad = Image.new("L", (1, H))
    grad.putdata([max(0, 190 - round(y * 0.35)) for y in range(H)])
    shade = Image.new("RGBA", (W, H), (20, 6, 50, 255))
    shade.putalpha(grad.resize((W, H)))
    out.alpha_composite(shade)
    return out


def countdown(canvas, t):
    """3-2-1 bubble over the phone in the quiz scene (t in scene seconds)."""
    if t >= 2.1:
        return
    n = 3 - int(t / 0.7)
    age = t - (3 - n) * 0.7
    s = 0.5 + 0.5 * ease_out_back(min(age / 0.25, 1))
    r = round(150 * s)
    cx, cy = W // 2, 1180
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(124, 58, 237, 235), outline=g.WHITE, width=10)
    f = g.font(round(200 * s), 900)
    d.text((cx, cy + 8), str(n), font=f, fill=g.WHITE, anchor="mm")
    canvas.alpha_composite(layer)


def end_card(stage, t):
    c = stage.background(t)
    d = ImageDraw.Draw(c)
    k = ease_out_back(min(t / 0.4, 1))
    icon_s = max(1, round(300 * k))
    icon = Image.open(g.ICON).convert("RGB").resize((icon_s, icon_s), Image.LANCZOS)
    c.paste(icon, ((W - icon_s) // 2, 470 + (300 - icon_s) // 2), g.rounded_mask((icon_s, icon_s), round(icon_s * 0.22)))
    if t > 0.3:
        stage.caption(c, "Human or", "AI?", t - 0.3, y=840)
    if t > 0.8:
        f = g.font(56, 760)
        d.text((W // 2, 1060), "Train your eye for AI fakes", font=f, fill=g.WHITE, anchor="mm")
    if t > 1.2:
        k2 = ease_out_back(min((t - 1.2) / 0.3, 1))
        bw, bh = round(720 * k2), round(150 * k2)
        if bw > 10:
            btn = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
            bd = ImageDraw.Draw(btn)
            bd.rounded_rectangle((0, 0, bw - 1, bh - 1), bh // 2, fill=(0, 0, 0, 255))
            if k2 > 0.6:
                bd.text((bw // 2, bh // 2 - 26), "FREE ON", font=g.font(36, 700), fill=(220, 220, 230), anchor="mm")
                bd.text((bw // 2, bh // 2 + 22), "Google Play", font=g.font(64, 800), fill=g.WHITE, anchor="mm")
            c.alpha_composite(btn, ((W - bw) // 2, 1200 + (150 - bh) // 2))
    if t > 1.8:
        f = g.font(44, 700)
        d.text((W // 2, 1440), "Photos · Videos · Music", font=f, fill=(255, 255, 255, 230), anchor="mm")
    g.sparkle(d, 200, 560, 34, g.YELLOW)
    g.sparkle(d, 880, 700, 24, g.WHITE)
    g.sparkle(d, 860, 1520, 28, g.YELLOW)
    return c


def render(video):
    stage = Stage()
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
                           "-pix_fmt", "yuv420p", str(HERE / "_video.mp4")], stdin=subprocess.PIPE)
    clock = 0.0
    cuts = []
    for idx, (kind, src, dur, caps) in enumerate(SCENES):
        cuts.append(clock)
        n = round(dur * FPS)
        if kind == "montage":
            frames = []
            for s in MONTAGE:
                frames += read_frames(video, s, 0.6)
        elif kind == "end":
            frames = [None] * n
        elif kind == "tip":
            # The game moves on 1.8 s after an answer: hold the reveal.
            frames = read_frames(video, src, 1.3)
            frames += [frames[-1]] * (n - len(frames))
        else:
            frames = read_frames(video, src, dur)
        for i in range(n):
            t = i / FPS
            gt = clock + t
            if kind == "hook":
                c = full_bleed(frames[i], 1.0 + 0.06 * t / dur)
            elif kind == "end":
                c = end_card(stage, t)
            else:
                c = stage.background(gt)
                shake = 0
                if kind == "fail" and 1.9 <= t < 2.3:
                    shake = round(18 * math.sin(t * 90) * (1 - (t - 1.9) / 0.4))
                if kind == "tip":
                    stage.phone(c, frames[i], scale=1.0 + 0.55 * min(t / 1.2, 1), focus_y=2100)
                elif kind == "montage":
                    stage.phone(c, frames[i], scale=1.0 + 0.04 * ((t % 0.6) / 0.6))
                else:
                    stage.phone(c, frames[i], shake=shake)
                if kind == "quiz":
                    countdown(c, t)
            for a, b, w, y in caps:
                if a <= t < b:
                    if kind == "hook":
                        stage.stacked(c, w, y, t - a, y=820)
                    else:
                        stage.caption(c, w, y, t - a, y=150, backing=kind == "tip")
            if kind != "hook" or i > 0:
                flash(c, t)
            ff.stdin.write(c.convert("RGB").tobytes())
        clock += dur
        print(f"scene {idx} {kind} done at {clock:.1f}s", flush=True)
    ff.stdin.close()
    ff.wait()
    return clock, cuts


# ---------------------------------------------------------------- audio

def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1) * np.exp(-t / decay)


def tone(freq, dur, decay, kind="sine"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == "saw":
        w = 2 * ((t * freq) % 1) - 1
    elif kind == "square":
        w = np.sign(np.sin(2 * np.pi * freq * t))
    else:
        w = np.sin(2 * np.pi * freq * t)
    return w * env(n, 0.003, decay)


def place(buf, sig, at, gain):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i] * gain


def soundtrack(total, cuts):
    buf = np.zeros(int(total * SR) + SR)
    beat = 60 / BPM
    rng = np.random.default_rng(7)
    music_end = total - 1.0
    bass_notes = [55.0, 55.0, 65.41, 49.0]  # A1 A1 C2 G1, one per bar
    k = 0
    t = 0.0
    while t < music_end:
        # kick on every beat
        n = int(0.25 * SR)
        tt = np.arange(n) / SR
        kick = np.sin(2 * np.pi * (50 + 120 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 9)
        place(buf, kick, t, 0.9)
        # clap on 2 and 4
        if k % 2 == 1:
            place(buf, rng.standard_normal(int(0.15 * SR)) * env(int(0.15 * SR), 0.001, 0.04), t, 0.35)
        # hats on the off-beat
        place(buf, rng.standard_normal(int(0.05 * SR)) * env(int(0.05 * SR), 0.001, 0.012), t + beat / 2, 0.18)
        # bass pulse on eighths
        note = bass_notes[(k // 4) % 4]
        for e in (0, beat / 2):
            place(buf, tone(note, beat / 2, 0.12, "saw"), t + e, 0.22)
        # pluck arpeggio from the second scene on
        if t >= cuts[1]:
            arp = [note * 4, note * 5, note * 6, note * 8]
            place(buf, tone(arp[k % 4], 0.3, 0.09, "square"), t + beat / 4, 0.05)
        t += beat
        k += 1
    # gentle fade at the end card
    fade_from = int(cuts[-1] * SR)
    fade = np.ones(len(buf))
    fade[fade_from:] = np.linspace(1, 0.35, len(buf) - fade_from)
    buf *= fade
    # whoosh at every cut
    for c in cuts[1:]:
        n = int(0.25 * SR)
        noise = rng.standard_normal(n)
        noise = np.convolve(noise, np.ones(12) / 12, mode="same")
        place(buf, noise * np.hanning(n), c - 0.12, 0.25)
    # countdown ticks, dings, buzz
    for i in range(3):
        place(buf, tone(1500, 0.08, 0.02), cuts[1] + i * 0.7, 0.35)
    for scene, at in DING.items():
        place(buf, tone(1318.5, 0.5, 0.18) + tone(1975.5, 0.5, 0.14) * 0.6, cuts[scene] + at, 0.35)
    for scene, at in BUZZ.items():
        place(buf, tone(110, 0.45, 0.25, "square"), cuts[scene] + at, 0.25)
    # end card chime
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        place(buf, tone(f, 0.6, 0.25), cuts[-1] + 0.3 + i * 0.09, 0.22)
    buf = buf[: int(total * SR)]
    buf = buf / max(1e-6, np.max(np.abs(buf))) * 0.89
    pcm = (buf * 32767).astype(np.int16)
    raw = HERE / "_audio.raw"
    raw.write_bytes(pcm.tobytes())
    return raw


def main():
    video = Path(sys.argv[1])
    total, cuts = render(video)
    raw = soundtrack(total, cuts)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(HERE / "_video.mp4"), "-f", "s16le", "-ar", str(SR), "-ac", "1",
                    "-i", str(raw), "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(OUT)],
                   check=True)
    (HERE / "_video.mp4").unlink()
    raw.unlink()
    print(OUT)


if __name__ == "__main__":
    main()

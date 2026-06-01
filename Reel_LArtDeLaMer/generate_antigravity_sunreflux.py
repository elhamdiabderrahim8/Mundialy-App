# -*- coding: utf-8 -*-
"""generate_antigravity_sunreflux.py

Creates a vertical 9:16 Facebook Reel with:
- Clear blue sky, no clouds
- Golden sunlight with realistic lens‑flare / sun‑reflux effect
- Anti‑gravity levitation of fish (smooth upward motion)
- French captions (3 lines)
- Audio mix: waves (-7 dB), breeze (-8 dB), fishing ambience (-9 dB), acoustic background (-18 dB)
- Cross‑dissolve transitions (0.5 s) and slow pan/zoom (Ken Burns)
- Each image displayed 3.5 s.

Usage: `python generate_antigravity_sunreflux.py`
"""

import os, math, random
from pathlib import Path
import numpy as np
import cv2
from moviepy.editor import (
    ImageClip, AudioFileClip, CompositeAudioClip, CompositeVideoClip,
    concatenate_videoclips, TextClip, vfx
)

# -------------------- Configuration --------------------
PROJECT_ROOT = Path(r"d:/WordCup/Reel_LArtDeLaMer")
IMG_DIR = PROJECT_ROOT
OUTPUT = PROJECT_ROOT / "reel_antigravity_sunreflux.mp4"

# Images (4 photos)
IMAGE_FILES = [IMG_DIR / f"image{i}.jpg" for i in range(1, 5)]

# Audio assets (place them in PROJECT_ROOT / "audio")
AUDIO_DIR = PROJECT_ROOT / "audio"
WAVES = AUDIO_DIR / "waves.mp3"
BREEZE = AUDIO_DIR / "breeze.mp3"
FISHING = AUDIO_DIR / "fishing_ambient.mp3"
MUSIC = AUDIO_DIR / "acoustic_ambient.mp3"

# Sun‑reflux (lens‑flare) frames – PNG sequence with transparency
FLARE_DIR = PROJECT_ROOT / "flare_seq"
FLARE_FRAMES = sorted(FLARE_DIR.glob("*.png"))

# Timing
IMAGE_DURATION = 3.5  # seconds per image
TRANSITION = 0.5      # cross‑dissolve seconds
FPS = 30

# Audio volume levels (dB)
DB_LEVELS = {
    "waves": -7,
    "breeze": -8,
    "fishing": -9,
    "music": -18,
}

# ----------------------------------------------------

def db_to_gain(db):
    """Convert dB to linear gain factor."""
    return 10 ** (db / 20.0)

def load_image(path, target_size=(3840, 2160)):
    img = cv2.imread(str(path))
    if img is None:
        raise FileNotFoundError(f"Image not found: {path}")
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    # Resize while preserving aspect ratio, then center‑crop to target size
    h, w = img.shape[:2]
    scale = max(target_size[0] / w, target_size[1] / h)
    scale = max(target_size[0] / w, target_size[1] / h)
    new_w = int(w * scale)
    new_h = int(h * scale)
    img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
    start_x = (img.shape[1] - target_size[0]) // 2
    start_y = (img.shape[0] - target_size[1]) // 2
    img = img[start_y:start_y + target_size[1], start_x:start_x + target_size[0]]
    return img

def color_grade_sky_ocean(img):
    """Boost sky to pure blue, deepen ocean, keep natural tones."""
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV).astype(np.float32)
    # Increase saturation modestly
    hsv[..., 1] = np.clip(hsv[..., 1] * 1.25, 0, 255)  # boost saturation for deep blues
    # Slightly increase value for brightness but keep highlights safe
    hsv[..., 2] = np.clip(hsv[..., 2] * 1.15, 0, 255)  # increase brightness for golden hour glow
    img = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)

    # Global slight gamma lift (0.95) to keep blacks deep
    gamma = 0.92  # deeper contrast
    inv_gamma = 1.0 / gamma
    table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in range(256)]).astype("uint8")
    img = cv2.LUT(img, table)
    return img

def extract_fish_mask(img):
    """Return binary mask of fish based on dominant orange/red hues."""
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    # Fish tend to be orange/red; adjust thresholds empirically
    lower = np.array([5, 60, 60])
    upper = np.array([25, 255, 255])
    mask = cv2.inRange(hsv, lower, upper)
    # Morphological clean‑up
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    return mask

def apply_levitation(img, mask, shift_px):
    """Shift the masked fish upward by shift_px, keep background unchanged."""
    # Separate foreground and background
    fish = cv2.bitwise_and(img, img, mask=mask)
    background = cv2.bitwise_and(img, img, mask=cv2.bitwise_not(mask))
    # Translate fish
    M = np.float32([[1, 0, 0], [0, 1, -shift_px]])
    fish_shifted = cv2.warpAffine(fish, M, (img.shape[1], img.shape[0]), borderMode=cv2.BORDER_TRANSPARENT)
    # Composite
    result = cv2.add(background, fish_shifted)
    return result

def load_flare_sequence():
    frames = []
    for p in FLARE_FRAMES:
        img = cv2.imread(str(p), cv2.IMREAD_UNCHANGED)  # keep alpha
        if img is None:
            continue
        frames.append(img)
    return frames

# Simple procedural flare used when no external PNGs are available
def generate_simple_flare(width, height, scale=0.3):
    """Create a basic bright circular flare as an RGBA NumPy array.
    The flare is a white‑yellow gradient blurred to look like a lens flare.
    """
    size = int(min(width, height) * scale)
    flare = np.zeros((size, size, 4), dtype=np.uint8)
    # Center white circle
    cv2.circle(flare, (size // 2, size // 2), size // 2, (255, 255, 200, 255), -1)
    # Blur to create glow
    flare = cv2.GaussianBlur(flare, (0, 0), sigmaX=size * 0.15)
    return flare

def apply_sun_reflux(frame, t, flare_frames, speed=0.4):
    """Overlay a moving lens‑flare across the frame.
    t – time in seconds, speed – fraction of width per second.
    """
    h, w = frame.shape[:2]
    if not flare_frames:
        # No external flare assets – generate a simple procedural flare on‑the‑fly
        flare = generate_simple_flare(w, h, scale=0.3)
    else:
        idx = int((t * speed * len(flare_frames)) % len(flare_frames))
        flare = flare_frames[idx]
    # Resize flare to a reasonable size (≈30% width)
    scale = 0.3
    flare = cv2.resize(flare, (int(w * scale), int(w * scale)), interpolation=cv2.INTER_AREA)
    fh, fw = flare.shape[:2]
    # Compute moving position (diagonal from left‑bottom to right‑top)
    x = int((t * speed * w) % (w - fw))
    y = int(h - fh - (t * speed * h) % (h - fh))
    # Split alpha
    if flare.shape[2] == 4:
        alpha = flare[:, :, 3] / 255.0
        rgb = flare[:, :, :3]
    else:
        alpha = np.ones((fh, fw))
        rgb = flare
    overlay = frame.copy()
    for c in range(3):
        overlay[y:y+fh, x:x+fw, c] = (
            alpha * rgb[:, :, c] + (1 - alpha) * overlay[y:y+fh, x:x+fw, c]
        ).astype(np.uint8)
    return overlay

def create_clip(img_path, idx, flare_frames):
    # Load, grade, and add fish levitation + sun reflux
    base = load_image(img_path)
    base = color_grade_sky_ocean(base)
    mask = extract_fish_mask(base)
    # Compute levitation shift based on index (smooth start)
    shift = int(10 * math.sin(math.pi * idx / 4))  # stronger gentle levitation
    base = apply_levitation(base, mask, shift)
    # Create the base ImageClip (no frame‑by‑frame modifications yet)
    base_clip = ImageClip(base).set_duration(IMAGE_DURATION)
    # Apply sun reflux via frame‑by‑frame effect using a lambda that accesses the original clip
    clip = base_clip.fl(lambda gf, t: apply_sun_reflux(gf(t), t, flare_frames))
    # Add caption using OpenCV (no ImageMagick)
    captions = ["Ciel d’un bleu pur", "Soleil doré illumine le bateau", "Le poisson flotte dans les airs"]
    caption_text = captions[idx % len(captions)]
    h, w = base.shape[:2]
    txt_img = np.zeros((200, w, 4), dtype=np.uint8)
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 1.2
    thickness = 2
    (text_w, text_h), _ = cv2.getTextSize(caption_text, font, font_scale, thickness)
    x = (w - text_w) // 2
    y = 150
    # Draw black outline first
    cv2.putText(txt_img, caption_text, (x, y), font, font_scale, (0, 0, 0, 255), thickness + 2, cv2.LINE_AA)
    # Draw white text on top
    cv2.putText(txt_img, caption_text, (x, y), font, font_scale, (255, 255, 255, 255), thickness, cv2.LINE_AA)
    txt_clip = ImageClip(txt_img).set_duration(IMAGE_DURATION).set_position(("center", "bottom"))
    # Composite caption over video clip
    clip = CompositeVideoClip([clip, txt_clip])
    # Add a subtle zoom‑in effect using resize lambda
    clip = clip.fx(vfx.resize, lambda t: 1 + 0.02 * (t / IMAGE_DURATION))
    return clip
def build_video():
    # Load flare sequence once
    flare_frames = load_flare_sequence()
    clips = []
    for i, img_path in enumerate(IMAGE_FILES):
        clip = create_clip(img_path, i, flare_frames).crossfadein(TRANSITION)
        clips.append(clip)
    # Concatenate with cross‑dissolve
    final = concatenate_videoclips(clips, method="compose", padding=-TRANSITION)
    # Audio mix
    audio_clips = []
    if WAVES.exists():
        audio_clips.append(AudioFileClip(str(WAVES)).volumex(db_to_gain(DB_LEVELS["waves"])) )
    if BREEZE.exists():
        audio_clips.append(AudioFileClip(str(BREEZE)).volumex(db_to_gain(DB_LEVELS["breeze"])) )
    if FISHING.exists():
        audio_clips.append(AudioFileClip(str(FISHING)).volumex(db_to_gain(DB_LEVELS["fishing"])) )
    if MUSIC.exists():
        audio_clips.append(AudioFileClip(str(MUSIC)).volumex(db_to_gain(DB_LEVELS["music"])) )
    # If no audio files are present, create a silent audio track
    if not audio_clips:
        from moviepy.audio.AudioClip import AudioClip
        import numpy as np
        silent = AudioClip(lambda t: np.zeros((1,)), fps=44100).set_duration(final.duration)
        final = final.set_audio(silent)
    else:
        mixed = CompositeAudioClip(audio_clips).set_duration(final.duration)
        final = final.set_audio(mixed)
    # Export
    final.write_videofile(str(OUTPUT), fps=FPS, codec="libx264", preset="slow", ffmpeg_params=["-crf", "18", "-pix_fmt", "yuv420p"])

if __name__ == "__main__":
    build_video()

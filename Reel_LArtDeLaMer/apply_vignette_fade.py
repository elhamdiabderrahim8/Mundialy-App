import os
from moviepy.editor import VideoFileClip, vfx

# Paths
INPUT_PATH = r"d:/WordCup/Reel_LArtDeLaMer/reel.mp4"
OUTPUT_PATH = r"d:/WordCup/Reel_LArtDeLaMer/reel_final.mp4"

if not os.path.isfile(INPUT_PATH):
    raise FileNotFoundError(f"Input video not found: {INPUT_PATH}")

# Load clip
clip = VideoFileClip(INPUT_PATH)

# Duration of video
duration = clip.duration

# Apply vignette effect via a mask (using moviepy's vfx.mask_color)
# Create a radial gradient mask (white center, black edges) and apply as mask
import numpy as np

def vignette_mask(get_frame, t):
    frame = get_frame(t)
    h, w = frame.shape[:2]
    # create coordinate grids
    y, x = np.ogrid[:h, :w]
    cx, cy = w/2, h/2
    # distance from center normalized (0..1)
    d = np.sqrt((x - cx)**2 + (y - cy)**2) / np.sqrt(cx**2 + cy**2)
    # vignette factor (strength 0.7) – adjust exponent for smoothness
    vignette = 1 - np.clip(d**1.5, 0, 1) * 0.7
    # apply to all color channels
    vignetted = (frame.astype('float32') * vignette[..., None]).astype('uint8')
    return vignetted

vignette_clip = clip.fl(vignette_mask)

# Apply fade‑out (last 2 seconds)
FADE_DURATION = 2.0  # seconds
final_clip = vignette_clip.fx(vfx.fadeout, duration=FADE_DURATION)

# Write the result (high quality, keep original fps)
final_clip.write_videofile(
    OUTPUT_PATH,
    codec="libx264",
    bitrate="5000k",
    fps=clip.fps,
    preset="medium",
    audio=True,
    threads=4,
    temp_audiofile="temp-audio.m4a",
    remove_temp=True,
    logger=None
)

print(f"Video with vignette and fade-out written to {OUTPUT_PATH}")

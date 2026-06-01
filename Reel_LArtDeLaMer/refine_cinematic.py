# refine_cinematic.py
"""Generate refined cinematic video for Reel L'Art de la Mer.
User parameters:
- Resolution: Vertical Reel 1080x1920 (9:16)
- Scene duration per image: 4 seconds
- Warm golden lens flare applied
- No vignette
- Fade-out length: 3 seconds
- Audio volumes: music 0.5, waves 0.3, wind 0.2, fishing 0.2
- No title slide
"""
import os
import cv2
import numpy as np
from moviepy.editor import (
    ImageClip,
    AudioFileClip,
    CompositeAudioClip,
    concatenate_videoclips,
)
from moviepy.video.fx import all as vfx

# Paths
PROJECT_DIR = r"d:/WordCup/Reel_LArtDeLaMer"
IMAGES = [os.path.join(PROJECT_DIR, f"image{i}.jpg") for i in range(1, 5)]
MUSIC_PATH = os.path.join(PROJECT_DIR, "keys_of_moon_epic_hero.mp3")
WAVES_PATH = os.path.join(PROJECT_DIR, "waves.mp3")
WIND_PATH = os.path.join(PROJECT_DIR, "wind.mp3")
FISHING_PATH = os.path.join(PROJECT_DIR, "fishing.mp3")
FLARE_WARM = os.path.join(PROJECT_DIR, "flare_warm.png")
OUTPUT = os.path.join(PROJECT_DIR, "reel_cinematic_refined.mp4")

# Vertical Reel Parameters (1080 x 1920)
RESOLUTION = (1080, 1920)
SCENE_DURATION = 4  # seconds per image
CROSSFADE = 0.4
FADE_OUT = 3  # seconds at end

def apply_bloom(image, thresh_value=230, blur_value=75, gain=0.3):
    # Convert to HSV to isolate the highly bright areas (sun and light reflections)
    hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
    h, s, v = cv2.split(hsv)
    
    # Create mask for intense highlight areas (sun and reflections)
    _, thresh = cv2.threshold(v, thresh_value, 255, cv2.THRESH_BINARY)
    
    # Very soft blur to create a light, elegant airy glow (not heavy)
    bloom = cv2.GaussianBlur(thresh, (blur_value, blur_value), 0)
    bloom_3ch = cv2.merge([bloom, bloom, bloom])
    
    # Neutral/cool tint for natural sky/water reflections (preserving blue dominance)
    glow = bloom_3ch.copy().astype(np.float32)
    glow[:, :, 0] = np.clip(glow[:, :, 0] * 0.90, 0, 255)  # R
    glow[:, :, 1] = np.clip(glow[:, :, 1] * 0.95, 0, 255)  # G
    glow[:, :, 2] = np.clip(glow[:, :, 2] * 1.05, 0, 255)  # B
    glow = glow.astype(np.uint8)
    
    # Blend very lightly to avoid blowing out whites
    result = cv2.addWeighted(image, 1.0, glow, gain, 0)
    return result

def color_grade_light(img):
    # Convert to HSV to boost natural saturation smoothly
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV).astype(np.float32)
    
    # Boost saturation for natural colors (+15%, balanced)
    hsv[..., 1] = np.clip(hsv[..., 1] * 1.15, 0, 255)
    img = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
    
    # Gamma correction to lift mid-tones slightly without overexposing whites
    invGamma = 1.0 / 0.9  # 0.9 gamma brightens shadows gently
    table = np.array([((i / 255.0) ** invGamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
    img = cv2.LUT(img, table)
    
    # Enhance the natural blue brilliance of the sky and water
    img = img.astype(np.float32)
    img[:, :, 2] = np.clip(img[:, :, 2] * 1.08, 0, 255) # Boost Blue slightly
    img[:, :, 0] = np.clip(img[:, :, 0] * 0.96, 0, 255) # Reduce Red slightly for natural look
    img = img.astype(np.uint8)
    
    # Elegant, subtle glow (very low gain to prevent white washout)
    img = apply_bloom(img, thresh_value=230, blur_value=75, gain=0.3)
    return img

def apply_warm_flare(frame):
    if not os.path.isfile(FLARE_WARM):
        return frame
    flare = cv2.imread(FLARE_WARM, cv2.IMREAD_UNCHANGED)
    flare = cv2.resize(flare, (frame.shape[1], frame.shape[0]))
    if flare.shape[2] == 4:
        alpha = flare[:, :, 3] / 255.0
        for c in range(3):
            frame[:, :, c] = (1 - alpha) * frame[:, :, c] + alpha * flare[:, :, c]
    return frame

def make_clip(img_path):
    img = cv2.imread(img_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Smart vertical 9:16 crop & scale:
    # Scale image to match height of 1920 first, then center crop the width to 1080
    h, w = img.shape[:2]
    new_h = 1920
    new_w = int(w * (new_h / h))
    resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
    
    # Center crop width to 1080
    start_x = (new_w - 1080) // 2
    cropped = resized[:, start_x : start_x + 1080]
    
    # Apply color grade & glow
    cropped = color_grade_light(cropped)
    cropped = apply_warm_flare(cropped)
    
    # Slight dynamic pan/zoom (Ken Burns vertical-friendly)
    clip = ImageClip(cropped).set_duration(SCENE_DURATION)
    clip = clip.fx(vfx.resize, lambda t: 1.0 + 0.05 * t / SCENE_DURATION)
    return clip

# Build clips with transitions
clips = []
for idx, img_path in enumerate(IMAGES):
    clip = make_clip(img_path)
    clips.append(clip)

# Apply crossfade between clips
for i in range(1, len(clips)):
    clips[i] = clips[i].crossfadein(CROSSFADE)
final_clip = concatenate_videoclips(clips, method="compose")
final_clip = final_clip.fx(vfx.fadeout, FADE_OUT)

# Audio mixing
audio_clips = []
if os.path.isfile(MUSIC_PATH):
    music = AudioFileClip(MUSIC_PATH).volumex(0.5)
    audio_clips.append(music)
if os.path.isfile(WAVES_PATH):
    waves = AudioFileClip(WAVES_PATH).volumex(0.3).audio_loop(duration=final_clip.duration)
    audio_clips.append(waves)
if os.path.isfile(WIND_PATH):
    wind = AudioFileClip(WIND_PATH).volumex(0.2).audio_loop(duration=final_clip.duration)
    audio_clips.append(wind)
if os.path.isfile(FISHING_PATH):
    fish = AudioFileClip(FISHING_PATH).volumex(0.2).audio_loop(duration=final_clip.duration)
    audio_clips.append(fish)
if audio_clips:
    final_audio = CompositeAudioClip(audio_clips)
    final_clip = final_clip.set_audio(final_audio)

# Export vertical video for Reels
final_clip.write_videofile(
    OUTPUT,
    codec="libx264",
    fps=30,
    preset="medium",
    bitrate="6000k",
    ffmpeg_params=["-crf", "18"],
    audio_codec="aac",
)

print("Video rendered to", OUTPUT)


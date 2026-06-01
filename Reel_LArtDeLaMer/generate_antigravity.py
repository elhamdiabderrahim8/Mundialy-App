import os
import cv2
import numpy as np
from moviepy.editor import VideoClip, concatenate_videoclips, AudioFileClip

PROJECT_DIR = r"d:/WordCup/Reel_LArtDeLaMer"
IMAGES = [os.path.join(PROJECT_DIR, f"image{i}.jpg") for i in range(1, 5)]
OUTPUT = os.path.join(PROJECT_DIR, "reel_antigravity.mp4")
WAVES_PATH = os.path.join(PROJECT_DIR, "waves.mp3")

W, H = 1080, 1920
FPS = 30
DURATION = 4

# Pre-generate droplet texture (Anti-Gravity effect)
# Create a tall canvas so we can scroll it upwards
DROPLET_H = H * 2
droplets = np.zeros((DROPLET_H, W, 3), dtype=np.uint8)
np.random.seed(42)  # For consistent droplets
for _ in range(400):
    x = np.random.randint(0, W)
    y = np.random.randint(0, DROPLET_H)
    r = np.random.randint(2, 9)
    # Cyan/white water drops
    color = (255, 240, 240) if np.random.rand() > 0.5 else (255, 255, 255)
    cv2.circle(droplets, (x, y), r, color, -1)
# Soften the drops to look like out-of-focus water
droplets = cv2.GaussianBlur(droplets, (7, 7), 0)

# Pre-generate luminous sun rays mask
rays = np.zeros((H, W, 3), dtype=np.float32)
center = (int(W * 0.8), int(H * 0.1))  # Top right sun origin
for angle in range(0, 360, 12):
    pt2 = (int(center[0] + 2000 * np.cos(np.radians(angle))), 
           int(center[1] + 2000 * np.sin(np.radians(angle))))
    intensity = np.random.uniform(0.1, 0.5)
    # Sun rays are golden
    color = (intensity * 0.5, intensity * 0.8, intensity) # BGR (golden in RGB is low blue, high red/green)
    cv2.line(rays, center, pt2, color, np.random.randint(30, 80))
rays = cv2.GaussianBlur(rays, (61, 61), 0)
rays = np.clip(rays * 255, 0, 255).astype(np.uint8)

def color_grade_blue_gold(img):
    # Deep blue sky, brilliant gold light
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * 1.25, 0, 255) # Saturation boost
    img = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32)
    
    # Enhance blues
    img[:, :, 2] = np.clip(img[:, :, 2] * 1.15, 0, 255)
    # Warm up highlights slightly
    img[:, :, 0] = np.clip(img[:, :, 0] * 1.05, 0, 255)
    
    # Add a global contrast lift
    img = cv2.convertScaleAbs(img.astype(np.uint8), alpha=1.1, beta=10)
    return img

def make_antigravity_clip(img_path):
    img = cv2.imread(img_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Scale image so we have extra vertical space to pan upwards
    # We need width=1080 minimum, height=1920 + 300 extra for pan
    target_w = W
    target_h = H + 400
    
    h_orig, w_orig = img.shape[:2]
    scale = max(target_w / w_orig, target_h / h_orig)
    new_w = int(w_orig * scale)
    new_h = int(h_orig * scale)
    img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
    img = color_grade_blue_gold(img)
    
    # Crop horizontally to center
    start_x = (new_w - W) // 2
    img = img[:, start_x:start_x+W]
    
    def make_frame(t):
        # 1. Camera vertical pan (bottom to top simulates lift/anti-gravity)
        progress = t / DURATION
        y_offset = int((new_h - H) * (1 - progress))
        frame = img[y_offset:y_offset+H, :].copy()
        
        # 2. Add luminous sun rays (fixed over camera)
        frame = cv2.addWeighted(frame, 1.0, rays, 0.6, 0)
        
        # 3. Add anti-gravity droplets (scroll upwards very fast)
        # speed = 250 pixels per second
        scroll = int(250 * t) % (DROPLET_H - H)
        drop_y_start = (DROPLET_H - H) - scroll
        drop_frame = droplets[drop_y_start:drop_y_start+H, :]
        
        # Additive blend for water droplets
        frame = cv2.addWeighted(frame, 1.0, drop_frame, 0.7, 0)
        
        return frame
        
    return VideoClip(make_frame, duration=DURATION)

clips = []
for p in IMAGES:
    clips.append(make_antigravity_clip(p))

# Apply crossfade between clips
for i in range(1, len(clips)):
    clips[i] = clips[i].crossfadein(0.5)

final_clip = concatenate_videoclips(clips, method="compose")

# Add ambient sounds only
if os.path.isfile(WAVES_PATH):
    waves = AudioFileClip(WAVES_PATH).volumex(0.3).audio_loop(duration=final_clip.duration)
    final_clip = final_clip.set_audio(waves)

final_clip.write_videofile(
    OUTPUT,
    codec="libx264",
    fps=FPS,
    preset="medium",
    bitrate="6000k",
    ffmpeg_params=["-crf", "18"],
    audio_codec="aac"
)
print(f"Anti-gravity Reel saved to {OUTPUT}")

import cv2
import numpy as np
import os
import requests
from moviepy.editor import VideoFileClip, AudioFileClip, CompositeAudioClip
import moviepy.audio.fx.all as afx

WIDTH, HEIGHT = 720, 1280
FPS = 30

def enhance_image(img):
    # Boost saturation and contrast for a vibrant, bright look
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV).astype(np.float32)
    h, s, v = cv2.split(hsv)
    
    s = s * 1.3 # 30% more saturation
    s = np.clip(s, 0, 255)
    
    hsv = cv2.merge([h, s, v]).astype(np.uint8)
    img_enhanced = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    
    # Increase contrast and brightness (Golden hour / bright sunlight)
    img_enhanced = cv2.convertScaleAbs(img_enhanced, alpha=1.15, beta=15)
    return img_enhanced

def load_image(path):
    img = cv2.imread(path)
    if img is None:
        img = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    return enhance_image(img_rgb)

def get_crop(img, scale, center_offset_x, center_offset_y):
    h, w = img.shape[:2]
    target_aspect = WIDTH / HEIGHT
    img_aspect = w / h
    
    if img_aspect > target_aspect:
        new_w = int(h * target_aspect)
        new_h = h
    else:
        new_w = w
        new_h = int(w / target_aspect)
        
    crop_w = int(new_w / scale)
    crop_h = int(new_h / scale)
    
    cx = w // 2 + int(center_offset_x * w)
    cy = h // 2 + int(center_offset_y * h)
    
    x1 = max(0, cx - crop_w // 2)
    y1 = max(0, cy - crop_h // 2)
    x2 = min(w, x1 + crop_w)
    y2 = min(h, y1 + crop_h)
    
    if x2 == w: x1 = max(0, w - crop_w)
    if y2 == h: y1 = max(0, h - crop_h)
    if x1 == 0: x2 = min(w, crop_w)
    if y1 == 0: y2 = min(h, crop_h)
    
    crop = img[y1:y2, x1:x2]
    return cv2.resize(crop, (WIDTH, HEIGHT))

scenes = [
    {"img": "image4.jpg", "dur": 3.0, "effect": "zoom_in"},
    {"img": "image2.jpg", "dur": 3.0, "effect": "pan_right"},
    {"img": "image3.jpg", "dur": 2.5, "effect": "zoom_in"},
    {"img": "image1.jpg", "dur": 3.0, "effect": "zoom_out"},
    {"img": "image4.jpg", "dur": 2.5, "effect": "static_zoom"}
]

print("Generating video frames (vibrant colors, NO TEXT)...")
out = cv2.VideoWriter("temp_video.mp4", cv2.VideoWriter_fourcc(*'mp4v'), FPS, (WIDTH, HEIGHT))

for i, scene in enumerate(scenes):
    print(f"Rendering scene {i+1}...")
    frames = int(scene["dur"] * FPS)
    img = load_image(scene["img"])
        
    for f in range(frames):
        progress = f / float(frames)
        
        scale = 1.0
        cx, cy = 0.0, 0.0
        
        if scene["effect"] == "zoom_in":
            scale = 1.0 + 0.15 * progress
        elif scene["effect"] == "zoom_out":
            scale = 1.15 - 0.15 * progress
        elif scene["effect"] == "pan_right":
            scale = 1.05
            cx = -0.05 + 0.1 * progress
        elif scene["effect"] == "static_zoom":
            scale = 1.15
            
        frame = get_crop(img, scale, cx, cy)
        
        if scene["img"] == "image3.jpg":
            gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
            frame = cv2.cvtColor(gray, cv2.COLOR_GRAY2RGB)
            
        # Smooth cross dissolve (cinematic transition)
        if i > 0 and f < 20:
            fade_alpha = f / 20.0
            frame = cv2.addWeighted(frame, fade_alpha, np.zeros_like(frame), 1-fade_alpha, 0)
            
        out.write(cv2.cvtColor(frame.astype(np.uint8), cv2.COLOR_RGB2BGR))

out.release()

print("Mixing audio...")
try:
    video = VideoFileClip("temp_video.mp4")
    
    audios_to_mix = []
    
    if os.path.exists("waves.mp3"):
        aw = AudioFileClip("waves.mp3").volumex(0.4)
        if aw.duration < video.duration:
            aw = afx.audio_loop(aw, duration=video.duration)
        else:
            aw = aw.subclip(0, video.duration)
        audios_to_mix.append(aw)
        
    if os.path.exists("guitar.mp3"):
        ag = AudioFileClip("guitar.mp3").volumex(0.6)
        if ag.duration < video.duration:
            ag = afx.audio_loop(ag, duration=video.duration)
        else:
            ag = ag.subclip(0, video.duration)
        audios_to_mix.append(ag)
        
    if audios_to_mix:
        final_audio = CompositeAudioClip(audios_to_mix)
        final_video = video.set_audio(final_audio)
    else:
        final_video = video
        
    # Fade out audio/video at the end
    final_video = final_video.fadeout(1.5)
    
    print("Exporting final cinematic video...")
    final_video.write_videofile("reel_cinematic.mp4", codec="libx264", audio_codec="aac")
    
    # Cleanup
    video.close()
    if os.path.exists("temp_video.mp4"):
        os.remove("temp_video.mp4")
except Exception as e:
    print(f"Error mixing audio: {e}")
    
print("Done!")

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os

WIDTH, HEIGHT = 720, 1280
FPS = 30

def load_image(path):
    img = cv2.imread(path)
    if img is None:
        img = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

def apply_text(img_rgb, lines, progress):
    # Use PIL for better text rendering
    pil_img = Image.fromarray(img_rgb)
    # create a transparent overlay for text
    txt_layer = Image.new('RGBA', pil_img.size, (255,255,255,0))
    draw = ImageDraw.Draw(txt_layer)
    
    try:
        font = ImageFont.truetype("arial.ttf", 46)
    except:
        font = ImageFont.load_default()
        
    y_start = HEIGHT - 350
    for i, line in enumerate(lines):
        # staggered fade-in based on line index
        line_progress = max(0, min(1, (progress * 2) - (i * 0.3)))
        alpha = int(255 * line_progress)
        
        if alpha > 0:
            # We need to compute text size to center it
            try:
                bbox = font.getbbox(line)
                tw = bbox[2] - bbox[0]
            except:
                tw = len(line) * 20
                
            x = (WIDTH - tw) // 2
            y = y_start + i * 60
            
            # shadow
            draw.text((x+3, y+3), line, font=font, fill=(0, 0, 0, alpha))
            draw.text((x, y), line, font=font, fill=(245, 245, 230, alpha))
            
    # Composite the text layer over the image
    out_img = Image.alpha_composite(pil_img.convert('RGBA'), txt_layer)
    return np.array(out_img.convert('RGB'))

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
    {"img": "image4.jpg", "dur": 3.0, "lines": ["Mon pere ne parle pas beaucoup.", "La mer parle pour lui."], "effect": "zoom_in"},
    {"img": "image2.jpg", "dur": 3.0, "lines": ["Chaque matin, la mer offre."], "effect": "pan_right"},
    {"img": "image3.jpg", "dur": 2.5, "lines": ["Un metier.", "Une patience.", "Un art."], "effect": "zoom_in"},
    {"img": "image1.jpg", "dur": 3.0, "lines": ["La recompense de ceux", "qui se levent avant l'aube."], "effect": "zoom_out"},
    {"img": "image4.jpg", "dur": 2.5, "lines": ["Peche a l'ancienne.", "Avec amour."], "effect": "static_zoom"},
    {"img": None, "dur": 2.5, "lines": ["Papa - fierte de la mer."], "effect": "black"}
]

out = cv2.VideoWriter("reel.mp4", cv2.VideoWriter_fourcc(*'mp4v'), FPS, (WIDTH, HEIGHT))

for i, scene in enumerate(scenes):
    print(f"Rendering scene {i+1}...")
    frames = int(scene["dur"] * FPS)
    
    if scene["img"] is not None:
        img = load_image(scene["img"])
    else:
        img = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
        
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
            
        if scene["img"] is not None:
            frame = get_crop(img, scale, cx, cy)
            if scene["img"] == "image3.jpg":
                gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
                frame = cv2.cvtColor(gray, cv2.COLOR_GRAY2RGB)
            
            # Simple vignette
            rows, cols = frame.shape[:2]
            kernel_x = cv2.getGaussianKernel(cols, cols/2)
            kernel_y = cv2.getGaussianKernel(rows, rows/2)
            kernel = kernel_y * kernel_x.T
            mask = 255 * kernel / np.linalg.norm(kernel)
            mask = cv2.resize(mask, (cols, rows))
            # Apply very light vignette
            mask = mask / np.max(mask)
            mask = mask * 0.5 + 0.5
            for c in range(3):
                frame[:,:,c] = frame[:,:,c] * mask
        else:
            frame = img.copy()
            
        frame_with_text = apply_text(frame, scene["lines"], progress)
        
        # Crossfade transition (fade from black on first few frames of new scene)
        if i > 0 and f < 15:
            fade_alpha = f / 15.0
            frame_with_text = cv2.addWeighted(frame_with_text, fade_alpha, np.zeros_like(frame_with_text), 1-fade_alpha, 0)
            
        out.write(cv2.cvtColor(frame_with_text.astype(np.uint8), cv2.COLOR_RGB2BGR))

out.release()
print("Done! reel.mp4 created.")

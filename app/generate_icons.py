import os
from PIL import Image, ImageDraw, ImageFont

def make_icons():
    source_path = r'../references/app icon/—Pngtree—simple campfire drawing_23364387.png'
    try:
        img = Image.open(source_path).convert('RGBA')
    except Exception as e:
        print(f"Failed to open image: {e}")
        return

    # Constants
    DENSITIES = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
    }
    
    # Adaptive foreground scale (72 out of 108 is the typical safe zone for a foreground)
    # The actual adaptive icon standard says 108x108 total, 72x72 safe zone.
    # We will generate adaptive foregrounds scaled to 108x108, with the image fitting inside 72x72.
    
    # Colors
    bg_color = (255, 255, 255, 255) # White
    beta_bg_color = (255, 243, 224, 255) # Light orange
    
    def create_legacy_icon(base_img, size, is_beta=False, bg=bg_color):
        out = Image.new('RGBA', (size, size), bg)
        # Pad the image by 10% to prevent touching the edges
        pad = int(size * 0.1)
        inner_size = size - 2 * pad
        resized = base_img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        out.paste(resized, (pad, pad), resized)
        
        if is_beta:
            draw = ImageDraw.Draw(out)
            # Draw a simple sash or box in the bottom right corner
            # Let's draw a red rectangle and "BETA"
            rect_h = int(size * 0.25)
            rect_w = int(size * 0.5)
            rx1 = size - rect_w
            ry1 = size - rect_h
            draw.rectangle([rx1, ry1, size, size], fill=(220, 50, 50, 255))
            
            # Simple text (no font needed, or default font)
            # Pillow's default font might be too small, but drawing lines or using basic font works.
            draw.text((rx1 + int(size*0.05), ry1 + int(size*0.05)), "BETA", fill="white")
            
            # Draw a sash (diagonal) instead
            # Instead of a sash, a red triangle in bottom right
            poly = [(size, size - int(size*0.4)), (size - int(size*0.4), size), (size, size)]
            draw.polygon(poly, fill=(220, 50, 50, 255))
        
        # Circular mask for standard legacy icons
        mask = Image.new('L', (size, size), 0)
        draw_mask = ImageDraw.Draw(mask)
        draw_mask.ellipse((0, 0, size, size), fill=255)
        out.putalpha(mask)
        
        return out

    def create_foreground_icon(base_img, size, is_beta=False):
        # Foreground must be 108dp. For mdpi that's 108px.
        fg_size = int(size * (108 / 48))
        out = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0)) # transparent
        
        safe_zone = int(fg_size * (72 / 108))
        pad = (fg_size - safe_zone) // 2
        
        resized = base_img.resize((safe_zone, safe_zone), Image.Resampling.LANCZOS)
        out.paste(resized, (pad, pad), resized)
        
        if is_beta:
            draw = ImageDraw.Draw(out)
            # Draw a beta sash in the foreground
            poly = [(fg_size, fg_size - int(fg_size*0.35)), (fg_size - int(fg_size*0.35), fg_size), (fg_size, fg_size)]
            draw.polygon(poly, fill=(220, 50, 50, 255))
        
        return out

    for flavor in ['stable', 'beta']:
        for density, d_size in DENSITIES.items():
            out_dir = f"android/app/src/{flavor}/res/mipmap-{density}"
            os.makedirs(out_dir, exist_ok=True)
            
            # Legacy icon
            legacy = create_legacy_icon(img, d_size, is_beta=(flavor == 'beta'), bg=(beta_bg_color if flavor == 'beta' else bg_color))
            legacy.save(os.path.join(out_dir, "ic_launcher.png"))
            
            # Foreground icon
            fg = create_foreground_icon(img, d_size, is_beta=(flavor == 'beta'))
            fg.save(os.path.join(out_dir, "ic_launcher_foreground.png"))
            
    # Also generate windows icon
    win_dir = "windows/runner/resources"
    if os.path.exists(win_dir):
        # .ico file needs multiple sizes: 16, 32, 48, 64, 128, 256
        sizes = [(16,16), (32,32), (48,48), (64,64), (128,128), (256,256)]
        out_ico = Image.new('RGBA', img.size, bg_color)
        out_ico.paste(img, (0,0), img)
        out_ico.save(os.path.join(win_dir, "app_icon.ico"), sizes=sizes)
        print("Generated app_icon.ico")
        
    print("Done generating icons.")

if __name__ == '__main__':
    make_icons()

#!/usr/bin/env python3
"""App Store 营销截图合成：标题文案 + 真机截图卡 + 品牌渐变底。

用法（仓库根目录，Pillow 环境）：
    python3 test/tools/compose_screenshots.py

输入：assets/screenshots/raw/*.png（真机实拍 1170×2532）
输出：assets/screenshots/store/{zh,en}/{69,65}/0X.png（6.9" 1290×2796 / 6.5" 1242×2688）
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'assets/screenshots/raw'
OUT = ROOT / 'assets/screenshots/store'

# 两档必交尺寸
SIZES = {'69': (1290, 2796), '65': (1242, 2688)}

# 叙事顺序与标题（改文案只动这里）
SETS = {
    'zh': {
        'shots': ['01_home.png', '02_edit_result.png', '03_sliders.png',
                  '04_result.png', '05_edit_red.png'],
        'titles': ['33+ 内置规格，开箱即用', 'AI 抠图换底，全在本机完成',
                   '美颜与清晰度，随手微调', '保存前逐项合规检测',
                   '蓝白红灰，底色秒切'],
        'font': ('/System/Library/Fonts/Hiragino Sans GB.ttc', 2),  # W6
    },
    'en': {
        'shots': ['en_01_home.png', 'en_02_edit.png', 'en_03_sliders.png',
                  'en_04_result.png', 'en_05_red.png'],
        'titles': ['33+ built-in specs, ready to use',
                   'AI cutout and recolor, on your device',
                   'Fine-tune skin and sharpness',
                   'Checked before you save',
                   'Blue, white, red — switch instantly'],
        'font': ('/System/Library/Fonts/HelveticaNeue.ttc', 1),  # Bold
    },
}

BG_TOP = (43, 108, 176)     # 品牌蓝 0xFF2B6CB0
BG_BOTTOM = (23, 43, 84)    # 深蓝


def gradient(size):
    w, h = size
    base = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1)
        base.putpixel((0, y), tuple(
            round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))
    return base.resize((w, h))


def load_font(spec, size):
    path, index = spec
    try:
        return ImageFont.truetype(path, size, index=index)
    except Exception:
        return ImageFont.truetype(path, size, index=0)


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, im.width, im.height), radius=radius, fill=255)
    out = im.convert('RGBA')
    out.putalpha(mask)
    return out


def compose(shot_path, title, size, font_path, out_path):
    w, h = size
    canvas = gradient(size).convert('RGBA')

    # 标题（顶部居中，自动两行）
    font = load_font(font_path, round(w * 0.058))
    draw = ImageDraw.Draw(canvas)
    max_w = w * 0.86
    words = title.split(' ')
    lines, cur = [], ''
    for word in words if len(words) > 1 else [title]:
        trial = f'{cur} {word}'.strip()
        if draw.textlength(trial, font=font) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    y = h * 0.062
    for line in lines:
        lw = draw.textlength(line, font=font)
        draw.text(((w - lw) / 2, y), line, font=font, fill='white')
        y += font.size * 1.3

    # 截图卡（圆角 + 投影）
    shot = Image.open(shot_path)
    sw = round(w * 0.80)
    sh = round(sw * shot.height / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    card = rounded(shot, round(sw * 0.09))

    shadow = Image.new('RGBA', (sw + 80, sh + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (40, 40, sw + 40, sh + 40), radius=round(sw * 0.09),
        fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))

    x = (w - sw) // 2
    top = h - sh - round(h * 0.045)
    canvas.alpha_composite(shadow, (x - 40, top - 40))
    canvas.alpha_composite(card, (x, top))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(out_path, 'PNG')
    print('✓', out_path.relative_to(ROOT))


def main():
    missing = []
    for lang, cfg in SETS.items():
        for size_key, size in SIZES.items():
            for i, (shot, title) in enumerate(
                    zip(cfg['shots'], cfg['titles']), 1):
                src = RAW / shot
                if not src.exists():
                    missing.append(shot)
                    continue
                compose(src, title, size, cfg['font'],
                        OUT / lang / size_key / f'{i:02d}.png')
    if missing:
        print('缺原始截图：', ', '.join(sorted(set(missing))))


if __name__ == '__main__':
    main()

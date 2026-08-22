# -*- coding: utf-8 -*-
"""生成「轻课表」应用图标（日历 + 课程格子），覆盖各 mipmap 尺寸。"""
import os

from PIL import Image, ImageDraw

SIZE = 1024
RADIUS = int(SIZE * 0.21)

BLUE_TOP = (59, 130, 246)     # #3B82F6
BLUE_BOTTOM = (37, 99, 235)   # #2563EB
WHITE = (255, 255, 255, 255)
GRID_BLUE = (59, 130, 246, 255)


def make_master():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    # 垂直渐变背景
    grad = Image.new('RGBA', (1, SIZE))
    for y in range(SIZE):
        t = y / (SIZE - 1)
        r = int(BLUE_TOP[0] + (BLUE_BOTTOM[0] - BLUE_TOP[0]) * t)
        g = int(BLUE_TOP[1] + (BLUE_BOTTOM[1] - BLUE_TOP[1]) * t)
        b = int(BLUE_TOP[2] + (BLUE_BOTTOM[2] - BLUE_TOP[2]) * t)
        grad.putpixel((0, y), (r, g, b, 255))
    bg = grad.resize((SIZE, SIZE))

    # 圆角蒙版（圆角外透明）
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1], radius=RADIUS, fill=255)
    img.paste(bg, (0, 0), mask)

    d = ImageDraw.Draw(img)

    # 日历的两个装订环
    d.rounded_rectangle([304, 224, 432, 384], radius=40, fill=WHITE)
    d.rounded_rectangle([592, 224, 720, 384], radius=40, fill=WHITE)

    # 日历主体（白色）
    d.rounded_rectangle([176, 360, 848, 832], radius=72, fill=WHITE)

    # 顶部标题条
    d.rounded_rectangle([216, 400, 808, 496], radius=40, fill=GRID_BLUE)

    # 课程格子 3x2
    col_x = [216, 432, 648]
    row_y = [540, 692]
    cw, ch = 160, 100
    for y in row_y:
        for x in col_x:
            d.rounded_rectangle([x, y, x + cw, y + ch], radius=28, fill=GRID_BLUE)

    return img


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    res = os.path.normpath(
        os.path.join(base, '..', 'android', 'app', 'src', 'main', 'res'))
    master = make_master()

    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, px in sizes.items():
        out_path = os.path.join(res, folder, 'ic_launcher.png')
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(out_path, 'PNG')
        print('saved', out_path, f'{px}x{px}')


if __name__ == '__main__':
    main()

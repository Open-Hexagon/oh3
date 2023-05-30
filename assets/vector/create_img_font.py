# Draws yellow separators for an image font

import os
from PIL import Image, ImageDraw

def main():
    im = Image.open("img_font.png")
    draw = ImageDraw.Draw(im)
    width, height = im.size
    for x in range(width):
        if contains_green(im, x, height):
            draw.rectangle([(x, 0), (x, height)], fill=(255, 255, 0, 255))
    im.save("font.png")


def contains_green(im:Image, x, height):
    for y in range(height):
        if im.getpixel((x, y))[1] > 0:
            return True
    return False


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    main()

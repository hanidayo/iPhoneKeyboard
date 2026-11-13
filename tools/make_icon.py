from PIL import Image, ImageDraw, ImageFilter
S = 1024
# 배경: 민트 → 청록 대각선 그라데이션
bg = Image.new("RGB", (S, S))
top, bot = (126, 224, 182), (22, 132, 128)
px = bg.load()
for y in range(S):
    for x in range(S):
        t = (x * 0.35 + y * 0.65) / S
        px[x, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
img = bg.convert("RGBA")

def rr(draw, box, r, fill):
    draw.rounded_rectangle(box, r, fill=fill)

# 키 3개 (ㅣ ㆍ ㅡ) — 그림자 + 흰 키
keys = [(150, 335, 390, 595), (412, 335, 652, 595), (674, 335, 914, 595)]
shift = -40
keys = [(a + shift, b, c + shift, d) for a, b, c, d in keys]
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
for a, b, c, d in keys:
    rr(sd, (a, b + 14, c, d + 14), 44, (0, 60, 50, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(10))
img.alpha_composite(shadow)
d = ImageDraw.Draw(img)
for a, b, c, dd in keys:
    rr(d, (a, b, c, dd), 44, (255, 255, 255, 255))

ink = (20, 92, 90, 255)
# ㅣ
cx = (keys[0][0] + keys[0][2]) // 2
rr(d, (cx - 15, 390, cx + 15, 540), 15, ink)
# ㆍ
cx = (keys[1][0] + keys[1][2]) // 2
d.ellipse((cx - 26, 439, cx + 26, 491), fill=ink)
# ㅡ
cx = (keys[2][0] + keys[2][2]) // 2
rr(d, (cx - 75, 450, cx + 75, 480), 15, ink)

# 아래: 스페이스바 + 스와이프 화살표 느낌
sb = (150 + shift, 645, 914 + shift, 795)
sh2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(sh2).rounded_rectangle((sb[0], sb[1] + 14, sb[2], sb[3] + 14), 44, fill=(0, 60, 50, 90))
img.alpha_composite(sh2.filter(ImageFilter.GaussianBlur(10)))
d = ImageDraw.Draw(img)
rr(d, sb, 44, (255, 255, 255, 235))
cy = (sb[1] + sb[3]) // 2
mx = (sb[0] + sb[2]) // 2
acc = (40, 170, 140, 255)
rr(d, (mx - 150, cy - 11, mx + 150, cy + 11), 11, acc)
d.polygon([(mx - 200, cy), (mx - 140, cy - 42), (mx - 140, cy + 42)], fill=acc)
d.polygon([(mx + 200, cy), (mx + 140, cy - 42), (mx + 140, cy + 42)], fill=acc)

# 오른쪽 위 작은 스마일 배지 (이모티콘 키)
bx, by, br = 900 + shift, 245, 70
badge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(badge).ellipse((bx - br, by - br + 10, bx + br, by + br + 10), fill=(0, 60, 50, 80))
img.alpha_composite(badge.filter(ImageFilter.GaussianBlur(8)))
d = ImageDraw.Draw(img)
d.ellipse((bx - br, by - br, bx + br, by + br), fill=(255, 214, 90, 255))
d.ellipse((bx - 30, by - 25, bx - 12, by - 5), fill=(70, 50, 20, 255))
d.ellipse((bx + 12, by - 25, bx + 30, by - 5), fill=(70, 50, 20, 255))
d.arc((bx - 40, by - 30, bx + 40, by + 40), 25, 155, fill=(70, 50, 20, 255), width=11)

img = img.transform(img.size, Image.AFFINE, (1,0,0,0,1,-35), fillcolor=None) if False else img
img.convert("RGB").save("AppIcon.png")
# 미리보기 (iOS 마스크 흉내)
m = Image.new("L", (S, S), 0)
ImageDraw.Draw(m).rounded_rectangle((0, 0, S, S), 225, fill=255)
prev = Image.new("RGBA", (S, S), (240, 240, 240, 255))
prev.paste(img, (0, 0), m)
prev.resize((360, 360), Image.LANCZOS).save("preview.png")

"""
うちの子免許証 タグ裏面 印刷用テンプレート生成スクリプト

仕様:
  - 仕上がり直径: 25mm（プラバン芯材サイズ）
  - 塗り足しなし、円形PNG（円外は透明）
  - 解像度: 350dpi -> 345 x 345 px
  - 出力: tag_back.png（RGBA、円外は完全透明）
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# ============ 基本設定 ============
DPI = 1200
TAG_DIA_MM = 25.0

ASSETS_DIR = Path(__file__).parent
FONT_REG = ASSETS_DIR.parent / "fonts" / "NotoSansJP-Regular.ttf"
FONT_SBL = ASSETS_DIR.parent / "fonts" / "NotoSansJP-SemiBold.ttf"
NFC_ICON = ASSETS_DIR / "nfc_icon.png"
OUTPUT = ASSETS_DIR / "tag_back.png"

BG_COLOR = (255, 255, 255)
INK_COLOR = (70, 70, 70)
ICON_LINE_COLOR = (50, 50, 50)
ICON_THRESHOLD = 100

# ============ レイアウト（mm基準、タグ左上原点）============
TITLE_Y_MM = 6.5
TITLE_FS_MM = 2.6

ICON_CENTER_Y_MM = 12.5
ICON_DIAM_MM = 6.0

NFC_Y_MM = 16.5
NFC_FS_MM = 1.6

CATCH_Y_MM = 19.5
CATCH_FS_MM = 1.8


# ============ 単位変換 ============
def mm_to_px(mm: float) -> int:
    return round(mm * DPI / 25.4)


W = mm_to_px(TAG_DIA_MM)
H = mm_to_px(TAG_DIA_MM)


# ============ 描画ユーティリティ ============
def font_for_mm(font_path: Path, fs_mm: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(font_path), mm_to_px(fs_mm))


def draw_centered_text(draw: ImageDraw.ImageDraw, text: str,
                        font: ImageFont.FreeTypeFont, y_tag_mm: float,
                        ink) -> None:
    cx = W // 2
    cy = mm_to_px(y_tag_mm)
    draw.text((cx, cy), text, fill=ink, font=font, anchor="mm")


def extract_line_art(icon_path: Path, line_color, threshold: int) -> Image.Image:
    src = Image.open(icon_path).convert("L")

    def to_alpha(p: int) -> int:
        if p >= threshold:
            return 0
        return int((threshold - p) / threshold * 255)

    alpha = src.point(to_alpha)
    out = Image.new("RGB", src.size, line_color)
    out.putalpha(alpha)
    return out


def paste_icon_centered(canvas: Image.Image, icon: Image.Image,
                         y_tag_mm: float, diam_mm: float) -> None:
    target = mm_to_px(diam_mm)
    icon = icon.copy()
    icon.thumbnail((target, target), Image.LANCZOS)
    cx = W // 2
    cy = mm_to_px(y_tag_mm)
    px = cx - icon.width // 2
    py = cy - icon.height // 2
    canvas.paste(icon, (px, py), icon)


def apply_circle_mask(img: Image.Image) -> Image.Image:
    """画像を円形にマスクする（円外を透明化）"""
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, W - 1, H - 1), fill=255)
    img = img.convert("RGBA")
    img.putalpha(mask)
    return img


# ============ メイン ============
def main() -> None:
    canvas = Image.new("RGB", (W, H), BG_COLOR)
    draw = ImageDraw.Draw(canvas)

    title_font = font_for_mm(FONT_SBL, TITLE_FS_MM)
    draw_centered_text(draw, "うちの子免許証", title_font, TITLE_Y_MM, INK_COLOR)

    line_art = extract_line_art(NFC_ICON, ICON_LINE_COLOR, ICON_THRESHOLD)
    paste_icon_centered(canvas, line_art, ICON_CENTER_Y_MM, ICON_DIAM_MM)

    nfc_font = font_for_mm(FONT_REG, NFC_FS_MM)
    draw_centered_text(draw, "NFC", nfc_font, NFC_Y_MM, INK_COLOR)

    catch_font = font_for_mm(FONT_REG, CATCH_FS_MM)
    draw_centered_text(draw, "スマホをかざしてね", catch_font, CATCH_Y_MM, INK_COLOR)

    final = apply_circle_mask(canvas)
    final.save(OUTPUT, dpi=(DPI, DPI))
    print(f"saved : {OUTPUT}")
    print(f"size  : {W} x {H} px @ {DPI} dpi (circle, transparent outside)")
    print(f"actual: Φ{TAG_DIA_MM}mm")


if __name__ == "__main__":
    main()

"""
うちの子免許証 カード裏面 印刷用テンプレート生成スクリプト

仕様:
  - 仕上がりサイズ: 85.6 x 54 mm (ISO/IEC 7810 ID-1)
  - 塗り足し: 各辺 3mm -> 全体 91.6 x 60 mm
  - 解像度: 350dpi -> 1262 x 827 px
  - 出力: card_back.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# ============ 基本設定 ============
DPI = 350
BLEED_MM = 3.0
CARD_W_MM = 85.6
CARD_H_MM = 54.0

ASSETS_DIR = Path(__file__).parent
FONT_REG = ASSETS_DIR.parent / "fonts" / "NotoSansJP-Regular.ttf"
FONT_SBL = ASSETS_DIR.parent / "fonts" / "NotoSansJP-SemiBold.ttf"
NFC_ICON = ASSETS_DIR / "nfc_icon.png"
OUTPUT = ASSETS_DIR / "card_back.png"

BG_COLOR = (255, 255, 255)
INK_COLOR = (70, 70, 70)
LINE_COLOR = (180, 180, 180)
ICON_LINE_COLOR = (50, 50, 50)
ICON_THRESHOLD = 100

# ============ レイアウト（mm基準、カード左上原点）============
TITLE_Y_MM = 8.0
TITLE_FS_MM = 3.2

TOP_LINE_Y_MM = 11.5
TOP_LINE_W_MM = 70.0

ICON_CENTER_Y_MM = 23.0
ICON_DIAM_MM = 14.0

NFC_Y_MM = 30.0
NFC_FS_MM = 1.9

CATCH_Y_MM = 37.5
CATCH_FS_MM = 2.4

BOTTOM_LINE_Y_MM = 43.0
BOTTOM_LINE_W_MM = 70.0

NOTE_Y_MM = 48.5
NOTE_FS_MM = 1.3

LINE_THICKNESS_MM = 0.2

# ============ 単位変換 ============
def mm_to_px(mm: float) -> int:
    return round(mm * DPI / 25.4)


W = mm_to_px(CARD_W_MM + BLEED_MM * 2)
H = mm_to_px(CARD_H_MM + BLEED_MM * 2)
CARD_TOP = mm_to_px(BLEED_MM)
LINE_THICKNESS_PX = max(2, mm_to_px(LINE_THICKNESS_MM))


# ============ 描画ユーティリティ ============
def font_for_mm(font_path: Path, fs_mm: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(font_path), mm_to_px(fs_mm))


def draw_centered_text(draw: ImageDraw.ImageDraw, text: str,
                        font: ImageFont.FreeTypeFont, y_card_mm: float,
                        ink) -> None:
    cx = W // 2
    cy = CARD_TOP + mm_to_px(y_card_mm)
    draw.text((cx, cy), text, fill=ink, font=font, anchor="mm")


def draw_horizontal_line(draw: ImageDraw.ImageDraw, y_card_mm: float,
                          w_mm: float, color) -> None:
    cx = W // 2
    cy = CARD_TOP + mm_to_px(y_card_mm)
    half = mm_to_px(w_mm) // 2
    draw.line([(cx - half, cy), (cx + half, cy)],
              fill=color, width=LINE_THICKNESS_PX)


def extract_line_art(icon_path: Path, line_color, threshold: int) -> Image.Image:
    """しきい値より明るいピクセルを透明化して線画だけ残す。
    threshold=140: それ以上明るい(灰色〜白)は完全透明、それ以下は明度に応じた不透明度。
    """
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
                         y_card_mm: float, diam_mm: float) -> None:
    target = mm_to_px(diam_mm)
    icon = icon.copy()
    icon.thumbnail((target, target), Image.LANCZOS)
    cx = W // 2
    cy = CARD_TOP + mm_to_px(y_card_mm)
    px = cx - icon.width // 2
    py = cy - icon.height // 2
    canvas.paste(icon, (px, py), icon)


# ============ メイン ============
def main() -> None:
    canvas = Image.new("RGB", (W, H), BG_COLOR)
    draw = ImageDraw.Draw(canvas)

    title_font = font_for_mm(FONT_SBL, TITLE_FS_MM)
    draw_centered_text(draw, "うちの子免許証", title_font, TITLE_Y_MM, INK_COLOR)

    draw_horizontal_line(draw, TOP_LINE_Y_MM, TOP_LINE_W_MM, LINE_COLOR)

    line_art = extract_line_art(NFC_ICON, ICON_LINE_COLOR, ICON_THRESHOLD)
    paste_icon_centered(canvas, line_art, ICON_CENTER_Y_MM, ICON_DIAM_MM)

    nfc_font = font_for_mm(FONT_REG, NFC_FS_MM)
    draw_centered_text(draw, "NFC", nfc_font, NFC_Y_MM, INK_COLOR)

    catch_font = font_for_mm(FONT_REG, CATCH_FS_MM)
    draw_centered_text(draw, "スマホをかざしてね", catch_font, CATCH_Y_MM, INK_COLOR)

    draw_horizontal_line(draw, BOTTOM_LINE_Y_MM, BOTTOM_LINE_W_MM, LINE_COLOR)

    note_font = font_for_mm(FONT_REG, NOTE_FS_MM)
    draw_centered_text(
        draw,
        "※この免許証はジョーク商品です。公的な効力はありません。",
        note_font, NOTE_Y_MM, INK_COLOR,
    )

    canvas.save(OUTPUT, dpi=(DPI, DPI))
    print(f"saved : {OUTPUT}")
    print(f"size  : {W} x {H} px @ {DPI} dpi")
    print(f"actual: {CARD_W_MM + BLEED_MM*2} x {CARD_H_MM + BLEED_MM*2} mm "
          f"(card {CARD_W_MM} x {CARD_H_MM} mm + bleed {BLEED_MM} mm)")


if __name__ == "__main__":
    main()

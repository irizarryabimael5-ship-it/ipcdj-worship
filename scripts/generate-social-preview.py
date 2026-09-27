#!/usr/bin/env python3
from __future__ import annotations

import ast
import io
import json
import re
import sys
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image, ImageCms, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "index.html"
OUTPUT = ROOT / "social-preview-v176.jpg"
WIDTH, HEIGHT = 1200, 630
TZ = ZoneInfo("America/New_York")

def font_path(*candidates: str) -> str:
    roots = [
        Path("/usr/share/fonts/truetype"),
        Path("/usr/share/fonts/opentype"),
        Path("/usr/local/share/fonts"),
    ]
    names = [c.lower().replace(" ", "") for c in candidates]
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.suffix.lower() not in {".ttf", ".otf"}:
                continue
            compact = path.stem.lower().replace(" ", "").replace("-", "")
            if any(name in compact for name in names):
                return str(path)
    return "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

REGULAR = font_path("InterRegular", "DejaVuSans")
SEMIBOLD = font_path("InterSemiBold", "DejaVuSans-Bold")
BOLD = font_path("InterBold", "DejaVuSans-Bold")
BLACK = font_path("InterBlack", "DejaVuSans-Bold")

def parse_catalog(source: str) -> list[dict]:
    marker = "const SONG_CATALOG_SOURCE = ["
    start = source.find(marker)
    if start < 0:
        return []
    start += len("const SONG_CATALOG_SOURCE = ")
    depth = 0
    quote = None
    escape = False
    end = None
    for i in range(start, len(source)):
        ch = source[i]
        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue
        if ch in {'"', "'"}:
            quote = ch
        elif ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        return []

    block = source[start:end]
    # Convert the small JS object literal shape used by the catalog to JSON-ish Python.
    block = re.sub(r'([,{]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:', r'\1"\2":', block)
    block = block.replace("true", "True").replace("false", "False").replace("null", "None")
    block = re.sub(r",\s*([}\]])", r"\1", block)
    try:
        value = ast.literal_eval(block)
        return value if isinstance(value, list) else []
    except Exception:
        return []

def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None

def phase(song: dict, now: datetime) -> str:
    learning_start = parse_time(song.get("learningStart"))
    learning_end = parse_time(song.get("learningEnd"))
    final_start = parse_time(song.get("finalStart"))
    final_end = parse_time(song.get("finalEnd"))
    release_day = parse_time(song.get("releaseDayStartAt") or song.get("releaseAt"))
    release_at = parse_time(song.get("releaseAt"))
    introduced = parse_time(song.get("introducedAt") or song.get("rolloverAt"))
    if not all([learning_start, learning_end, final_start, final_end, release_day, release_at, introduced]):
        return "upcoming"
    if now < learning_start:
        return "upcoming"
    if now <= learning_end:
        return "learning"
    if final_start <= now <= final_end or now < release_day:
        return "final"
    if now < release_at + timedelta(minutes=30):
        return "release"
    if now < introduced:
        return "released"
    return "complete"

def select_current(catalog: list[dict], now: datetime) -> dict | None:
    active = []
    for song in catalog:
        active_from = parse_time(song.get("activeFrom"))
        if not active_from or now < active_from:
            continue
        p = phase(song, now)
        if p == "complete":
            continue
        active.append((0 if p not in {"release", "released"} else 1, parse_time(song.get("releaseAt")) or now, song))
    active.sort(key=lambda item: (item[0], item[1]))
    if active:
        return active[0][2]
    return catalog[0] if catalog else None

def valid_palette(song: dict) -> list[tuple[int,int,int]]:
    raw = song.get("futurePalette") or []
    colors = []
    for item in raw[:3]:
        if isinstance(item, (list, tuple)) and len(item) >= 3:
            try:
                colors.append(tuple(max(0, min(255, int(v))) for v in item[:3]))
            except Exception:
                pass
    return colors if len(colors) >= 3 else [(36,76,118),(46,82,120),(28,55,84)]

def radial(size, center, radius, color, alpha):
    layer = Image.new("RGBA", size, (0,0,0,0))
    px = layer.load()
    cx,cy=center
    r,g,b=color
    xmin=max(0,int(cx-radius)); xmax=min(size[0],int(cx+radius)+1)
    ymin=max(0,int(cy-radius)); ymax=min(size[1],int(cy+radius)+1)
    for y in range(ymin,ymax):
        dy=y-cy
        for x in range(xmin,xmax):
            d=((x-cx)**2+dy**2)**0.5/radius
            if d <= 1:
                a=int(alpha*(1-d)**2)
                px[x,y]=(r,g,b,a)
    return layer

def rounded_mask(size, radius):
    mask=Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,size[0]-1,size[1]-1), radius=radius, fill=255)
    return mask

def fetch_artwork(url: str | None):
    if not url:
        return None
    try:
        req=urllib.request.Request(url, headers={"User-Agent":"IPCDJ-Social-Preview/1.0"})
        with urllib.request.urlopen(req, timeout=12) as response:
            data=response.read(6_000_000)
        return Image.open(io.BytesIO(data)).convert("RGB")
    except Exception:
        return None

def fit_cover(image: Image.Image, size):
    w,h=size
    scale=max(w/image.width,h/image.height)
    resized=image.resize((round(image.width*scale),round(image.height*scale)), Image.Resampling.LANCZOS)
    left=(resized.width-w)//2
    top=(resized.height-h)//2
    return resized.crop((left,top,left+w,top+h))

def render():
    source=INDEX.read_text(encoding="utf-8")
    catalog=parse_catalog(source)
    now=datetime.now(TZ)
    song=select_current(catalog, now) or {
        "title":"IPCDJ Worship",
        "artist":"Ministerio de Alabanza",
        "futurePalette":[[36,76,118],[46,82,120],[28,55,84]]
    }
    colors=valid_palette(song)
    dominant=colors[0]

    canvas=Image.new("RGB",(WIDTH,HEIGHT),(4,9,16)).convert("RGBA")
    for center,radius,color,alpha in [
        ((860,220),460,dominant,150),
        ((1120,535),360,colors[1],82),
        ((260,530),330,colors[2],64),
    ]:
        canvas=Image.alpha_composite(canvas, radial((WIDTH,HEIGHT),center,radius,color,alpha))

    draw=ImageDraw.Draw(canvas)
    brand=ImageFont.truetype(BOLD, 18)
    title=ImageFont.truetype(BLACK, 55)
    sub=ImageFont.truetype(SEMIBOLD, 24)
    body=ImageFont.truetype(REGULAR, 18)
    mini=ImageFont.truetype(BOLD, 15)
    card_title=ImageFont.truetype(BLACK, 36)
    card_artist=ImageFont.truetype(REGULAR, 19)
    card_status=ImageFont.truetype(BOLD, 14)
    banner_title=ImageFont.truetype(BLACK, 21)
    banner_body=ImageFont.truetype(REGULAR, 14)

    draw.rounded_rectangle((50,66,258,106), radius=20, fill=(7,22,35,225), outline=(53,168,211,160), width=2)
    draw.text((70,78),"IPCDJ WORSHIP",font=brand,fill=(232,248,255,255))
    draw.text((50,148),"Ministerio",font=title,fill=(255,255,255,255))
    draw.text((50,207),"de Alabanza",font=title,fill=(255,255,255,255))
    draw.text((51,303),"Canciones · preparación",font=sub,fill=(214,229,241,255))
    draw.text((51,338),"y estrenos en un solo lugar.",font=sub,fill=(214,229,241,255))
    draw.rounded_rectangle((52,398,358,401),radius=2,fill=(45,177,217,205))
    draw.text((51,425),"worship.ipcdj.org",font=body,fill=(157,194,217,255))
    draw.text((51,488),"Acceso rápido para el ministerio.",font=body,fill=(127,161,184,255))

    panel_box=(444,64,1166,566)
    pw=panel_box[2]-panel_box[0]; ph=panel_box[3]-panel_box[1]
    shadow=Image.new("RGBA",(pw+80,ph+80),(0,0,0,0))
    sm=Image.new("L",(pw+80,ph+80),0)
    ImageDraw.Draw(sm).rounded_rectangle((40,40,40+pw-1,40+ph-1),radius=30,fill=155)
    sm=sm.filter(ImageFilter.GaussianBlur(24))
    shadow.putalpha(sm)
    canvas.alpha_composite(shadow,(panel_box[0]-40,panel_box[1]-40))

    panel=Image.new("RGBA",(pw,ph),(5,13,22,244))
    pdraw=ImageDraw.Draw(panel)
    pdraw.rounded_rectangle((0,0,pw-1,ph-1),radius=28,fill=(5,13,22,244),outline=(102,178,221,112),width=2)

    # Top landing/header strip.
    pdraw.text((32,28),"IPCDJ Worship",font=ImageFont.truetype(BOLD,18),fill=(247,250,255,255))
    pdraw.text((32,54),"Ministerio de Alabanza",font=ImageFont.truetype(REGULAR,13),fill=(155,177,198,255))
    pdraw.rounded_rectangle((32,82,pw-32,126),radius=14,fill=(9,20,32,230),outline=(255,255,255,30),width=1)
    for x,label in [(55,"Spotify"),(275,"Apple Music"),(500,"YouTube Music")]:
        pdraw.text((x,96),label,font=mini,fill=(245,247,250,255))

    # Current song card.
    card=(32,146,pw-32,412)
    card_img=fetch_artwork(song.get("artworkUrl"))
    if card_img:
        art=fit_cover(card_img,(card[2]-card[0],card[3]-card[1]))
        art=ImageEnhance.Color(art).enhance(1.08)
        art=ImageEnhance.Contrast(art).enhance(1.05)
        art_rgba=art.convert("RGBA")
        # Dark readability veil.
        veil=Image.new("RGBA",art_rgba.size,(2,10,18,92))
        art_rgba=Image.alpha_composite(art_rgba,veil)
        mask=rounded_mask(art_rgba.size,22)
        art_rgba.putalpha(mask)
        panel.alpha_composite(art_rgba,(card[0],card[1]))
    else:
        pdraw.rounded_rectangle(card,radius=22,fill=(dominant[0],dominant[1],dominant[2],160))

    # cover-color glow + green release identity
    pdraw.rounded_rectangle(card,radius=22,outline=(56,173,141,165),width=2)
    current_phase=phase(song,now)
    status_text={
        "release":"HOY · ESTRENO",
        "released":"ESTRENADO",
        "learning":"AHORA EN PREPARACIÓN",
        "final":"AHORA EN PREPARACIÓN",
        "upcoming":"PRÓXIMA CANCIÓN"
    }.get(current_phase,"AHORA EN PREPARACIÓN")
    pdraw.rounded_rectangle((50,163,180,194),radius=16,fill=(6,28,36,220),outline=(43,185,137,175),width=1)
    pdraw.text((64,171),status_text,font=card_status,fill=(229,255,243,255))

    pdraw.text((50,214),str(song.get("title") or "IPCDJ Worship"),font=card_title,fill=(255,255,255,255))
    pdraw.text((50,256),str(song.get("artist") or "Ministerio de Alabanza"),font=card_artist,fill=(220,230,240,255))

    # Release/current banner; keep evergreen wording if not on release day.
    bx1,by1,bx2,by2=50,294,pw-50,375
    pdraw.rounded_rectangle((bx1,by1,bx2,by2),radius=17,fill=(6,17,27,224),outline=(45,143,119,150),width=1)
    if current_phase=="released":
        kicker="ESTRENADO"; btitle="ESTRENO COMPLETADO"; bbody="La canción ya fue presentada en el servicio."
    elif current_phase=="release":
        kicker="ESTRENO"; btitle="HOY ES EL DÍA"; bbody="La canción está en su día de estreno."
    else:
        kicker="PREPARACIÓN"; btitle="CAMINO AL ESTRENO"; bbody="Aprendizaje, preparación y adelantos en un solo lugar."
    pdraw.text((66,307),kicker,font=card_status,fill=(120,232,190,255))
    pdraw.text((66,329),btitle,font=banner_title,fill=(255,255,255,255))
    pdraw.text((66,356),bbody,font=banner_body,fill=(214,226,235,255))

    pdraw.rounded_rectangle((50,390,250,426),radius=18,fill=(176,132,53,210),outline=(239,185,74,210),width=1)
    pdraw.text((74,400),"▶  ADELANTO",font=mini,fill=(255,255,255,255))

    # Future section teaser.
    pdraw.text((32,438),"Después",font=ImageFont.truetype(BOLD,17),fill=(245,248,252,255))
    pdraw.text((32,464),"Próximas canciones programadas para prepararse.",font=ImageFont.truetype(REGULAR,12),fill=(158,177,196,255))
    pdraw.rounded_rectangle((32,488,pw-32,540),radius=15,fill=(15,24,38,230),outline=(255,255,255,28),width=1)

    panel.putalpha(rounded_mask((pw,ph),28))
    canvas.alpha_composite(panel,(panel_box[0],panel_box[1]))

    draw=ImageDraw.Draw(canvas)
    draw.text((950,584),"IPCDJ",font=ImageFont.truetype(BOLD,23),fill=(185,216,232,105))

    out=canvas.convert("RGB")
    srgb_profile=ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    out.save(
        OUTPUT,
        "JPEG",
        quality=90,
        optimize=True,
        progressive=True,
        subsampling=0,
        icc_profile=srgb_profile
    )
    if out.size != (1200,630):
        raise SystemExit("Unexpected social preview size")
    if OUTPUT.stat().st_size > 400_000:
        raise SystemExit("Social preview is unexpectedly large")
    print(json.dumps({
        "output":str(OUTPUT.relative_to(ROOT)),
        "bytes":OUTPUT.stat().st_size,
        "song":song.get("id",""),
        "phase":phase(song,now),
        "palette":colors,
        "generatedAt":now.isoformat()
    },ensure_ascii=False))

if __name__ == "__main__":
    render()

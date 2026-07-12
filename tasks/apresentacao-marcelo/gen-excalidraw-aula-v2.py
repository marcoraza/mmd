#!/usr/bin/env python3
"""Gera a aula visual v2 do motor MMD no Excalidraw.

Esta versao e screenshot-first: cada bloco nasce de uma tela real, e a escrita
explica o que aquela tela prova para o Marcelo.
"""
import base64
import json
import mimetypes
import struct
from pathlib import Path


OUT = Path("/Users/marko/Projects/mmd/tasks/apresentacao-marcelo/motor-mmd-aula-v2.excalidraw")
SCREEN_DIR = Path("/Users/marko/Projects/mmd/tasks/apresentacao-marcelo/screenshots")
UPDATED = 1750000000000

elements = []
files = {}
_seed = 5000


def nxt():
    global _seed
    _seed += 7
    return _seed


def base(eid, etype, x, y, w, h, **kw):
    return {
        "id": eid,
        "type": etype,
        "x": x,
        "y": y,
        "width": w,
        "height": h,
        "angle": 0,
        "strokeColor": kw.get("strokeColor", "#1e1e1e"),
        "backgroundColor": kw.get("backgroundColor", "transparent"),
        "fillStyle": kw.get("fillStyle", "solid"),
        "strokeWidth": kw.get("strokeWidth", 2),
        "strokeStyle": kw.get("strokeStyle", "solid"),
        "roughness": kw.get("roughness", 1),
        "opacity": kw.get("opacity", 100),
        "groupIds": kw.get("groupIds", []),
        "frameId": None,
        "roundness": kw.get("roundness", {"type": 3}),
        "seed": nxt(),
        "version": 1,
        "versionNonce": nxt(),
        "isDeleted": False,
        "boundElements": kw.get("boundElements", None),
        "updated": UPDATED,
        "link": None,
        "locked": False,
    }


def measure_text(text, font):
    lines = str(text).split("\n")
    return max(10, int(max(len(line) for line in lines) * font * 0.54)), int(len(lines) * font * 1.25)


def text(eid, x, y, body, font=18, color="#1e1e1e", align="left", container=None):
    w, h = measure_text(body, font)
    el = base(eid, "text", x, y, w, h, strokeColor=color, roundness=None)
    el.update({
        "text": body,
        "fontSize": font,
        "fontFamily": 1,
        "textAlign": align,
        "verticalAlign": "top" if container is None else "middle",
        "containerId": container,
        "originalText": body,
        "lineHeight": 1.25,
        "autoResize": True,
        "baseline": int(font * 0.9),
    })
    elements.append(el)
    return el


def box(eid, x, y, w, h, label="", fill="#ffffff", stroke="#1e1e1e", font=18, color="#1e1e1e", roughness=1):
    tid = f"{eid}_t"
    bound = [{"type": "text", "id": tid}] if label else None
    elements.append(base(
        eid,
        "rectangle",
        x,
        y,
        w,
        h,
        backgroundColor=fill,
        strokeColor=stroke,
        roughness=roughness,
        boundElements=bound,
    ))
    if label:
        tw, th = measure_text(label, font)
        text(tid, x + (w - tw) / 2, y + (h - th) / 2, label, font, color, "center", eid)


def line(eid, x, y, dx, dy, label=None, color="#1e1e1e", font=14):
    bound = [{"type": "text", "id": f"{eid}_t"}] if label else None
    el = base(eid, "arrow", x, y, abs(dx), abs(dy), strokeColor=color, boundElements=bound, roundness=None)
    el.update({
        "points": [[0, 0], [dx, dy]],
        "lastCommittedPoint": None,
        "startBinding": None,
        "endBinding": None,
        "startArrowhead": None,
        "endArrowhead": "arrow",
    })
    elements.append(el)
    if label:
        tx = x + dx / 2
        ty = y + dy / 2
        tw, th = measure_text(label, font)
        text(f"{eid}_t", tx - tw / 2, ty - th / 2, label, font, color, "center", eid)


def image_size(path):
    raw = path.read_bytes()
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return struct.unpack(">II", raw[16:24])
    if raw.startswith(b"\xff\xd8"):
        i = 2
        while i < len(raw):
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            i += 2
            if marker in (0xD8, 0xD9):
                continue
            size = struct.unpack(">H", raw[i:i + 2])[0]
            if marker in (0xC0, 0xC2):
                height, width = struct.unpack(">HH", raw[i + 3:i + 7])
                return width, height
            i += size
    raise ValueError(f"imagem nao suportada: {path}")


def add_image(eid, file_name, x, y, w):
    path = SCREEN_DIR / file_name
    assert path.exists(), f"print ausente: {path}"
    iw, ih = image_size(path)
    h = int(w * ih / iw)
    mime = mimetypes.guess_type(str(path))[0] or "image/png"
    raw = path.read_bytes()
    file_id = f"{eid}_file"
    files[file_id] = {
        "id": file_id,
        "mimeType": mime,
        "dataURL": f"data:{mime};base64,{base64.b64encode(raw).decode('ascii')}",
        "created": UPDATED,
        "lastRetrieved": UPDATED,
    }
    img = base(eid, "image", x, y, w, h, strokeColor="transparent", backgroundColor="transparent", strokeWidth=1, roughness=0)
    img.update({"fileId": file_id, "status": "saved", "scale": [1, 1], "crop": None})
    elements.append(img)
    return h


def sticky(eid, x, y, w, h, title, body, fill="#fff3bf", stroke="#f59e0b"):
    box(eid, x, y, w, h, "", fill, stroke, roughness=1)
    text(f"{eid}_title", x + 18, y + 16, title, 17, "#1e1e1e")
    text(f"{eid}_body", x + 18, y + 48, body, 15, "#575757")


def badge(eid, x, y, label, fill, stroke):
    box(eid, x, y, 130, 38, label, fill, stroke, 15)


# Paleta alinhada ao handoff, com cara de quadro branco.
BLUE_F, BLUE_S = "#a5d8ff", "#4a9eed"
PURP_F, PURP_S = "#d0bfff", "#8b5cf6"
TEAL_F, TEAL_S = "#c3fae8", "#06b6d4"
YEL_F, YEL_S = "#fff3bf", "#f59e0b"
GREEN_F, GREEN_S = "#b2f2bb", "#22c55e"
GRAY_F, GRAY_S = "#f8f9fa", "#adb5bd"


# =========================================================
# BLOCO 1
# =========================================================
text("b1_title", 120, 70, "1. O sistema visto de fora", 34)
text(
    "b1_sub",
    120,
    118,
    "Antes de explicar banco, motor ou RFID, Marcelo precisa reconhecer as duas portas de uso.",
    18,
    "#757575",
)

# Mock de browser, inspirado nos componentes de library.
box("b1_browser_frame", 120, 190, 680, 470, "", "#ffffff", GRAY_S, roughness=1)
box("b1_browser_bar", 120, 190, 680, 42, "", GRAY_F, GRAY_S, roughness=1)
text("b1_browser_dots", 143, 203, "●  ●  ●", 15, "#adb5bd")
text("b1_browser_url", 245, 203, "web, escritório", 15, "#757575")
add_image("b1_dashboard", "board-dashboard.jpg", 140, 250, 640)
badge("b1_badge_web", 145, 690, "ESCRITÓRIO", BLUE_F, BLUE_S)
text("b1_web_caption", 295, 694, "gestão acompanha eventos, estoque e alertas", 16, "#1e1e1e")

# Mock de iPhone, inspirado nos componentes de library.
box("b1_phone_frame", 880, 165, 250, 545, "", "#111111", "#1e1e1e", roughness=1)
box("b1_phone_notch", 945, 185, 120, 28, "", "#000000", "#000000", roughness=0)
add_image("b1_ios", "board-ios-launch.jpg", 902, 225, 205)
badge("b1_badge_ios", 895, 735, "GALPÃO", TEAL_F, TEAL_S)
text("b1_ios_caption", 1045, 739, "iPhone executa leitura e conferência", 16, "#1e1e1e")

# Centro explicativo.
box("b1_center", 470, 745, 420, 105, "MESMO ESTOQUE\nMESMO MOTOR\nMESMA VERDADE", PURP_F, PURP_S, 20)
line("b1_line_web", 555, 690, 80, 55, "alimenta", BLUE_S, 14)
line("b1_line_ios", 980, 735, -115, 35, "executa", TEAL_S, 14)

sticky(
    "b1_note1",
    1180,
    235,
    330,
    120,
    "Tradução para Marcelo",
    "A web organiza a operação.\nO iPhone confirma o que acontece no galpão.",
    YEL_F,
    YEL_S,
)
sticky(
    "b1_note2",
    1180,
    390,
    330,
    120,
    "O ponto importante",
    "Não são dois sistemas.\nSão duas telas falando com a mesma base.",
    GREEN_F,
    GREEN_S,
)
line("b1_note_line", 1180, 445, -250, 250, "mesma fonte", PURP_S, 14)

text(
    "b1_talktrack",
    120,
    900,
    "Fala sugerida: primeiro mostra as telas. Depois explica que o motor fica entre a operação e o banco, conferindo, registrando e impedindo erro.",
    17,
    "#575757",
)


doc = {
    "type": "excalidraw",
    "version": 2,
    "source": "https://excalidraw.com",
    "elements": elements,
    "appState": {"viewBackgroundColor": "#ffffff", "gridSize": None},
    "files": files,
}

OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")

ids = [e["id"] for e in elements]
assert len(ids) == len(set(ids)), "ids duplicados"
for e in elements:
    if e.get("containerId"):
        assert e["containerId"] in ids, f"containerId órfão: {e['id']}"
    if e.get("boundElements"):
        for b in e["boundElements"]:
            assert b["id"] in ids, f"boundElement órfão em {e['id']}"
    if e["type"] == "image":
        assert e.get("fileId") in files, f"imagem sem arquivo: {e['id']}"
payload = json.dumps(doc, ensure_ascii=False)
assert "\u2014" not in payload, "em-dash proibido encontrado"
assert chr(0x2026) not in payload, "reticências proibidas encontradas"
print("elementos:", len(elements))
print("imagens:", len(files))
print("OK, arquivo:", OUT)

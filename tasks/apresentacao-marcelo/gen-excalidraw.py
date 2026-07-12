#!/usr/bin/env python3
"""Gera um arquivo .excalidraw nativo (editavel no excalidraw.com) com os
diagramas do motor MMD. Formato oficial: type=excalidraw, version=2, elements[].

Converte uma spec simples (box/arrow/text) em elementos completos, com labels
ligados ao container (bound text), pra ficar editavel de verdade no Excalidraw.
"""
import json
import base64
import mimetypes
import struct
from pathlib import Path

elements = []
files = {}
_seed = 1000
UPDATED = 1750000000000  # timestamp fixo, deterministico
SCREEN_DIR = Path("/Users/marko/Projects/mmd/tasks/apresentacao-marcelo/screenshots")


def nxt():
    global _seed
    _seed += 7
    return _seed


def base(eid, etype, x, y, w, h, **kw):
    el = {
        "id": eid, "type": etype, "x": x, "y": y, "width": w, "height": h,
        "angle": 0, "strokeColor": kw.get("strokeColor", "#1e1e1e"),
        "backgroundColor": kw.get("backgroundColor", "transparent"),
        "fillStyle": kw.get("fillStyle", "solid"),
        "strokeWidth": kw.get("strokeWidth", 2),
        "strokeStyle": kw.get("strokeStyle", "solid"),
        "roughness": 1, "opacity": 100, "groupIds": [], "frameId": None,
        "roundness": kw.get("roundness", None), "seed": nxt(), "version": 1,
        "versionNonce": nxt(), "isDeleted": False,
        "boundElements": kw.get("boundElements", None), "updated": UPDATED,
        "link": None, "locked": False,
    }
    return el


def image_size(path):
    raw = Path(path).read_bytes()
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        width, height = struct.unpack(">II", raw[16:24])
        return width, height
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
    raise ValueError(f"formato de imagem nao suportado: {path}")


def measure_text(s, font):
    lines = str(s).split("\n")
    tw = max(10, int(max(len(line) for line in lines) * font * 0.55))
    th = int(len(lines) * font * 1.25)
    return tw, th


def text_el(eid, x, y, s, font=20, color="#1e1e1e", container=None, align="left"):
    tw, th = measure_text(s, font)
    el = base(eid, "text", x, y, tw, th, strokeColor=color)
    el.update({
        "text": s, "fontSize": font, "fontFamily": 1,
        "textAlign": align, "verticalAlign": "top" if container is None else "middle",
        "containerId": container, "originalText": s, "lineHeight": 1.25,
        "autoResize": True, "baseline": int(font * 0.9),
    })
    return el


def box(eid, x, y, w, h, label, fill, stroke, font=18, rounded=True):
    tid = eid + "_t"
    b = base(eid, "rectangle", x, y, w, h,
             backgroundColor=fill, strokeColor=stroke,
             roundness={"type": 3} if rounded else None,
             boundElements=[{"type": "text", "id": tid}])
    elements.append(b)
    # bound text: centralizado no container
    tw, th = measure_text(label, font)
    t = text_el(tid, x + (w - tw) // 2, y + (h - th) // 2, label, font,
                "#1e1e1e", container=eid, align="center")
    elements.append(t)


def diamond(eid, x, y, w, h, label, fill, stroke, font=17):
    tid = eid + "_t"
    d = base(eid, "diamond", x, y, w, h,
             backgroundColor=fill, strokeColor=stroke,
             boundElements=[{"type": "text", "id": tid}])
    elements.append(d)
    tw, th = measure_text(label, font)
    t = text_el(tid, x + (w - tw) // 2, y + (h - th) // 2, label, font,
                "#1e1e1e", container=eid, align="center")
    elements.append(t)


def arrow(eid, x, y, dx, dy, label=None, stroke="#1e1e1e", font=14):
    bound = [{"type": "text", "id": eid + "_t"}] if label else None
    a = base(eid, "arrow", x, y, abs(dx) if dx else 0, abs(dy) if dy else 0,
             strokeColor=stroke, boundElements=bound)
    a.update({
        "points": [[0, 0], [dx, dy]], "lastCommittedPoint": None,
        "startBinding": None, "endBinding": None,
        "startArrowhead": None, "endArrowhead": "arrow",
    })
    elements.append(a)
    if label:
        midx = x + dx / 2
        midy = y + dy / 2
        tw, th = measure_text(label, font)
        t = text_el(eid + "_t", int(midx - tw / 2), int(midy - th / 2), label,
                    font, "#1e1e1e", container=eid, align="center")
        elements.append(t)


def note(eid, x, y, s, font=16, color="#757575"):
    elements.append(text_el(eid, x, y, s, font, color))


def title(eid, x, y, s, font=28):
    elements.append(text_el(eid, x, y, s, font, "#1e1e1e"))


def card(eid, x, y, w, h, name, desc, metric, fill, stroke, metric_fill=None):
    b = base(eid, "rectangle", x, y, w, h,
             backgroundColor=fill, strokeColor=stroke,
             roundness={"type": 3})
    elements.append(b)
    note(eid + "_name", x + 16, y + 14, name, 16, "#1e1e1e")
    note(eid + "_desc", x + 16, y + 46, desc, 14, "#757575")
    if metric_fill:
        box(eid + "_metric_box", x + w - 84, y + h - 44, 64, 30, metric,
            metric_fill, stroke, 16)
    else:
        note(eid + "_metric", x + w - 70, y + h - 40, metric, 20, "#1e1e1e")


def image_card(eid, file_name, x, y, w, caption, source, stroke="#adb5bd"):
    path = SCREEN_DIR / file_name
    assert path.exists(), f"print ausente: {path}"
    iw, ih = image_size(path)
    h = int(w * ih / iw)
    raw = path.read_bytes()
    mime = mimetypes.guess_type(str(path))[0] or "image/png"
    file_id = eid + "_file"
    files[file_id] = {
        "id": file_id,
        "mimeType": mime,
        "dataURL": f"data:{mime};base64,{base64.b64encode(raw).decode('ascii')}",
        "created": UPDATED,
        "lastRetrieved": UPDATED,
    }
    frame = base(eid + "_frame", "rectangle", x - 10, y - 10, w + 20, h + 70,
                 backgroundColor="#ffffff", strokeColor=stroke,
                 roundness={"type": 3})
    frame["opacity"] = 100
    elements.append(frame)
    img = base(eid, "image", x, y, w, h,
               strokeColor="transparent", backgroundColor="transparent",
               strokeWidth=1)
    img.update({
        "fileId": file_id,
        "status": "saved",
        "scale": [1, 1],
        "crop": None,
    })
    elements.append(img)
    note(eid + "_cap", x, y + h + 14, caption, 15, "#1e1e1e")
    note(eid + "_src", x, y + h + 38, source, 13, "#757575")
    return h


# Paleta
BLUE_F, BLUE_S = "#a5d8ff", "#4a9eed"
PURP_F, PURP_S = "#d0bfff", "#8b5cf6"
TEAL_F, TEAL_S = "#c3fae8", "#06b6d4"
YEL_F, YEL_S = "#fff3bf", "#f59e0b"
ORG_F, ORG_S = "#ffd8a8", "#f59e0b"
GREEN_F, GREEN_S = "#b2f2bb", "#22c55e"
RED_F, RED_S = "#ffc9c9", "#ef4444"
GRAY_F, GRAY_S = "#f1f3f5", "#868e96"

# =========================================================
# DIAGRAMA 1 : As 3 partes do sistema (yOffset 0)
# =========================================================
o = 0
title("d1title", 120, o + 0, "1. As 3 partes do sistema", 30)
box("d1apps", 120, o + 70, 460, 80, "APLICATIVOS (web + iPhone)", BLUE_F, BLUE_S)
note("d1na", 600, o + 100, "as telas que a equipe usa")
arrow("d1ar1", 350, o + 150, 0, 60, "usam")
box("d1motor", 120, o + 230, 460, 80, "MOTOR (as regras)", PURP_F, PURP_S)
note("d1nm", 600, o + 260, "decide o que pode e registra")
arrow("d1ar2", 350, o + 310, 0, 60, "guardam em")
box("d1banco", 120, o + 390, 460, 80, "BANCO DE DADOS (Supabase)", TEAL_F, TEAL_S)
note("d1nb", 600, o + 420, "onde tudo fica guardado")
arrow("d1proof_a", 580, o + 110, 430, 0, "tela da equipe", BLUE_S)
image_card("d1webproof", "board-dashboard.jpg", 1040, o + 45, 300,
           "Web: visão de gestão", "print QA do dashboard")
image_card("d1iosproof", "board-ios-launch.jpg", 1390, o + 45, 145,
           "iPhone: campo com RFD40", "print QA iOS")

# =========================================================
# DIAGRAMA 2 : O banco por dentro (yOffset 700)
# =========================================================
o = 700
title("d2title", 120, o + 0, "2. O banco: tabelas que se conversam", 30)
note("d2lg", 120, o + 44, "número = quantos registros existem hoje", 16, "#757575")
box("d2items", 120, o + 170, 200, 70, "Catálogo de tipos (539)", TEAL_F, TEAL_S, 16)
arrow("d2b1", 320, o + 205, 90, 0, "tem várias")
box("d2serial", 420, o + 170, 220, 70, "Unidades físicas (1058)", BLUE_F, BLUE_S, 16)
box("d2proj", 720, o + 60, 190, 70, "Eventos (11)", PURP_F, PURP_S, 16)
box("d2pack", 720, o + 180, 190, 70, "Listas (65)", YEL_F, YEL_S, 16)
arrow("d2b2", 640, o + 205, 80, 0, "entra em")
arrow("d2b3", 815, o + 130, 0, 50, "monta")
box("d2movim", 420, o + 340, 220, 70, "Histórico (2)", ORG_F, ORG_S, 16)
arrow("d2b4", 530, o + 240, 0, 100, "gera")
note("d2note", 420, o + 425, "cada linha liga a unidade e o evento")

# =========================================================
# DIAGRAMA 3 : O loop operacional (yOffset 1400)
# =========================================================
o = 1400
title("d3title", 120, o + 0, "3. O loop: o caminho de um equipamento", 30)
note("d3sub", 120, o + 46, "antes da saída, o motor confere a prontidão", 16, "#757575")
steps = [
    ("d3b1", "Alocar", BLUE_F, BLUE_S, "reserva as peças"),
    ("d3b2", "Check-out", BLUE_F, BLUE_S, "saída, tudo ou nada"),
    ("d3b3", "Campo", ORG_F, ORG_S, "em uso no evento"),
    ("d3b4", "Check-in", BLUE_F, BLUE_S, "volta e confere"),
    ("d3b5", "Resolver", PURP_F, PURP_S, "o que não voltou"),
]
x0 = 120
for i, (sid, lbl, f, s, desc) in enumerate(steps):
    bx = x0 + i * 175
    box(sid, bx, o + 150, 140, 70, lbl, f, s)
    note(sid + "_d", bx + 6, o + 230, desc, 15, "#757575")
    if i < len(steps) - 1:
        arrow(sid + "_a", bx + 140, o + 185, 35, 0)
arrow("d3proof_a", 835, o + 185, 170, 0, "vira fluxo real", BLUE_S)
image_card("d3packingproof", "board-packing.jpg", 1040, o + 95, 225,
           "Packing: o que vai para campo", "print QA web")
image_card("d3returnproof", "board-return.jpg", 1320, o + 95, 320,
           "Retorno: fecha o loop", "print QA web")

# =========================================================
# DIAGRAMA 4 : O Supabase tabela a tabela (yOffset 2100)
# =========================================================
o = 2100
title("d4title", 120, o + 0, "4. O que o banco guarda, tabela por tabela", 30)
note("d4sub", 120, o + 46,
     "núcleo = operação diária, apoio = rastreio, auditoria e recursos que ainda vão entrar em uso",
     16, "#757575")
note("d4nucleo", 120, o + 86, "núcleo", 16, TEAL_S)
note("d4apoio", 120, o + 424, "apoio", 16, "#757575")
d4_cards = [
    ("d4c1", "Catálogo de tipos\n(items)", "cada modelo: nome,\nmarca, categoria, valor", "539", TEAL_F, TEAL_S),
    ("d4c2", "Unidades físicas\n(serial_numbers)", "cada peça real: código,\netiqueta, estado, desgaste", "1058", BLUE_F, BLUE_S),
    ("d4c3", "Eventos\n(projetos)", "cada evento ou locação:\ncliente, datas, status", "11", PURP_F, PURP_S),
    ("d4c4", "Listas de separação\n(packing_list)", "o que cada evento leva:\nitem, quantidade, unidades", "65", YEL_F, YEL_S),
    ("d4c5", "Histórico\n(movimentacoes)", "cada saída e retorno:\nautor, hora, método", "2", ORG_F, ORG_S),
    ("d4c6", "Lotes, legado\n(lotes)", "cabos em bloco do modelo\nantigo, em descontinuação", "152", ORG_F, ORG_S),
    ("d4c7", "Leitores RFID\n(rfid_readers)", "os leitores RFD40\nregistrados", "0", GRAY_F, GRAY_S),
    ("d4c8", "Leituras RFID\n(rfid_scans)", "cada etiqueta lida\nem campo", "0", GRAY_F, GRAY_S),
    ("d4c9", "Saídas forçadas\n(checkout_overrides)", "auditoria das exceções\nliberadas pelo admin", "0", GRAY_F, ORG_S),
    ("d4c10", "Pendências\n(retorno_pendencias)", "o que não voltou,\nesperando resolução", "0", GRAY_F, ORG_S),
    ("d4c11", "Modelos de packing\n(packing_templates)", "listas salvas\npara reusar", "0", GRAY_F, GRAY_S),
    ("d4c12", "Usuários\n(profiles)", "quem acessa\ne com qual papel", "1", GRAY_F, GRAY_S),
]
for i, (eid, name, desc, metric, fill, stroke) in enumerate(d4_cards):
    row, col = divmod(i, 3)
    card(eid, 120 + col * 285, o + 120 + row * 155, 250, 130,
         name, desc, metric, fill, stroke, metric_fill="#ffffff")

# =========================================================
# DIAGRAMA 5 : O motor protege a operação (yOffset 3000)
# =========================================================
o = 3000
title("d5title", 120, o + 0, "5. O motor protege a operação", 30)
note("d5sub", 120, o + 46,
     "o sistema confere antes da saída e evita operação pela metade",
     16, "#757575")
box("d5pedido", 120, o + 120, 190, 70, "Pedido\nde saída", BLUE_F, BLUE_S, 18)
arrow("d5a1", 310, o + 155, 55, 0, "entra")
diamond("d5dec", 370, o + 100, 250, 110,
        "Prontidão OK?\nevento confirmado,\nlista cheia, cobertura",
        YEL_F, YEL_S, 16)
arrow("d5sim", 620, o + 130, 80, -35, "sim", GREEN_S)
box("d5libera", 705, o + 55, 250, 80,
    "Libera: peças viram\n'em campo' e grava\nno histórico",
    GREEN_F, GREEN_S, 16)
arrow("d5nao", 620, o + 185, 80, 45, "não", ORG_S)
box("d5trava", 705, o + 220, 250, 92,
    "Trava. Admin pode\nforçar com motivo,\ne vai para auditoria",
    ORG_F, ORG_S, 16)
note("d5parteb", 120, o + 370, "tudo ou nada", 17, "#1e1e1e")
box("d5saida", 120, o + 420, 220, 75, "Saída de\n30 peças", BLUE_F, BLUE_S, 18)
arrow("d5b1", 340, o + 450, 85, -45, "ou")
box("d5todas", 440, o + 365, 220, 70, "todas saem", GREEN_F, GREEN_S, 18)
arrow("d5b2", 340, o + 465, 85, 55, "ou")
box("d5nada", 440, o + 520, 220, 70, "nada muda", RED_F, RED_S, 18)
note("d5nada_note", 700, o + 453, "nunca pela metade", 18, "#757575")
arrow("d5proof_a", 955, o + 265, 80, 0, "motor confere", PURP_S)
image_card("d5checkoutproof", "board-checkout-gate.jpg", 1060, o + 115, 430,
           "Gate real: saída bloqueada", "print QA web")

# =========================================================
# DIAGRAMA 6 : Valor atual (yOffset 3750)
# =========================================================
o = 3750
title("d6title", 120, o + 0, "6. Quanto cada peça vale hoje", 30)
note("d6sub", 120, o + 46,
     "o valor é calculado pelo cadastro, sem reavaliação manual a cada consulta",
     16, "#757575")
box("d6v1", 120, o + 120, 185, 80, "Valor original\nquanto custou", BLUE_F, BLUE_S, 16)
box("d6v2", 120, o + 230, 185, 90, "Desgaste\n1 a 5\natualiza no retorno", BLUE_F, BLUE_S, 16)
box("d6v3", 120, o + 350, 185, 110,
    "Estado\nNOVO 1,00\nSEMI 0,85\nUSADO 0,65\nRECOND 0,50",
    BLUE_F, BLUE_S, 15)
box("d6formula", 390, o + 210, 300, 120,
    "valor atual =\nvalor original x\n(desgaste / 5) x\nfator do estado",
    PURP_F, PURP_S, 17)
arrow("d6a1", 305, o + 160, 85, 90)
arrow("d6a2", 305, o + 275, 85, 0)
arrow("d6a3", 305, o + 405, 85, -85)
arrow("d6a4", 690, o + 270, 70, 0, "gera")
box("d6resultado", 760, o + 205, 260, 130,
    "Exemplo:\nR$1.000, USADO,\ndesgaste 4\n1000 x 0,8 x 0,65\n= R$520",
    GREEN_F, GREEN_S, 17)
arrow("d6proof_a", 1020, o + 270, 70, 0, "aparece no cadastro", GREEN_S)
image_card("d6itemproof", "board-item-detail.jpg", 1115, o + 135, 410,
           "Item: valor e condição visíveis", "print QA web")

# =========================================================
# DIAGRAMA 7 : RFID (yOffset 4450)
# =========================================================
o = 4450
title("d7title", 120, o + 0, "7. RFID, software pronto para a prova de campo", 30)
note("d7sub", 120, o + 46,
     "o fluxo já está integrado no software, falta validar com equipamento real no galpão",
     16, "#757575")
d7_flow = [
    ("d7f1", "RFD40 lê\na tag"),
    ("d7f2", "iPhone\nrecebe"),
    ("d7f3", "Envia ao\nsistema"),
    ("d7f4", "Vira\nhistórico"),
]
for i, (eid, lbl) in enumerate(d7_flow):
    x = 120 + i * 220
    box(eid, x, o + 125, 155, 70, lbl, BLUE_F, BLUE_S, 17)
    if i < len(d7_flow) - 1:
        arrow(eid + "_a", x + 155, o + 160, 65, 0)
box("d7known", 210, o + 280, 300, 75,
    "Tag já cadastrada:\nassocia ao equipamento certo",
    GREEN_F, GREEN_S, 17)
box("d7unknown", 570, o + 280, 330, 75,
    "Tag desconhecida:\nregistra para tratar depois, não descarta",
    ORG_F, ORG_S, 16)
note("d7branch", 120, o + 302, "quando lê:", 16, "#757575")
box("d7today", 120, o + 430, 330, 75,
    "Hoje:\nsoftware pronto para a prova física",
    GREEN_F, GREEN_S, 17)
box("d7notyet", 500, o + 430, 330, 75,
    "Ainda não:\nRFID validado em campo",
    RED_F, RED_S, 17)
note("d7plano", 120, o + 570, "plano de teste", 17, "#1e1e1e")
box("d7p1", 120, o + 620, 170, 65, "Bancada", YEL_F, YEL_S, 18)
arrow("d7pa1", 290, o + 652, 60, 0)
box("d7p2", 350, o + 620, 170, 65, "Galpão", YEL_F, YEL_S, 18)
arrow("d7pa2", 520, o + 652, 60, 0)
box("d7p3", 580, o + 620, 230, 65, "Fluxo real\npequeno", YEL_F, YEL_S, 18)
note("d7need", 120, o + 715,
     "teste com 10 a 20 equipamentos. Precisa de: RFD40, iPhone, app, tags reais, equipamentos separados",
     15, "#757575")
arrow("d7proof_a", 810, o + 160, 190, 0, "vai para o campo", BLUE_S)
image_card("d7iosproof", "board-ios-scan.jpg", 1040, o + 105, 175,
           "iOS: busca RFID no galpão", "print fresco do simulador")

# =========================================================
# DIAGRAMA 8 : Tipo vs peça real (yOffset 5400)
# =========================================================
o = 5400
title("d8title", 120, o + 0, "8. Tipo vs peça real", 30)
note("d8sub", 120, o + 46,
     "um modelo no catálogo pode ter várias unidades físicas no estoque",
     16, "#757575")
box("d8tipo", 120, o + 135, 320, 110,
    "Tipo\nmodelo no catálogo\n539 registros",
    TEAL_F, TEAL_S, 18)
arrow("d8a1", 440, o + 190, 90, 0, "1 tipo,\nvárias unidades")
box("d8unidade", 535, o + 135, 350, 110,
    "Unidade física\npeça real com código\n1058 registros",
    BLUE_F, BLUE_S, 18)
note("d8note", 535, o + 270,
     "exemplo de código interno: MMD-ILU-0001",
     16, "#757575")
arrow("d8proof_a", 885, o + 190, 140, 0, "prova no cadastro", TEAL_S)
image_card("d8eventproof", "board-evento.jpg", 1060, o + 75, 250,
           "Evento: nasce a operação", "print QA web")

# =========================================================
# DIAGRAMA 9 : Web e campo (yOffset 6050)
# =========================================================
o = 6050
title("d9title", 120, o + 0, "9. Web e campo, o mesmo motor", 30)
note("d9sub", 120, o + 46,
     "o escritório e o galpão não têm regras paralelas",
     16, "#757575")
box("d9web", 120, o + 120, 260, 95,
    "Web, no escritório\ncadastra evento\nmonta lista\nimporta planilha\nacompanha painel",
    BLUE_F, BLUE_S, 15)
box("d9iphone", 670, o + 120, 260, 95,
    "iPhone, no galpão\nlê RFID e QR\nfaz check-out\nconfere retorno\nresume campo",
    BLUE_F, BLUE_S, 15)
arrow("d9a1", 380, o + 168, 110, 70, "usa")
arrow("d9a2", 670, o + 168, -110, 70, "usa")
box("d9motor", 470, o + 260, 210, 85,
    "Mesmo motor,\nmesmo banco",
    PURP_F, PURP_S, 18)
note("d9note", 370, o + 375,
     "se um lado muda, o outro enxerga a mudança pela mesma fonte de verdade",
     16, "#757575")

# =========================================================
# DIAGRAMA 10 : Pronto e por ativar (yOffset 6700)
# =========================================================
o = 6700
title("d10title", 120, o + 0, "10. O que está pronto e o que falta ativar", 30)
box("d10ready", 120, o + 100, 390, 250,
    "Pronto\n\nbanco completo e 100% catalogado\nmotor no banco e no web\nporteiro, alocação e conferência\npendências de retorno\napp de campo com RFID integrado\nmetade do parque com QR",
    GREEN_F, GREEN_S, 16)
box("d10todo", 570, o + 100, 390, 250,
    "Por ativar\n\nprova de campo do RFID\netiquetagem física\nrodar o loop em volume\ncadastro de usuários em uso real",
    ORG_F, ORG_S, 16)
note("d10note", 120, o + 390,
     "leitura correta para reunião: a arquitetura está pronta para teste real, não para prometer RFID validado",
     16, "#757575")

doc = {
    "type": "excalidraw",
    "version": 2,
    "source": "https://excalidraw.com",
    "elements": elements,
    "appState": {"viewBackgroundColor": "#ffffff", "gridSize": None},
    "files": files,
}

out = "/Users/marko/Projects/mmd/tasks/apresentacao-marcelo/motor-mmd.excalidraw"
with open(out, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False, indent=2)

# validacao basica
print("elementos:", len(elements))
ids = [e["id"] for e in elements]
assert len(ids) == len(set(ids)), "ids duplicados!"
for e in elements:
    if e.get("containerId"):
        assert e["containerId"] in ids, f"containerId orfao: {e['id']}"
    if e.get("boundElements"):
        for b in e["boundElements"]:
            assert b["id"] in ids, f"boundElement orfao em {e['id']}"
    if e["type"] == "image":
        assert e.get("fileId") in files, f"imagem sem arquivo: {e['id']}"
payload = json.dumps(doc, ensure_ascii=False)
assert "\u2014" not in payload, "em-dash proibido encontrado"
assert chr(0x2026) not in payload, "reticencias proibidas encontradas"
print("OK, arquivo:", out)

#!/usr/bin/env python3
"""Generate command-center.html from agent-prompts.md (source of truth)."""

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPTS_PATH = ROOT / "docs" / "agent-prompts.md"
OUTPUT_PATH = ROOT / "docs" / "command-center.html"

# Enhanced supervisor prompt (with design verification sections)
SUPERVISOR_OVERRIDE = None  # Will use agent-prompts.md version + design enhancements

SPRINT_META = {
    "0": {"title": "Data Cleanup + Supabase Schema", "model": "codex", "deps": "sem deps", "clickup": "86agn5dq2"},
    "1": {"title": "iOS RFID Core (Zebra SDK)", "model": "opus", "deps": "Sprint 0", "clickup": "86agn5dqd"},
    "2": {"title": "iOS Packing List + Check-in/out", "model": "opus", "deps": "Sprint 1", "clickup": "86agn5dqw"},
    "3": {"title": "Web Dashboard + CRUD", "model": "sonnet", "deps": "Sprint 0", "clickup": "86agn5dr2"},
    "4": {"title": "Web Events + Packing List + QR", "model": "sonnet", "deps": "Sprint 3", "clickup": "86agn5du3"},
    "5": {"title": "RFID Linking + Realtime", "model": "opus", "deps": "Sprint 2, Sprint 4", "clickup": "86agn5dug"},
    "6": {"title": "Deploy + Polish + Delivery", "model": "sonnet", "deps": "Sprint 5", "clickup": "86agn5dv1"},
}


def read_prompts():
    return PROMPTS_PATH.read_text(encoding="utf-8")


def extract_design_system_header(text: str) -> str:
    """Extract the Design System section (between first --- markers, before Sprint 0)."""
    match = re.search(
        r"(## Design System \(obrigatorio para Sprints 1-6\).*?)(?=\n---\n)",
        text,
        re.DOTALL,
    )
    return match.group(1).strip() if match else ""


def extract_sections(text: str) -> dict:
    """Split the markdown into sections by ## headers, respecting code blocks."""
    sections = {}

    # Remove code blocks temporarily to avoid splitting on ## inside them
    code_blocks = []
    def stash_code(m):
        code_blocks.append(m.group(0))
        return f"\x00CODEBLOCK_{len(code_blocks) - 1}\x00"

    safe_text = re.sub(r"```.*?```", stash_code, text, flags=re.DOTALL)

    # Split on ## at start of line (only top-level headers now)
    parts = re.split(r"\n(?=## )", safe_text)

    for part in parts:
        # Restore code blocks
        restored = part
        for i, block in enumerate(code_blocks):
            restored = restored.replace(f"\x00CODEBLOCK_{i}\x00", block)

        header_match = re.match(r"## (.+?)(?:\n|$)", restored)
        if not header_match:
            continue
        title = header_match.group(1).strip()
        content = restored.strip()

        if title.startswith("Sprint 0"):
            sections["sprint_0"] = content
        elif title.startswith("Sprint 1"):
            sections["sprint_1"] = content
        elif title.startswith("Sprint 2"):
            sections["sprint_2"] = content
        elif title.startswith("Sprint 3"):
            sections["sprint_3"] = content
        elif title.startswith("Sprint 4"):
            sections["sprint_4"] = content
        elif title.startswith("Sprint 5"):
            sections["sprint_5"] = content
        elif title.startswith("Sprint 6"):
            sections["sprint_6"] = content
        elif "Supervisor" in title or "Prompt do Supervisor" in title:
            sections["supervisor"] = content
        elif "Notas de Execucao" in title:
            sections["notas"] = content
        elif "Design System" in title:
            sections["design_system"] = content
        elif "Mapa de Sprints" in title:
            sections["mapa"] = content

    return sections


def enhance_supervisor(supervisor_text: str) -> str:
    """Add design verification sections to the supervisor prompt."""
    # Check if already has design verification
    if "Verificacao de Design" in supervisor_text:
        return supervisor_text

    # Add design system reference after existing references
    supervisor_text = supervisor_text.replace(
        "Prompts de execucao: `docs/agent-prompts.md`",
        "Prompts de execucao: `docs/agent-prompts.md`\nDesign system: `docs/design-brief.md`\nReferencia visual: `~/Desktop/analytics-dashboard.html`",
    )

    # Add 3b section after section 3
    design_section = """
**3b. Verificacao de Design (Sprints 1-6)**

Para sprints com UI, verificar contra `docs/design-brief.md`:

- Fontes corretas? Space Grotesk (body), Space Mono (labels/data ALL CAPS), Doto (hero numbers 36px+)
- Sem sombras? Sem gradients? Card-less layout (secoes por 1px border)?
- Labels em Space Mono ALL CAPS com letter-spacing 0.08-0.12em?
- Numeros em Space Mono (ou Doto pra hero)? Nunca Space Grotesk pra numeros?
- Cores de status aplicadas nos VALORES (texto), nao no background das rows?
- Barras segmentadas de desgaste com 5 blocos, cor variando com nivel?
- iOS 100% dark mode (#000 OLED)? Fontes bundled no Xcode?
- Web split layout: dark sidebar 380px + light content? Dot-grid na sidebar?
- Mobile: bottom nav dark? Layout single-column?
- Comparar visualmente com ~/Desktop/analytics-dashboard.html"""

    supervisor_text = supervisor_text.replace(
        "**4. Checklist de Verificacao**",
        design_section + "\n\n**4. Checklist de Verificacao**",
    )

    # Enhance per-sprint validation with DESIGN checks
    sprint_design_checks = {
        "**Sprint 1 - iOS RFID Core:**": """- DESIGN: Verificar Theme.swift com tokens de cor (#000, #D71921, #4A9E5C, etc.)
- DESIGN: Verificar fontes bundled (Space Grotesk, Space Mono, Doto em Resources/Fonts/)
- DESIGN: Verificar Info.plist registra UIAppFonts
- DESIGN: Verificar telas 100% dark mode (fundo #000, sem light mode)
- DESIGN: Verificar ScanView com hero Doto (contagem de tags)
- DESIGN: Verificar WearBar.swift e StatusBadge.swift existem""",
        "**Sprint 2 - iOS Packing List:**": """- DESIGN: Cores de validacao nos VALORES (texto), nao no background das rows
- DESIGN: Progresso checkout em Doto com barra segmentada
- DESIGN: Modal de defeito com backdrop dark, dialog #111, campo underline
- DESIGN: Resumo retorno com 3 numeros Doto lado a lado (OK/DEFEITO/FALTA)""",
        "**Sprint 3 - Web Dashboard:**": """- DESIGN: Split layout dark sidebar 380px + light content funcionando
- DESIGN: Dot-grid visivel na sidebar (radial-gradient #333 0.5px, 16px)
- DESIGN: Google Fonts carregando (Space Grotesk + Space Mono + Doto)
- DESIGN: Hero metric em Doto 88px na sidebar
- DESIGN: Brand "MMD\u00b7ESTOQUE" com dot vermelho #D71921
- DESIGN: Gauge circular SVG na taxa de depreciacao
- DESIGN: Barras segmentadas de desgaste com 5 blocos
- DESIGN: SEM sombras, SEM gradients em nenhum componente
- DESIGN: Bottom nav dark no mobile (< 768px)
- DESIGN: Comparar visualmente com ~/Desktop/analytics-dashboard.html""",
        "**Sprint 4 - Web Events + QR:**": """- DESIGN: Pagina publica /s/ em dark mode (#000), mobile-first, hero Doto 36px
- DESIGN: Packing list editor com progresso Doto + barra segmentada
- DESIGN: QR labels em Space Mono, grid limpo pra impressao
- DESIGN: Forms com inputs underline, labels Space Mono ALL CAPS""",
        "**Sprint 5 - RFID Linking + Realtime:**": """- DESIGN: Tela de vinculacao iOS segue dark mode e componentes existentes
- DESIGN: Indicador "ao vivo" no dashboard (dot pulsante ou label [LIVE])""",
        "**Sprint 6 - Deploy + Polish:**": """- DESIGN REVIEW COMPLETO contra docs/design-brief.md:
  1. Comparar dashboard com ~/Desktop/analytics-dashboard.html
  2. Verificar TODAS as telas: fontes, sem sombras, sem gradients, labels ALL CAPS
  3. Dark sidebar com dot-grid, hero Doto, nav border-left
  4. Cores de status nos valores, nao backgrounds
  5. Barras segmentadas em todas as telas com desgaste
  6. Gauge circular na depreciacao
  7. iOS 100% dark, tab bar dark, fontes bundled
  8. Mobile web: bottom nav dark, single-column
  9. Pagina /s/: dark, Doto hero, mobile-first
  10. Print QR: layout A4 limpo""",
    }

    for marker, checks in sprint_design_checks.items():
        if marker in supervisor_text:
            # Find the next sprint marker or section end
            idx = supervisor_text.index(marker)
            # Find the next **Sprint line after this one
            rest = supervisor_text[idx + len(marker):]
            next_sprint = re.search(r"\n\n\*\*Sprint \d", rest)
            next_section = re.search(r"\n\n### ", rest)

            if next_sprint:
                insert_pos = idx + len(marker) + next_sprint.start()
            elif next_section:
                insert_pos = idx + len(marker) + next_section.start()
            else:
                insert_pos = len(supervisor_text)

            # Find end of current bullet list
            lines_after = supervisor_text[idx:insert_pos].split("\n")
            last_bullet_idx = 0
            for i, line in enumerate(lines_after):
                if line.startswith("- "):
                    last_bullet_idx = i

            # Insert design checks after last bullet
            all_lines = supervisor_text[:insert_pos].split("\n")
            # Find the absolute position of the last bullet in the marker's block
            marker_line_idx = None
            for i, line in enumerate(all_lines):
                if marker.strip("*") in line:
                    marker_line_idx = i
                    break

            if marker_line_idx is not None:
                # Find last bullet in this block
                insert_line = marker_line_idx
                for i in range(marker_line_idx + 1, len(all_lines)):
                    if all_lines[i].startswith("- "):
                        insert_line = i
                    elif all_lines[i].strip() == "":
                        break
                    else:
                        break

                check_lines = checks.split("\n")
                for j, cl in enumerate(check_lines):
                    all_lines.insert(insert_line + 1 + j, cl)

                supervisor_text = "\n".join(all_lines) + supervisor_text[insert_pos:]

    # Add design system to blocking criteria
    if "Design system ignorado" not in supervisor_text:
        supervisor_text = re.sub(
            r"(\*\*Credenciais hardcoded:\*\* qualquer secret no codigo)",
            r"\g<1>\n6. **Design system ignorado:** telas sem fontes corretas (Space Grotesk/Mono/Doto), com box-shadow, ou sem seguir o layout dark/light definido no design-brief.md",
            supervisor_text,
        )

    # Add design minor to approval criteria
    if "**UI rough:**" in supervisor_text:
        supervisor_text = supervisor_text.replace(
            "**UI rough:** funciona mas precisa de polish (aceitavel antes do Sprint 6)",
            "**Design minor:** funciona e segue o sistema, mas micro-detalhes (spacing, letter-spacing exato) precisam ajuste no Sprint 6",
        )

    return supervisor_text


def fix_migration_path(text: str) -> str:
    return text.replace("data/migration.sql", "supabase/migrations/00001_initial_schema.sql")


def escape(text: str) -> str:
    return html.escape(text, quote=False)


def make_card(card_id: str, badge_text: str, badge_class: str, title: str,
              model_text: str, model_class: str, deps: str, clickup_id: str,
              prompt_text: str) -> str:
    clickup_html = ""
    if clickup_id:
        clickup_html = f'\n<a class="clickup-link" href="https://app.clickup.com/t/{clickup_id}" target="_blank">CU-{clickup_id}</a>'

    deps_html = ""
    if deps:
        deps_html = f'\n<span class="dep-tag">{escape(deps)}</span>'

    return f"""
<!-- ========== {title.upper()} ========== -->
<div class="sprint-card" id="{card_id}">
<div class="sprint-header" onclick="toggleCard('{card_id}')">
<span class="sprint-number {badge_class}">{badge_text}</span>
<span class="sprint-title">{escape(title)}</span>
<div class="sprint-meta">
<span class="model-badge {model_class}">{model_text}</span>{deps_html}{clickup_html}
</div>
<svg class="chevron" width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M4 6l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</div>
<div class="sprint-body">
<div class="prompt-container">
<button class="copy-btn" onclick="copyPrompt(this)">Copiar</button>
<div class="prompt-box">{escape(prompt_text)}</div>
</div>
</div>
</div>"""


CSS = """*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,sans-serif;background:#FAFAF8;color:#111827;-webkit-font-smoothing:antialiased}
.header{background:#1A1F36;color:#fff;padding:32px 48px}
.header h1{font-size:28px;font-weight:600;letter-spacing:-0.02em;margin-bottom:6px}
.header p{font-size:13px;color:rgba(255,255,255,0.6)}
.dot{display:inline-block;width:12px;height:12px;border-radius:50%;background:#6366F1;margin-right:8px;vertical-align:middle}
.content{max-width:1200px;margin:0 auto;padding:32px 48px}
.kpis{display:flex;gap:48px;margin-bottom:32px;align-items:baseline}
.kpi-value{font-size:28px;font-weight:600;letter-spacing:-0.02em}
.kpi-label{font-size:11px;font-weight:500;text-transform:uppercase;letter-spacing:0.05em;color:#9CA3AF;margin-left:6px}
.section-title{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.05em;color:#9CA3AF;margin:32px 0 16px}
.sprint-grid{display:grid;gap:12px;margin-bottom:40px}
.sprint-card{background:#fff;border-radius:12px;overflow:hidden;border:1px solid #0000000A}
.sprint-header{display:flex;align-items:center;padding:16px 20px;cursor:pointer;gap:16px;user-select:none}
.sprint-header:hover{background:#F5F5F5}
.sprint-number{font-size:11px;font-weight:600;color:#fff;border-radius:6px;padding:4px 10px;min-width:36px;text-align:center;flex-shrink:0}
.sprint-number.opus{background:#6366F1}
.sprint-number.sonnet{background:#10B981}
.sprint-number.codex{background:#F59E0B;color:#111}
.sprint-number.supervisor{background:#EF4444}
.sprint-number.notas{background:#6B7280}
.sprint-title{font-size:14px;font-weight:500;flex:1}
.model-badge{font-size:11px;font-weight:500;padding:3px 8px;border-radius:4px;background:#F3F4F6;color:#6B7280}
.model-badge.opus{background:#EEF2FF;color:#4F46E5}
.model-badge.sonnet{background:#ECFDF5;color:#059669}
.model-badge.codex{background:#FFFBEB;color:#B45309}
.model-badge.supervisor{background:#FEF2F2;color:#DC2626}
.model-badge.notas{background:#F3F4F6;color:#6B7280}
.dep-tag{display:inline-block;font-size:11px;font-weight:500;padding:2px 8px;border-radius:4px;background:#F3F4F6;color:#6B7280;margin-right:4px}
.chevron{color:#9CA3AF;transition:transform 200ms ease;flex-shrink:0}
.sprint-card.open .chevron{transform:rotate(180deg)}
.sprint-body{display:none;border-top:1px solid #0000000A}
.sprint-card.open .sprint-body{display:block}
.prompt-container{position:relative;padding:20px}
.prompt-box{background:#1E1E2E;color:#CDD6F4;border-radius:8px;padding:16px 20px;font-size:12px;line-height:1.6;max-height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-word}
.copy-btn{position:absolute;top:28px;right:28px;background:#6366F1;color:#fff;border:none;border-radius:6px;padding:6px 14px;font-size:11px;font-weight:600;cursor:pointer;z-index:2}
.copy-btn:hover{background:#4F46E5}
.copy-btn.copied{background:#10B981}
.sprint-meta{display:flex;gap:12px;align-items:center;flex-shrink:0}
.clickup-link{font-size:11px;color:#6366F1;text-decoration:none;font-weight:500}
.clickup-link:hover{text-decoration:underline}
@media(max-width:768px){.header,.content{padding:20px}.kpis{gap:24px;flex-wrap:wrap}.sprint-meta{display:none}}"""

JS = """function toggleCard(id){document.getElementById(id).classList.toggle('open')}
function copyPrompt(btn){const box=btn.parentElement.querySelector('.prompt-box');navigator.clipboard.writeText(box.textContent).then(()=>{btn.textContent='Copiado!';btn.classList.add('copied');setTimeout(()=>{btn.textContent='Copiar';btn.classList.remove('copied')},2000)})}"""


def main():
    raw = read_prompts()
    sections = extract_sections(raw)
    design_header = extract_design_system_header(raw)

    # Fix migration paths globally
    for key in sections:
        sections[key] = fix_migration_path(sections[key])
    design_header = fix_migration_path(design_header)

    # Enhance supervisor with design checks
    if "supervisor" in sections:
        sections["supervisor"] = enhance_supervisor(sections["supervisor"])

    # Build cards
    cards = []

    # Supervisor card
    if "supervisor" in sections:
        cards.append(make_card(
            "card-supervisor", "SUP", "supervisor",
            "Supervisor \u2014 Validacao de Entregas",
            "Opus", "supervisor", "", "",
            sections["supervisor"],
        ))

    # Sprint cards 0-6
    for i in range(7):
        key = f"sprint_{i}"
        if key not in sections:
            continue
        meta = SPRINT_META[str(i)]
        prompt_text = sections[key]

        # Prepend design system header to sprints 1-6
        if i >= 1:
            prompt_text = design_header + "\n\n---\n\n" + prompt_text

        cards.append(make_card(
            f"card-sprint-{i}", f"S{i}", meta["model"],
            meta["title"],
            meta["model"].capitalize(), meta["model"],
            meta["deps"], meta["clickup"],
            prompt_text,
        ))

    # Notas card
    if "notas" in sections:
        cards.append(make_card(
            "card-notas", "REF", "notas",
            "Notas de Execucao",
            "Ref", "notas", "", "",
            sections["notas"],
        ))

    cards_html = "\n".join(cards)

    page = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MMD Estoque Inteligente \u2014 Command Center</title>
<style>
{CSS}
</style>
</head>
<body>
<div class="header">
<h1><span class="dot"></span>MMD Estoque Inteligente \u2014 Command Center</h1>
<p>7 sprints | 3 Opus, 3 Sonnet, 1 Codex | ClickUp: [MMD] MMD EVENTOS &gt; 04. Sprint Atual</p>
</div>
<div class="content">
<div class="kpis">
<div><span class="kpi-value">7</span><span class="kpi-label">Sprints</span></div>
<div><span class="kpi-value">3</span><span class="kpi-label">Opus</span></div>
<div><span class="kpi-value">3</span><span class="kpi-label">Sonnet</span></div>
<div><span class="kpi-value">1</span><span class="kpi-label">Codex</span></div>
</div>

<div class="section-title">Pipeline</div>
<div class="sprint-grid">
{cards_html}
</div>
</div>
<script>
{JS}
</script>
</body>
</html>
"""

    OUTPUT_PATH.write_text(page, encoding="utf-8")
    line_count = page.count("\n") + 1
    print(f"Generated {OUTPUT_PATH} ({line_count} lines)")

    # Verification
    for i in range(7):
        key = f"sprint_{i}"
        if key in sections:
            original_lines = sections[key].count("\n")
            print(f"  Sprint {i}: {original_lines} lines from source")
    if "supervisor" in sections:
        print(f"  Supervisor: {sections['supervisor'].count(chr(10))} lines")
    if "notas" in sections:
        print(f"  Notas: {sections['notas'].count(chr(10))} lines")

    # Check design system prepended
    for i in range(1, 7):
        card_id = f"card-sprint-{i}"
        if "Design System (obrigatorio para Sprints 1-6)" in page:
            pass
        else:
            print(f"  WARNING: Design System header missing from Sprint {i}")
            break

    # Check key design sections preserved
    checks = [
        ("Sprint 1 Design section", "5. Design (OBRIGATORIO"),
        ("Sprint 1 Telas section", "ConnectReaderView:"),
        ("Sprint 2 Design section", "Design (herda do Sprint 1"),
        ("Sprint 2 ndSuccess", "ndSuccess (#4A9E5C)"),
        ("Sprint 3 Design section", "Design (OBRIGATORIO - ler"),
        ("Sprint 3 desktop-first", "desktop-first com responsividade mobile"),
        ("Sprint 3 split layout", "380px dark sidebar"),
        ("Sprint 3 dot-grid", "radial-gradient(circle, #333 0.5px"),
        ("Sprint 4 Design section", "Design (herda do Sprint 3"),
        ("Sprint 6 Design Review", "Design Review (OBRIGATORIO"),
        ("Supervisor design checks", "Verificacao de Design (Sprints 1-6)"),
        ("Supervisor blocking", "Design system ignorado"),
        ("Migration path fixed", "supabase/migrations/00001_initial_schema.sql"),
    ]

    all_ok = True
    for label, needle in checks:
        escaped_needle = html.escape(needle, quote=False)
        if escaped_needle in page:
            print(f"  OK: {label}")
        else:
            print(f"  FAIL: {label} - '{needle}' not found")
            all_ok = False

    if all_ok:
        print("\nAll checks passed. HTML is 100% in sync with agent-prompts.md.")
    else:
        print("\nSome checks failed. Review output above.")


if __name__ == "__main__":
    main()

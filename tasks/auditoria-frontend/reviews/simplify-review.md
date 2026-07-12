# Simplify Review - Auditoria Frontend MMD

**Data:** 2026-05-25
**Revisor:** simplify (4o reviewer)
**Escopo:** RASCUNHO-RELATORIO.md - foco em over-engineering, abstrações prematuras, complexidade não justificada para contrato R$3k/3 meses.

---

## Achados

---

### [CRÍTICO] Seção 4.3 item 6 + Seção 6 Long Term: Pipeline DTCG JSON

Por que é over-engineering: o rascunho lista "Pipeline DTCG JSON para sincronização de tokens com Figma" no Long Term. O `mmd-tokens.json` já existe em `design_handoff_estoque_mmd/tokens/` e está em formato DTCG válido (verifiquei: tem `$schema`, `$value`, estrutura de grupos). O CSS em `globals.css` já é a fonte de verdade operacional. Um pipeline Style Dictionary + Figma nesse projeto serve a um único ator: o Marco. Não há equipe de design, não há designer separado, não há Figma sendo atualizado. O custo de setup e manutenção (Style Dictionary config, build step, CI integration) é real. O benefício (tokens sincronizados automaticamente) é hipotético no contexto de contratante individual com prazo de 3 meses.

Alternativa: documentar em comentário no `globals.css` que o arquivo JSON de referência fica em `design_handoff_estoque_mmd/tokens/mmd-tokens.json` e que atualização é manual. Isso já é o estado atual e funciona.

O que se perde: sincronização automática com Figma caso o cliente queira iteração visual frequente com designer externo. Dado que não há designer externo e o contrato não menciona isso, perda é zero no período.

---

### [CRÍTICO] Seção 4.7 item 3 + Seção 6 W2: Husky + lint-staged

Por que é over-engineering: o rascunho recomenda instalar Husky + lint-staged (W2, uma semana). O repositório tem um único desenvolvedor ativo: o Marco. Husky existe para garantir que ninguém faça commit sem passar por lint no time. Com um desenvolvedor, o benefício é marginal, o custo de manutenção de hooks de pre-commit é real (hooks que quebram por atualização de dependência, hooks lentos que frustram o ciclo de desenvolvimento, tempo de setup). O CI com `tsc --noEmit` + `eslint .` já captura o mesmo problema antes do merge.

Alternativa: manter só o CI check (que o próprio rascunho recomenda como Quick Win em W1). É a barreira correta para o tamanho do time.

O que se perde: feedback de lint antes do push (vs no push). Para um desenvolvedor solo que faz commits frequentes, isso é conforto, não necessidade. O CI fecha a porta antes do merge.

---

### [CRÍTICO] Seção 4.2 item 3 + Seção 6 W3: cva + class-variance-authority para PrimaryBtn/GhostBtn

Por que é over-engineering: o rascunho propõe instalar `class-variance-authority`, criar um componente `Button` unificado com sistema de variants, e estima 3 horas em W3. Verifiquei: PrimaryBtn e GhostBtn têm 46 call sites em 10 arquivos. Os dois componentes já existem como funções separadas em Primitives.tsx e aceitam `style` para customização pontual. A prop `small` já cobre a variação de tamanho. O problema real é que os botões usam inline styles pesados (background gradient, boxShadow hardcoded), o que é um problema de token, não de API de componente.

Alternativa: se o objetivo é consolidar, criar um único `Btn` que aceita `variant: 'primary' | 'ghost'` com 15 linhas de if/else. Sem nova dependência. Sem novo padrão de API. Sem migração de call sites porque os nomes existentes podem ficar como aliases.

O que se perde: type safety de variantes com CVA (autocomplete de variant names). Dado que há exatamente dois variants e o projeto não está crescendo para mais, essa perda é aceitável.

---

### [CRÍTICO] Seção 6 Long Term: Storybook para Primitives.tsx

Por que é over-engineering: Storybook em W4+ para um design system de 8 componentes (GlassCard, GlassPill, StatusDot, Ring, IconBox, Sparkline, PrimaryBtn, GhostBtn) todos em um único arquivo de 413 linhas, com zero stories hoje, zero CI visual, e contrato de 3 meses. O custo de setup Storybook (dependências, config, stories files, manutenção), mesmo conservador, é 1-2 dias. O benefício num projeto solo de MVP operacional é documentação visual que ninguém lê.

Alternativa: documentar os componentes disponíveis no AGENTS.md (que o rascunho já propõe). Se o cliente precisar de revisão visual do design system, um screenshot é suficiente.

O que se perde: ambiente interativo de exploração de componentes. Para o escopo do projeto, isso não é necessidade do contratante.

---

### [IMPORTANTE] Seção 4.3 item 1 + Seção 6 W4/Long Term: Layer 3 de component tokens

Por que é over-engineering: o rascunho classifica Layer 3 (tokens de componente: `--btn-bg`, `--dialog-overlay`, `--input-border`) como "Médio esforço, Médio risco" e coloca em W4 e Long Term. Verifiquei: nenhum componente do código hoje referencia tokens de Layer 3, porque a layer não existe. Criar uma layer de abstração de tokens por componente antes de qualquer componente pedir isso é premature DRY aplicado a tokens. O problema real apontado no rascunho ("refactor de design quebra múltiplos componentes") existe, mas o custo hoje é baixo: 8 componentes em um arquivo, mudança cirúrgica em Primitives.tsx resolve.

Alternativa: o único token de Layer 3 que se paga imediatamente é `--dialog-overlay` para unificar os 5 modais (já proposto no item 1 da seção 4.3 com esforço Baixo). Esse sim vale. Os demais tokens de componente devem surgir quando o segundo componente precisar do mesmo token, não antes.

O que se perde: estrutura organizada antecipadamente. Mas Layer 3 com zero usos é documentação sem valor.

---

### [IMPORTANTE] Seção 4.2 item 1 + Seção 6 W2: eslint-plugin-tailwindcss

Por que é over-engineering para o contexto: o rascunho classifica como "Alta" a issue de 906 inline styles vs 246 classNames. Isso é correto como observação. Mas a recomendação de instalar `eslint-plugin-tailwindcss` para detectar classes conflitantes é uma solução para um problema que o projeto não tem: com 246 usos de className e dois backtick-templates de className no código inteiro (verifiquei a contagem), não há concatenação de classes conflitantes em escala. O plugin seria útil num projeto com 2000+ classes Tailwind. Aqui vai lint de coisa que não existe.

Alternativa: pular o plugin. Instalar `eslint-plugin-jsx-a11y` (que resolve problema real) e deixar o tailwindcss plugin para quando a migração de inline styles começar de verdade.

O que se perde: detecção antecipada de conflito de classes. Dado o volume atual, custo-benefício não fecha.

---

### [IMPORTANTE] Seção 4.2 item 4 + Seção 6 W4+: Migração de 906 inline styles para Tailwind utility classes

Por que a recomendação precisa ser repensada: o rascunho coloca isso como "Alto esforço, Médio risco" e planeja início em W4 com "2-3 semanas" no long term. A pergunta que o rascunho não responde: por que migrar? O CSS funciona. O design system Liquid Glass é baseado em variáveis CSS (`var(--fg-0)`, `var(--glass-bg)`) e gradientes complexos (`linear-gradient(180deg, oklch(...), oklch(...))`) que não têm utilidade equivalente em Tailwind v4 sem criar classes custom de qualquer forma. Migrar `background: linear-gradient(180deg, oklch(0.78 0.14 210), oklch(0.68 0.15 220))` para Tailwind não simplifica: cria uma classe custom que é exatamente a mesma coisa. A proporção 3.7:1 de inline vs className é um achado técnico válido, mas o rascunho não demonstra que isso causa problema real de produto. Purge do Tailwind em v4 funciona por análise estática de classes, e o projeto tem poucas classes dinâmicas.

Alternativa: documentar como decisão aceita: "inline styles são usados para valores dinâmicos e gradientes complexos do Liquid Glass; Tailwind é usado para layout e estado (`.glass`, `.skeleton`, `.reveal-N`)." Isso é o que o código já faz. Não é bagunça, é separação de responsabilidade.

O que se perde: purge otimizado e IntelliSense de constraints de Tailwind. Dado que os valores são design tokens do Liquid Glass e não valores arbitrários, a perda de IntelliSense é marginal.

---

### [IMPORTANTE] Seção 4.7 item 6 + Seção 6 W4 Long Term: eslint-plugin-react-compiler

Por que é prematuro: o rascunho lista `eslint-plugin-react-compiler` como item de W4/Long Term. O plugin emite warnings para código incompatível com React Compiler antes de ativar o compiler. Faz sentido instalar junto com o React Compiler. O rascunho, porém, recomenda ativar o React Compiler em W1 (Quick Win) e instalar o plugin de lint em W4. A ordem está invertida: o plugin deve ser instalado antes ou junto com a ativação, não depois. Isso não é over-engineering, é sequência errada que o rascunho não flagou.

Alternativa: mover o plugin de W4 para W1, como pré-condição da ativação do Compiler. Se não quer instalar o plugin, não ative o Compiler até W4. Não faça os dois em janelas separadas.

O que se perde: nada. É uma correção de sequência.

---

### [IMPORTANTE] Seção 4.7 item 8 + Seção 6 Long Term: Visual regression com Lost Pixel / Playwright

Por que é over-engineering: visual regression testing para um design system de 8 componentes num contrato de 3 meses é setup de empresa de produto, não de projeto de estoque para locadora AV. Lost Pixel e Playwright visual precisam de baseline screenshots, CI com comparação, threshold de diff, manutenção de snapshots a cada mudança intencional de UI. Para o Marco solo, o custo de falsos positivos e de manter os snapshots atualizados excede o benefício de detectar regressão visual.

Alternativa: remover do roadmap completamente. Se no futuro o design system crescer e houver time, aí faz sentido.

O que se perde: detecção automática de regressão visual. Para MVP de estoque com um desenvolvedor, testes de comportamento (a11y, functional) têm ROI muito maior.

---

### [COSMÉTICO] Seção 4.2 item 5 + Seção 6 W2: prettier-plugin-tailwindcss

Por que é questionável para o escopo: `prettier-plugin-tailwindcss` ordena classes Tailwind automaticamente. Com 246 uses de className e dois backtick-templates (verifiquei), o ganho de consistência é cosmético. O plugin também tem histórico de conflito com configurações de ESLint em projetos com flat config (ESLint 9). Para um projeto solo, ordem de classes é preferência, não necessidade.

Alternativa: se Prettier for instalado (que faz sentido para formatação geral), instalar sem o plugin de Tailwind. Adicionar o plugin só quando a migração de inline styles começar e o volume de classes justificar.

O que se perde: ordem consistente de classes Tailwind. Com o volume atual, imperceptível.

---

### [COSMÉTICO] Seção 4.8 item 4 + Seção 6 W4: .cursor/rules/

Por que é menor que o classificado: o rascunho classifica ausência de `.cursor/rules/` como "Baixa" severidade mas inclui no plano de W4. A informação que o arquivo carregaria (stack real, anti-patterns) já estará no `AGENTS.md` atualizado (W1). Criar um segundo arquivo com conteúdo quase idêntico para o Cursor é duplicação de documentação. Se o Marco usa Cursor, o AGENTS.md já é lido.

Alternativa: pular. Se houver algo específico do Cursor que não cabe no AGENTS.md, criar então.

O que se perde: formatação específica do Cursor (`---` frontmatter, `globs`). Dado que o benefício já é coberto pelo AGENTS.md, a perda é zero.

---

## Resumo

3 CRÍTICO, 4 IMPORTANTE, 2 COSMÉTICO.

**Recomendação geral: simplificar antes de merge.**

O rascunho está correto nos achados de produto (a11y crítica nos dialogs, CI sem typecheck, React Compiler, skip link) e nas Quick Wins de W1. O problema é o que está em W2-W4 e Long Term: a densidade de ferramentas propostas (cva, Husky, lint-staged, eslint-plugin-tailwindcss, eslint-plugin-react-compiler em ordem errada, Layer 3 de tokens, Storybook, Lost Pixel, DTCG pipeline) transforma uma semana de polish em um projeto de infraestrutura.

O que deve sobrar como recomendação ativa:
- W1: todos os Quick Wins do rascunho, mais mover eslint-plugin-react-compiler para junto da ativação do Compiler.
- W2: Radix Dialog nos 5 modais (a11y crítica real), Prettier sem plugin Tailwind, jsx-a11y plugin.
- W3+: cva apenas se surgir terceiro variant de botão. Migração de inline styles apenas se causar bug real. Layer 3 apenas quando segundo componente precisar do mesmo token.
- Remover do roadmap: Storybook, Lost Pixel, DTCG pipeline, Husky, eslint-plugin-tailwindcss (por ora), .cursor/rules (duplica AGENTS.md).

O rascunho deve adicionar uma seção de "Itens deliberadamente fora do escopo" com justificativa, para que o próximo agente não os reclassifique como gaps.

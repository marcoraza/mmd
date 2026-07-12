# Spec Review: RASCUNHO-RELATORIO.md

**Revisado em:** 2026-05-25
**Arquivo:** `tasks/auditoria-frontend/RASCUNHO-RELATORIO.md`
**Objetivo:** Atacar critérios não verificáveis, premissas escondidas, escopo dilatável, dependências não declaradas e edge cases faltando.

---

## 1. Critérios Não Verificáveis

### 1.1 "fidelidade razoável"

**Seção:** 1. Resumo Executivo > Recomendação Geral
**Citação:** "O design system Liquid Glass está implementado com fidelidade razoável."
**Problema:** "Razoável" não é mensurável. O cliente pode interpretar como 90% ou 50%. Sem métrica, não há como verificar se a afirmação é verdadeira ou se melhorou após as correções.
**Sugestão:** Substituir por critério binário. Ex: "72% dos tokens do handoff (`design_handoff_estoque_mmd/`) estão implementados em `globals.css`. 5 componentes usam valores hardcoded em vez de tokens."

### 1.2 "fechar os gaps críticos de acessibilidade e CI esta semana"

**Seção:** 1. Resumo Executivo > Recomendação Geral
**Citação:** "fechar os gaps críticos de acessibilidade e CI esta semana"
**Problema:** "Gaps críticos" é vago. São todos os 8 issues de a11y? Só os de severidade Alta? O documento lista 8 issues em 4.6, mas só 5 são Alta. "Esta semana" é relativo à data de leitura.
**Sugestão:** Explicitar: "Resolver os 5 issues de severidade Alta da seção 4.6 (dialogs sem focus trap, skip link, contraste) até [data absoluta]."

### 1.3 Contraste "provavelmente insuficiente" com severidade "Alta (Hipótese)"

**Seção:** 4.6 Acessibilidade > Issue #3
**Citação:** "Contraste fg-2/fg-3 provavelmente insuficiente [...] Alta (Hipótese)"
**Problema:** Hipótese não pode ter severidade Alta. Se for Alta, é porque foi verificado. Se é hipótese, severidade é condicional ao resultado da medição.
**Sugestão:** Mudar para: "Severidade: A CONFIRMAR (medir antes de priorizar)". Ou medir antes de publicar o relatório e reportar o valor real.

### 1.4 "pós-MVP" sem definição

**Seção:** 4.3 Tokens > Recomendação #5
**Citação:** "Criar Layer 3 para button, dialog, input (pós-MVP)"
**Problema:** Quando é pós-MVP? Qual critério define que MVP está pronto? O documento não especifica.
**Sugestão:** Vincular a milestone concreto: "Criar Layer 3 após concluir W4 do plano (fechamento do Mês 1)".

### 1.5 "sem quebrar nada"

**Seção:** 1. Resumo Executivo > Top 3 Quick Wins
**Citação:** "Ativar React Compiler [...] elimina necessidade de useMemo/useCallback manuais em todo o projeto sem quebrar nada."
**Problema:** Afirmação absoluta sem evidência. React Compiler pode quebrar componentes com patterns incompatíveis (mutação de objeto no render, closures stale). O documento não verificou se existem tais patterns no código.
**Sugestão:** Trocar por: "Risco baixo: React Compiler é estável em React 19 + Next 16, mas requer smoke test no build antes de declarar sucesso."

### 1.6 Tokens "dos layers 1-2" sem fallback

**Seção:** 7. Convenções Propostas > Padrões de Código
**Citação:** "Tokens: usar `var(--token)` dos layers 1-2 do `globals.css`"
**Problema:** O próprio documento diz que Layer 3 (component tokens) não existe. Qual é o fallback quando um componente precisa de um token que não está em L1/L2?
**Sugestão:** Adicionar: "Se o token não existir em L1/L2, criar variável local no componente com nome `--[component]-[property]` e documentar para futura promoção a L3."

---

## 2. Premissas Escondidas

### 2.1 Deploy target indefinido (Vercel vs GitHub Pages)

**Seção:** Múltiplas (4.5, 6, 6.5)
**Citação:** "Remover `images: {unoptimized: true}` se deploy é Vercel (não GitHub Pages)"
**Problema:** O workflow de CI é `pages.yml`, sugerindo GitHub Pages. Várias recomendações assumem Vercel. O documento não declara qual é a fonte de verdade do deploy target.
**Sugestão:** Adicionar no início do documento: "Deploy target: [Vercel|GitHub Pages]. Confirmar com Marco antes de executar itens dependentes de plataforma."

### 2.2 "Purge ineficaz" com inline styles de CSS vars

**Seção:** 4.2 Tailwind v4 > Issue #1
**Citação:** "Purge ineficaz, sem IntelliSense de constraints"
**Problema:** Inline styles usando `var(--token)` não são o mesmo que valores hardcoded. Se os tokens estão definidos em `globals.css`, eles são preservados pelo build. O problema real é a falta de IntelliSense e constraints, não o purge.
**Sugestão:** Reformular: "Tailwind purge funciona para classes, mas inline styles com `var()` não recebem validação de design system (sem IntelliSense, sem erro se o token não existir)."

### 2.3 Severidade Alta para shadcn não instalado

**Seção:** 4.4 shadcn/ui > Issue #1
**Citação:** "shadcn/ui não instalado, CLAUDE.md diz que está [...] Severidade: Alta"
**Problema:** Severidade Alta assume que (a) agentes de IA são usados frequentemente e (b) geram código shadcn. Ambas são premissas não verificadas. O projeto funciona sem shadcn.
**Sugestão:** Mudar severidade para Média. A criticidade é documentação desatualizada, não sistema quebrado. O risco real é código gerado incompatível, que só se materializa se agentes forem usados.

### 2.4 React Compiler é "nativo"

**Seção:** 6.5 Mapeamento > W1 > Ativar React Compiler
**Citação:** "Nenhuma (React 19 + Next 16 suportam nativamente)"
**Problema:** React Compiler requer instalação separada (`babel-plugin-react-compiler`) em versões anteriores. Em Next.js 16+ com React 19.2+, é built-in mas ainda opt-in. A afirmação "nenhuma dependência" pode confundir quem ler a documentação oficial.
**Sugestão:** Trocar por: "Dependências: nenhuma instalação adicional (built-in em Next 16+, opt-in via config)."

### 2.5 Estimativas de esforço como fatos

**Seção:** 6.5 Mapeamento W1-W4
**Citação:** "0.5h", "1h", "6h"
**Problema:** Todas as estimativas são apresentadas como fatos. Quem validou? Qual margem de erro?
**Sugestão:** Adicionar prefixo "~" ou nota de rodapé: "Estimativas baseadas em complexidade observada; variance de ±50% esperada."

### 2.6 Violação WCAG citada incorretamente

**Seção:** 4.6 Acessibilidade > Issue #1
**Citação:** "Dialogs sem focus trap [...] Violação WCAG 2.1 SC 2.1.2"
**Problema:** WCAG 2.1.2 (No Keyboard Trap) trata de foco PRESO, não de foco ESCAPANDO. Se o usuário pode escapar do dialog para o conteúdo de fundo, o foco não está preso. A violação mais precisa seria relacionada a focus management em modal dialogs (WCAG 2.4.3 Focus Order) ou ARIA Authoring Practices.
**Sugestão:** Corrigir para: "Dialogs sem focus trap: violação de ARIA Authoring Practices Guide (APG) para Modal Dialog Pattern. Focus deve ser contido no dialog enquanto aberto."

---

## 3. Escopo Dilatável

### 3.1 "Migrar inline styles para Tailwind utility classes"

**Seção:** 5. Matriz de Priorização > Item #22
**Citação:** "Migrar inline styles para Tailwind utility classes [...] Esforço: Alto, Arquivos: Todo `src/`"
**Problema:** 906 inline styles em "Todo `src/`" é escopo indefinido. Sem critério de "done", pode crescer indefinidamente. O item pode levar 1 semana ou 3 meses.
**Sugestão:** Quebrar em fases com critério binário: "Fase 1: migrar os 6 componentes de `components/dashboard/` (estimativa: N inline styles). Fase 2: migrar `components/catalog/` (estimativa: M inline styles). Critério de done por fase: zero `style={{}}` com valor que tem token equivalente."

### 3.2 "Início da migração inline styles (1-2 componentes piloto)"

**Seção:** 6.5 W4
**Citação:** "Início da migração inline styles (1-2 componentes piloto) [...] Dashboard components"
**Problema:** "Dashboard components" é vago. São 6 arquivos em `components/dashboard/`. Quais 1-2 são os pilotos?
**Sugestão:** Nomear os arquivos específicos: "Pilotos: `DashboardClient.tsx` e `StatCard.tsx` (menor complexidade, boa cobertura de padrões)."

### 3.3 "Adicionar Storybook"

**Seção:** 5. Matriz de Priorização > Item #25
**Citação:** "Adicionar Storybook para Primitives.tsx [...] Esforço: Alto"
**Problema:** Sem escopo definido. Storybook para quantos componentes? Só Primitives.tsx (7+ componentes) ou todo o projeto (30+ componentes)?
**Sugestão:** Definir escopo mínimo: "Storybook MVP: stories para os 7 primitivos em `Primitives.tsx` (GlassCard, GlassPill, PrimaryBtn, GhostBtn, Ring, StatusDot, Badge). Expansão posterior opcional."

### 3.4 "Migração gradual de inline styles" na seção 4.2

**Seção:** 4.2 Tailwind v4 > Recomendação #4
**Citação:** "Migração gradual de inline styles para utility classes [...] Esforço: Alto, Risco: Médio"
**Problema:** "Gradual" não tem critério de término. Pode ser interpretado como "faça quando der" (nunca termina).
**Sugestão:** Vincular a trigger: "Migrar inline styles de cada componente quando ele for tocado por outra tarefa. Não criar tarefa separada de migração em massa."

---

## 4. Dependências Não Declaradas

### 4.1 cva não tem momento de instalação

**Seção:** 6.5 W3
**Citação:** "Button com cva (PrimaryBtn + GhostBtn) [...] Dependências: `class-variance-authority` instalado"
**Problema:** A dependência está declarada, mas o plano não diz quando instalar `class-variance-authority`. Não aparece em W1 nem W2.
**Sugestão:** Adicionar em W2 ou W3: "Instalar `class-variance-authority` (0.5h, zero risco)".

### 4.2 Decisão de deploy target bloqueia múltiplos itens

**Seção:** 6.5 W2
**Citação:** "Remover `images: {unoptimized}` (se Vercel) [...] Dependências: Confirmar deploy target"
**Problema:** A dependência "confirmar deploy target" não está no plano como item executável. É pré-requisito não rastreado.
**Sugestão:** Adicionar em W1: "Confirmar deploy target (Vercel vs GitHub Pages) com Marco (0h de execução, bloqueante para itens de otimização de imagem)."

### 4.3 Keys instáveis: e se não houver ID único?

**Seção:** 6.5 W1 > Corrigir keys instáveis
**Citação:** "Dependências: Identificar campo ID único em cada array"
**Problema:** E se os arrays em `LotesBanner` e `RfidBanner` não tiverem campo ID único (ex: array de strings, array de números)? O documento assume que o campo existe.
**Sugestão:** Adicionar fallback: "Se array não tiver ID único, gerar key composta (ex: `${item.name}-${item.value}`) ou adicionar ID no backend."

### 4.4 Radix Dialog: dependência de animações não mapeada

**Seção:** 6.5 W3 > @radix-ui/react-dialog para 5 dialogs
**Citação:** "Dependências: Verificar que foco e animações são preservados"
**Problema:** "Verificar" é pré-requisito, não dependência. Se os dialogs atuais têm animações CSS customizadas, a migração para Radix pode quebrar a UX. Isso deveria ser verificado ANTES de estimar esforço.
**Sugestão:** Adicionar em W2 como pré-requisito de W3: "Auditar animações dos 5 dialogs atuais e documentar como preservar em Radix (1h)."

### 4.5 Skip link assume que `#main-content` existe

**Seção:** 4.6 Acessibilidade > Recomendação #2
**Citação:** "Adicionar skip link em layout.tsx [...] `href=\"#main-content\"`"
**Problema:** O skip link aponta para `#main-content`, mas o documento não verifica se esse ID existe no conteúdo principal. Se não existir, o skip link não funciona.
**Sugestão:** Adicionar: "Verificar se `<main id=\"main-content\">` existe em `layout.tsx`. Se não, adicionar o ID junto com o skip link."

### 4.6 CI typecheck/lint: e se já houver erros?

**Seção:** 4.7 Tooling > Recomendação #1
**Citação:** "Adicionar `tsc --noEmit` + `eslint .` ao CI"
**Problema:** Se já existirem erros de type ou lint no código, o CI vai quebrar na primeira execução após a mudança. O documento não menciona se há erros existentes.
**Sugestão:** Adicionar pré-requisito: "Rodar `tsc --noEmit` e `npm run lint` localmente antes de adicionar ao CI. Se houver erros, resolver ou documentar como baseline."

---

## 5. Edge Cases Faltando

### 5.1 React Compiler: patterns incompatíveis

**Seção:** 4.5 Performance > Recomendação #1
**Citação:** "Ativar React Compiler: `reactCompiler: true`"
**Edge case não coberto:** E se algum componente usar pattern incompatível com Compiler (ex: mutação de objeto no render, closure stale em event handler)? O documento assume que não existem.
**Sugestão:** Adicionar verificação: "Após ativar, rodar build e verificar warnings do Compiler. Se houver `useMemo`/`useCallback` que o Compiler não conseguiu otimizar, investigar antes de remover manualmente."

### 5.2 Remover `--webpack`: fallback se Turbopack falhar

**Seção:** 6.5 W1 > Remover `--webpack` do build
**Citação:** "Dependências: Verificar que build Turbopack funciona"
**Edge case não coberto:** E se o build Turbopack falhar por incompatibilidade com alguma dependência? Qual é o procedimento de rollback?
**Sugestão:** Adicionar: "Se build Turbopack falhar, reverter para `--webpack` e abrir issue para investigar. Não bloquear deploy."

### 5.3 cn() com classes conflitantes

**Seção:** 4.2 Tailwind v4 > Exemplo de código
**Citação:** `export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)) }`
**Edge case não coberto:** E se classes conflitantes forem passadas (ex: `cn("p-4", "p-8")`)? O comportamento esperado (`twMerge` mantém a última) não está documentado para o time.
**Sugestão:** Adicionar nota nas convenções: "`cn()` usa `twMerge`: em classes conflitantes, a última vence. Ex: `cn('p-4', 'p-8')` resulta em `p-8`."

### 5.4 Contraste vs hierarquia visual

**Seção:** 4.6 Acessibilidade > Recomendação #3
**Citação:** "Medir contraste de fg-2 e fg-3 [...] e ajustar se necessário"
**Edge case não coberto:** E se ajustar o contraste quebrar a hierarquia visual do design system (fg-1, fg-2, fg-3 precisam de diferenciação perceptível)? O documento não contempla conflito entre a11y e design.
**Sugestão:** Adicionar: "Se fg-2/fg-3 precisarem de contraste maior, verificar que a hierarquia fg-1 > fg-2 > fg-3 permanece perceptível. Consultar design handoff se necessário."

### 5.5 ESLint plugins: volume de erros existentes

**Seção:** 4.7 Tooling > Recomendações #4 e #5
**Citação:** "Adicionar `eslint-plugin-jsx-a11y`", "Adicionar `eslint-plugin-tailwindcss`"
**Edge case não coberto:** Adicionar esses plugins pode gerar centenas de warnings/errors no código existente. O plano não menciona: (a) rodar em modo warn vs error; (b) estratégia para resolver violações existentes vs só novas.
**Sugestão:** Adicionar: "Configurar novos plugins com severity `warn` inicialmente. Resolver violações existentes de forma incremental (por componente, junto com outras tarefas no arquivo)."

### 5.6 Husky: arquivos staged que falham no lint

**Seção:** 6.5 W2 > Instalar Husky + lint-staged
**Edge case não coberto:** E se houver arquivos já staged que falham no lint? O commit será bloqueado. O documento não menciona se lint-staged deve rodar `--fix` automaticamente ou requerer fix manual.
**Sugestão:** Adicionar à configuração proposta: "lint-staged com `eslint --fix` para auto-correção de issues triviais. Issues não auto-corrigíveis bloqueiam commit."

### 5.7 Arrays sem ID único para keys

**Seção:** 4.5 Performance > Issue #4
**Citação:** "Keys instáveis (`key={i}`) em listas dinâmicas [...] LotesBanner.tsx:66, RfidBanner.tsx:70"
**Edge case não coberto:** A recomendação é "usar campo ID único", mas o documento não verifica se os arrays TÊM campo ID único. Se forem arrays de primitivos ou objetos sem ID, a correção é diferente.
**Sugestão:** Adicionar verificação: "Inspecionar estrutura dos arrays em LotesBanner e RfidBanner. Se não houver campo `id`, avaliar: (a) adicionar ID no backend; (b) usar key composta; (c) documentar exceção com justificativa."

---

## Resumo de Ações Prioritárias

1. **Resolver ambiguidade de deploy target** (bloqueia múltiplos itens)
2. **Corrigir referência WCAG** (2.1.2 não é a violação correta)
3. **Mudar severidade de contraste** de "Alta (Hipótese)" para "A CONFIRMAR"
4. **Adicionar momento de instalação de cva** no plano
5. **Definir escopo de migração de inline styles** (fases com critério binário)
6. **Verificar existência de `#main-content`** antes de skip link
7. **Rodar lint/typecheck localmente** antes de adicionar ao CI
8. **Auditar animações dos dialogs** antes de W3

---

*Review gerado em 2026-05-25. Objetivo: melhorar o relatório antes de entregar ao cliente.*

# G5: Tooling, DX e Configuracao para IA

## Prettier

### Status: AUSENTE (Media Severidade)

Verifiquei: `.prettierrc` nao existe. `prettier` nao esta em `devDependencies` (`package.json`).

Implicacoes:
- Sem formatacao automatica consistente
- `prettier-plugin-tailwindcss` impossivel (nao ha prettier)
- Classes Tailwind em `className=` nao sao ordenadas automaticamente
- Inconsistencias de formatacao entre contribuidores

## ESLint

### Status: Configurado, mas incompleto (Media Severidade)

Verifiquei `apps/web/eslint.config.mjs`:
```javascript
import { defineConfig, globalIgnores } from "eslint/config"
import nextVitals from "eslint-config-next/core-web-vitals"
import nextTs from "eslint-config-next/typescript"
const eslintConfig = defineConfig([...nextVitals, ...nextTs, globalIgnores([...])])
```

Presente e correto:
- Flat config (ESLint 9) - correto, nao usa legado `.eslintrc`
- `eslint-config-next/core-web-vitals` - inclui regras Next.js + CWV
- `eslint-config-next/typescript` - TypeScript rules

Ausente:
- `eslint-plugin-tailwindcss` - sem `no-contradicting-classname`, `enforces-shorthand`
- `eslint-plugin-jsx-a11y` - sem verificacao de acessibilidade estatica
- `eslint-plugin-react-compiler` - sem verificacao de compatibilidade com Compiler (relevante quando ativar o Compiler)

## Husky e lint-staged

### Status: AUSENTE (Media Severidade)

Verifiquei: sem `husky`, sem `lint-staged` em `package.json`.

Implicacoes:
- Sem pre-commit hook para lint/format
- Codigo sem formatacao ou com erros de lint pode ser commitado
- CI e a unica barreira (e o CI atual nao roda lint - ver abaixo)

## CI Pipeline

### Status: Minimo, sem qualidade gates (Alta Severidade)

Verifiquei `.github/workflows/pages.yml`:
```yaml
jobs:
  build:
    steps:
      - npm ci
      - next build
      - upload artifact
  deploy:
    needs: build
    - deploy-pages
```

O CI faz apenas build e deploy. Ausencias criticas:
- Sem `eslint .` (lint)
- Sem `tsc --noEmit` (typecheck)
- Sem testes unitarios ou de integracao
- Sem visual regression (Lost Pixel, Playwright)
- Sem bundle size check
- Sem Lighthouse CI
- Sem axe-core para acessibilidade

Um PR pode quebrar TypeScript ou introduzir violacoes de lint sem que o CI detecte.

## Storybook

### Status: AUSENTE

Verifiquei: sem storybook em `package.json`. Sem pasta `stories/`.

Para um design system como Liquid Glass 2030, Storybook seria util para documentar e visualizar Primitives.tsx. Mas para MVP R$3k/3 meses, e opcional.

## Visual Regression

### Status: AUSENTE

Sem Lost Pixel, Chromatic, Percy ou Playwright Visual Comparisons configurados.

## Configuracao para IA

### AGENTS.md (`apps/web/AGENTS.md`)

Verifiquei: arquivo existe mas conteudo e apenas:
```
<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know
This version has breaking changes...
<!-- END:nextjs-agent-rules -->
```

Este conteudo e gerado automaticamente pela versao do Next.js e alerta agentes de IA sobre breaking changes. Util, mas nao substitui instrucoes do projeto.

Ausentes no AGENTS.md:
- Stack definition (Next.js 16 + React 19 + Tailwind v4)
- Componentes disponiveis em Primitives.tsx
- Padroes de codigo do projeto (inline styles dominam, sem cva, sem cn)
- Regras de acessibilidade (WCAG 2.2 AA)
- Convencoes de commit
- Como rodar lint, build, testes
- O que NAO fazer (anti-patterns especificos)
- Referencia ao design system Liquid Glass 2030

### CLAUDE.md (`apps/web/CLAUDE.md`)

Verifiquei: arquivo existe mas parece conter apenas `@AGENTS.md` (referencia ao outro arquivo). Conteudo especifico de projeto nao verificado completamente.

### .cursor/rules/

Verifiquei: diretorio `.cursor/` nao existe no projeto.

### shadcn/skills

Verifiquei: shadcn nao esta instalado, portanto `shadcn/skills` nao existe.

### .mcp.json

Verifiquei: nao encontrado no projeto.

### .github/copilot-instructions.md

Verifiquei: nao encontrado.

## Recomendacoes de Tooling

### Quick Wins (podem ser feitos em horas)

1. Adicionar prettier + prettier-plugin-tailwindcss:
```bash
npm install -D prettier prettier-plugin-tailwindcss
```
```json
// .prettierrc
{
  "plugins": ["prettier-plugin-tailwindcss"],
  "semi": false,
  "singleQuote": true
}
```

2. Adicionar typecheck ao CI:
```yaml
- run: npx tsc --noEmit
```

3. Adicionar lint ao CI:
```yaml
- run: npm run lint
```

4. Reescrever AGENTS.md com instrucoes do projeto.

5. Ativar React Compiler:
```typescript
// next.config.ts
const nextConfig: NextConfig = {
  reactCompiler: true,
  ...
}
```

### Short Term

1. Adicionar husky + lint-staged
2. Adicionar `eslint-plugin-jsx-a11y`
3. Adicionar `eslint-plugin-react-compiler` (apos ativar Compiler)
4. Remover `--webpack` do script build

## Issues

| # | Issue | Severidade | Evidencia |
|---|---|---|---|
| 1 | CI sem lint nem typecheck | Alta | .github/workflows/pages.yml |
| 2 | Sem prettier | Media | package.json - ausencia |
| 3 | Sem husky/lint-staged | Media | package.json - ausencia |
| 4 | AGENTS.md sem instrucoes uteis do projeto | Media | apps/web/AGENTS.md |
| 5 | Sem eslint-plugin-jsx-a11y | Media | eslint.config.mjs |
| 6 | Sem eslint-plugin-tailwindcss | Media | eslint.config.mjs |
| 7 | Sem .cursor/rules/ | Baixa | diretorio ausente |
| 8 | Sem visual regression | Baixa | ausencia no projeto |
| 9 | Sem Storybook para Primitives | Baixa | ausencia no projeto |

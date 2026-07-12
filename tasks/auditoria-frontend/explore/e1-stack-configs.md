# E1: Stack e Configuracoes

## Versoes Detectadas (Verifiquei)

- Next.js: 16.2.2 (`apps/web/package.json` linha "next": "16.2.2")
- React: 19.2.4 (`package.json` linha "react": "19.2.4")
- React DOM: 19.2.4
- Tailwind CSS: ^4 (`devDependencies` linha "tailwindcss": "^4")
- TypeScript: ^5
- ESLint: ^9
- Node: 20 (inferido do CI `apps/web/.github/../pages.yml` usa `node-version: 20`)

## Configuracoes Criticas

### package.json (`apps/web/package.json`)

Scripts:
- `dev`: `next dev` (sem --turbopack flag, mas Turbopack configurado via next.config.ts)
- `build`: `next build --webpack` (IMPORTANTE: flag --webpack desabilita Turbopack no build)
- `start`: `next start`
- `lint`: `eslint .`

Dependencias relevantes:
- `@react-pdf/renderer`: ^4.5.1 (bundle pesado, client-side rendering)
- `@supabase/supabase-js`: ^2.104.0
- `lucide-react`: ^1.7.0
- `qrcode`: ^1.5.4

DevDependencies:
- `@tailwindcss/postcss`: ^4 (correto para v4)
- `@types/node`: ^20
- `typescript`: ^5

Ausencias notaveis:
- Nao ha `husky`, `lint-staged`, `prettier`, `prettier-plugin-tailwindcss`
- Nao ha `class-variance-authority` (cva), `tailwind-merge`, `clsx`
- Nao ha `eslint-plugin-tailwindcss`, `eslint-plugin-jsx-a11y`, `eslint-plugin-react-compiler`
- Nao ha `@radix-ui/*` ou `@base-ui-org/*` (sem shadcn/ui)

### next.config.ts (`apps/web/next.config.ts`)

```typescript
const nextConfig: NextConfig = {
  images: { unoptimized: true },
  turbopack: {
    root: __dirname,
  },
};
```

Issues criticos:
1. `images: { unoptimized: true }` - desabilita otimizacao de imagens do Next.js
2. `turbopack` configurado, mas `build` usa `--webpack`. Resultado: Turbopack apenas em `dev`, build de producao usa Webpack.
3. `reactCompiler: true` AUSENTE. React Compiler nao esta ativo.

### tsconfig.json (`apps/web/tsconfig.json`)

- `strict: true` - OK
- `target: "ES2017"` - conservador, poderia ser ES2020+
- `moduleResolution: "bundler"` - correto para Next.js 16
- `paths: { "@/*": ["./src/*"] }` - alias configurado
- Ausencias: `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`

### postcss.config.mjs (`apps/web/postcss.config.mjs`)

```js
plugins: { "@tailwindcss/postcss": {} }
```
Correto para Tailwind v4.

### eslint.config.mjs (`apps/web/eslint.config.mjs`)

Usa flat config (ESLint 9) com:
- `eslint-config-next/core-web-vitals`
- `eslint-config-next/typescript`

Ausencias:
- Nao ha `eslint-plugin-tailwindcss`
- Nao ha `eslint-plugin-jsx-a11y`
- Nao ha `eslint-plugin-react-compiler`
- Sem regras de a11y, sem regras de Tailwind

### Arquivos de IA

- `apps/web/AGENTS.md`: presente, conteudo minimo - apenas boilerplate da Next.js ("This is NOT the Next.js you know")
- `apps/web/CLAUDE.md`: existe no path mas parece referenciar apenas `@AGENTS.md`
- `.cursor/rules/`: nao encontrado no repo
- `shadcn/skills/`: nao encontrado
- `.github/copilot-instructions.md`: nao encontrado

### CI (`/.github/workflows/pages.yml`)

Pipeline minimo:
- `npm ci`
- `next build` (sem flags)
- Deploy GitHub Pages

Ausencias:
- Sem `eslint` step no CI
- Sem `tsc --noEmit` step
- Sem testes
- Sem visual regression
- Sem bundle size check
- Sem Lighthouse CI
- Sem axe-core

### Outros

- `.prettierrc`: NAO ENCONTRADO
- `components.json` (shadcn): NAO ENCONTRADO
- `vercel.json`: NAO ENCONTRADO (ha `.vercel/project.json` com IDs)
- `.nvmrc`: NAO ENCONTRADO
- `.lintstagedrc`: NAO ENCONTRADO
- `husky`: NAO ENCONTRADO

## Resumo de Severidade

| Issue | Severidade |
|---|---|
| React Compiler inativo (sem `reactCompiler: true`) | Alta |
| `images: { unoptimized: true }` | Alta |
| Build usa `--webpack` enquanto dev usa Turbopack | Media |
| Sem `prettier-plugin-tailwindcss` | Media |
| Sem `eslint-plugin-tailwindcss` nem `jsx-a11y` | Media |
| Sem Husky/lint-staged | Media |
| CI sem lint, typecheck, testes | Alta |
| `AGENTS.md` vazio de instrucoes uteis | Baixa |
| Sem `noUncheckedIndexedAccess` no TS | Baixa |

# MMD Web

Web app do MMD Estoque. Este não é um scaffold genérico de Next. É o produto vivo em `https://mmd-zeta.vercel.app`.

Antes de trabalhar no PRD MAR-171, leia:

- `../../docs/mar-171-agent-brief.md`
- `AGENTS.md`
- `../../tasks/mar-171-supervisor.md`
- `../../tasks/auditoria-frontend/RELATORIO-FINAL.md`

## Stack

- Next.js 16 App Router
- React 19
- Tailwind v4 CSS-first
- Liquid Glass 2030 próprio
- Supabase como fonte de verdade

## Design system

Use o que já existe:

- `src/components/mmd/Primitives.tsx`
- `src/app/globals.css`
- `public/handoff/`

Não instale shadcn/ui, Radix ou outro kit. Não crie um front-end paralelo. Prints em `../../tasks/evidence/` são prova ou referência, não outro produto.

## Produto e linguagem

- UI fala `Evento`.
- Rotas e modelos internos ainda podem usar `projetos`.
- Cabos são unidades rastreáveis individuais.
- Lotes são legado.
- QR público é mínimo e não expõe dados sensíveis.
- Mobile e web devem compartilhar regra operacional.

## Comandos

```bash
npm install
npm run dev
npm exec tsc -- --noEmit
npm run lint
npm run build
node --test src/lib/*.test.ts src/lib/data/*.test.ts
```

Use `MMD_DATA_MODE=demo` para QA visual sem depender do Supabase real.

## Gates para PR visual

Cada mudança visual relevante precisa ter:

- Issue Linear alvo.
- Referência glass usada.
- Imagegen quando houver UI nova ou mudança visual relevante.
- Screenshot desktop.
- Screenshot mobile.
- Typecheck, lint e build verdes.
- Nota clara se a entrega depende de Supabase real.

## Limites

Front-end pode adaptar telas existentes, copy, layout, responsividade, acessibilidade e estados visuais.

Front-end não deve mexer em migration, RLS, RPC, grants, contrato de API ou status de produção real sem alinhar com o supervisor.

# Paridade Visual Web e iOS MMD: Trava antes do Goal

## Missão

Traduzir a linguagem visual aprovada nos protótipos do Event Pro iOS em mudanças concretas para o WebApp, preservando a função, a densidade e as necessidades de desktop.

## Premissa central

*Paridade visual significa compartilhar gramática, tokens e hierarquia. Não significa esticar uma tela de iPhone no desktop nem redesenhar o iOS aprovado.*

## Contexto

A task `MMD · iOS white redesign` está refinando Home, Eventos e RFID em uma linguagem light, compacta e operacional. O WebApp usa Liquid Glass 2030 e possui superfícies próprias de gestão. O estudo precisa identificar onde os dois produtos divergem por acidente e onde a diferença atende ao dispositivo.

## Mapa do sistema

- Entrada: protótipos iOS vivos, decisões registradas, WebApp renderizado, tokens e componentes atuais.
- Processamento: comparação de gramática, hierarquia, cor, tipografia, densidade, motion e comportamento responsivo.
- Saída: direção de adaptação Web com crosswalk de tokens, componentes e telas.
- Fronteira de confiança: protótipos escolhidos e UI renderizada. Screenshot histórico não escolhido é referência secundária.

## Regras duras

- Ler a task iOS e os arquivos vivos antes de concluir.
- Preservar escolhas já travadas pelo Marco.
- Comparar telas equivalentes por função, não por nome de arquivo.
- Separar invariantes de marca das adaptações necessárias ao desktop.
- Não copiar dimensões, navegação ou gesto mobile para o Web.
- Não alterar código do Web ou do iOS nesta task.
- Não propor gradiente, glass ou card sem função demonstrável.
- Mapear cada mudança a token, primitive, componente ou tela existente.
- Usar screenshots renderizados dos dois produtos como prova.
- Priorizar mudanças sistêmicas que resolvam várias telas.
- Indicar o que deve permanecer diferente entre Web e iOS.

## Fonte da verdade

- Task `MMD · iOS white redesign`, thread `019fd4af-bcca-7253-9a1c-69d3292c2897`.
- Protótipos vivos em `tasks/evidence/home-2.0/` e decisões em `tasks/lessons.md`.
- Web atual em `apps/web`, `Primitives.tsx`, `globals.css` e runtime renderizado.
- `AGENTS.md`, `CONTEXT.md` e design system Liquid Glass 2030.

## Papéis obrigatórios

- Supervisor: protege as escolhas travadas e o escopo read-only.
- Analista iOS: extrai gramática, tokens, hierarquia e interações aprovadas.
- Analista Web: registra linguagem atual, constraints de desktop e divergências.
- Reviewer Design: elimina cópia literal, slop visual e propostas sem efeito sistêmico.

## Entregas

- Relatório de adaptação visual Web e iOS.
- Crosswalk de tokens, tipografia, superfícies, ícones, estados e motion.
- Matriz por tela equivalente.
- Screenshots comparativos anotados.
- Backlog priorizado de mudanças no Web com impacto e dependências.
- Lista explícita do que permanece diferente entre dispositivos.
- Brief de implementação pronto para outro agente, sem editar produto.

## Definition of Done

- [ ] O agente leu a task iOS e identificou a variante atual, decisões travadas e arquivos vivos.
- [ ] O agente renderizou protótipos iOS e rotas Web equivalentes.
- [ ] O relatório compara Home/Início, Eventos, Catálogo, Unidade e superfícies RFID disponíveis.
- [ ] Cada recomendação aponta a mudança visual e o componente Web afetado.
- [ ] Tokens compartilháveis e constraints específicas de dispositivo aparecem separados.
- [ ] O backlog prioriza primeiro mudanças sistêmicas de alto alcance.
- [ ] Screenshots sustentam as divergências principais.
- [ ] O relatório não redesenha protótipos aprovados.
- [ ] Reviewer identifica zero recomendação baseada apenas em gosto.
- [ ] Nenhum arquivo de produto foi alterado.

## Frase final de aceite

**O Web pode entrar no mesmo universo visual do Event Pro, mas não pode virar uma tela mobile ampliada nem apagar as necessidades de gestão.**

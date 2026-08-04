# Handoff: Event Pro 2.0

Você está retomando o trabalho do Event Pro 2.0 no repositório `/Users/marko/Projects/mmd`.

## Missão imediata

Recupere o estado visual exato de onde paramos antes de editar qualquer coisa. Depois continue a evolução da nova UX usando o processo obrigatório de cinco opções por corte visual.

## Abra primeiro

1. Entre em `/Users/marko/Projects/mmd`.
2. Leia `AGENTS.md`, `tasks/lessons.md` e `tasks/handoff-event-pro-2.md`.
3. Use a skill `browser:control-in-app-browser` e abra:

   `file:///Users/marko/Projects/mmd/tasks/evidence/home-2.0/prototipo-home.html`

4. Confirme visualmente que o preview abre direto no perfil da unidade, no corte atual `Round 47 · Ink Specimen`, com a opção `1 · Edge Rail` travada.
5. Se o navegador bloquear `file://`, confira antes se a porta 8765 já está ocupada. Se estiver livre, rode em `/Users/marko/Projects/mmd`:

   `python3 -m http.server 8765`

   Depois abra:

   `http://127.0.0.1:8765/tasks/evidence/home-2.0/prototipo-home.html`

## Onde o visual parou

- O preview abre com `itemProfileOpen = true`.
- A tela atual é o perfil de uma unidade do catálogo, sem scroll vertical.
- O corte travado usa uma ficha clara e uma peça central escura com anéis, silhueta do equipamento, estado, histórico recente, RFID e serial.
- A navegação de volta aponta para `Scanner`.
- A barra sutil de scroll da lista foi deslocada para não colidir com a coluna `TAG`.
- Não redesenhe a Home, o mapa, o scanner Halo ou a lista identificada sem Marco reabrir explicitamente essas decisões.

## Processo visual obrigatório

Para cada nova tela, estado ou componente:

1. Produza cinco opções realmente comparáveis.
2. Marco escolhe uma.
3. A rodada seguinte deriva apenas da opção escolhida.
4. Quando ele disser `trava`, preserve o corte.
5. Só então avance para a próxima superfície.

Não crie showcase. O próprio HTML é o laboratório visual. Preserve o círculo do scanner como motivo central. A linguagem é minimalista, funcional, dark-first, Apple/OpenAI, com hierarquia limpa, pouca informação simultânea e sem negrito excessivo.

## Decisões de produto já aprovadas

- O app iOS novo é uma nova UX. O legado é fonte de comportamento e de componentes valiosos, não modelo de navegação para copiar.
- Navegação persistente: Início, Eventos e Catálogo, com a ação global Identificar.
- Entidade abre por push. Mais conteúdo da mesma entidade abre em sheet. Ações de escrever, iniciar ou encerrar usam workspace focado. Só uma camada manipulável por vez.
- Todo manuseio útil de RFID deve ser possível no app.
- Etiquetar associa um EPC existente a uma unidade e precisa suportar vincular, substituir, desvincular e mover, com unicidade e auditoria. Não inclui programar a memória física da tag.
- Localizar usa proximidade real do RFD40 em tela focada, preservando e evoluindo o melhor componente visual do legado.
- Checkout move para `EM_CAMPO` apenas unidades confirmadas fisicamente. QR e manual são fallback. Checkout incompleto é permitido com motivo curto. A mesma conferência pode ser retomada.
- Retorno considera leitura como `OK` por padrão. Exceções são tratadas. Item ausente vira pendência de resolução.
- Hardware só será validado com Marcelo depois que o app estiver funcionalmente completo.

## Fontes canônicas

- Brief aprovado: `/Users/marko/Projects/mmd/docs/discovery/event-pro-mobile-rfid-checkout-grill.md`
- Glossário e linguagem: `/Users/marko/Projects/mmd/CONTEXT.md`
- ADR de checkout: `/Users/marko/Projects/mmd/docs/adr/0005-physical-conference-authorizes-checkout.md`
- ADR de paridade mobile: `/Users/marko/Projects/mmd/docs/adr/0006-contextual-mobile-capability-parity.md`
- Handoff completo: `/Users/marko/Projects/mmd/tasks/handoff-event-pro-2.md`
- Inventário do legado: `/Users/marko/Projects/mmd/tasks/inventario-telas-antigas.md`
- Spec GitHub: `https://github.com/marcoraza/mmd/issues/8`
- Tickets de execução: issues `#9` a `#25`.

A fronteira inicial permite tocar em paralelo:

- `#9 [Backend] - Estabilizar a baseline remota`
- `#10 [Frontend] - Alinhar o shell à IA aprovada`

Não avance automaticamente nesses tickets se Marco estiver pilotando um novo corte visual no preview. Primeiro preserve o fluxo iterativo de cinco opções.

## Estado do Git

- Branch de origem: `cc/sprint-auth-ios`
- Commit base anterior: `38184f6 docs: registra migration remota do pin de destino Event Pro`
- Antes de editar, inspecione `git status` e preserve qualquer alteração local do novo worktree.

## Skills sugeridas

- `browser:control-in-app-browser` para abrir e validar o preview.
- `mattpocock-implement` somente quando for executar um ticket aprovado.
- `gstack-qa` antes de fechar uma entrega frontend.
- `changelog` antes de encerrar trabalho significativo.

Não use `raza-showcase`: Marco recusou showcase para este fluxo.

## Primeira ação da sessão

Abra o preview, verifique o corte `Ink Specimen / Edge Rail` e informe em uma frase o que está na tela. Em seguida continue do ponto exato pedido por Marco, sem recapitular o projeto e sem pedir contexto que já está nestes arquivos.

# Prompt para `/loop`: one-pager "Como funciona o motor MMD"

Cole o bloco abaixo depois de `/loop` (sem intervalo, deixa o modelo se auto-pacear). O loop constrói o one-pager seção por seção, verifica cada uma no navegador, registra progresso e para sozinho quando o Definition of Done fecha.

Antes de colar: confirme que existe `tasks/apresentacao-marcelo/inventario-motor.md` (a fonte de verdade dos fatos). Ele já foi gerado.

---

## Prompt (copiar a partir daqui)

Você está construindo um one-pager interativo em HTML que EXPLICA, para o Marcelo (dono da MMD Eventos, empresa de locação de equipamento de AV, não técnico), como o sistema de estoque inteligente funciona por dentro. Material para uma reunião presencial conduzida pelo Marco.

Direção de conteúdo (regra dura, o sócio precisa ENTENDER, não se impressionar):
- Explicação item a item, didática, não frases de efeito nem slogan. Cada conceito ganha um "o que é" e um "como funciona" em linguagem de dono de empresa.
- Explique de verdade o que é o Supabase (o banco de dados): o que guarda, como tabelas se ligam, e liste as tabelas uma a uma com o que cada uma guarda e quantos registros tem hoje.
- Explique de verdade o que é o motor (as regras sobre o banco): o que é, como funciona (operações tudo-ou-nada, validações, registro automático), com exemplos concretos de regra.
- Mostre o loop passo a passo com três colunas por etapa: o que você faz, o que o motor faz, o que muda no banco.
- Use exemplo numérico onde ajudar (ex: a conta de valor de uma peça). Prefira mostrar a explicar no abstrato.
- Corte tese poética e fecho grandioso. O fecho é um resumo objetivo do que foi explicado.

### Fonte de verdade (leia antes de escrever qualquer coisa)
- `tasks/apresentacao-marcelo/inventario-motor.md`: todos os fatos, números reais do banco, fluxo do motor, estado honesto. Não invente número nem capacidade. Se algo não está no inventário, não afirme.
- `apps/web/src/app/globals.css`: tokens reais do design system Liquid Glass 2030 (cores em oklch, `--bg-0`, `--fg-0`, `--accent-cyan`, `--glass-bg`, raios, sombras). Puxe os valores reais para o one-pager ser fiel ao produto, não uma aproximação.
- `apps/web/src/components/mmd/Primitives.tsx`: referência de como as superfícies vítreas, bordas e o "ring de prontidão" aparecem no produto.

### Entregável
- Um único arquivo: `tasks/apresentacao-marcelo/index.html`.
- Standalone e auto-contido: CSS inline na própria página, diagramas em SVG inline, zero dependência externa, zero build, zero CDN. Abre direto no navegador com duplo clique e funciona offline.
- Não toca o app (`apps/web`). Não cria rota, componente ou produto paralelo. É um material de apresentação que vive em `tasks/`.

### Linguagem e tom (regra dura)
- Português do Brasil, acentuação completa.
- Dono de empresa, não engenheiro. Traduza todo termo técnico para o que ele significa na operação. Exemplos: "RPC atômica" vira "a saída acontece inteira ou não acontece, nunca pela metade"; "RLS" vira "cada pessoa só enxerga e mexe no que o papel dela permite"; "realtime" vira "se um operador mexe, a tela do outro atualiza sozinha".
- Sem jargão de TI cru na tela. Pode existir um selo discreto "termo técnico: X" como nota lateral, nunca como título.
- Use os números reais do inventário como prova concreta (539 tipos, 1058 unidades, 1049 disponíveis, 100% catalogado, metade com QR). Número torna abstrato em palpável.
- Honestidade: a seção de estado mostra o que está pronto e o que falta ativar (RFID real, loop em volume). Não pinte como 100% no ar. O Marcelo confia mais no que é honesto.
- Proibido em-dash. Use vírgula, parênteses ou dois pontos. Sem reticências dramáticas, sem ponto-e-vírgula em prosa, sem exclamação dupla.

### Estrutura narrativa (ordem "como o motor funciona", do chão ao topo)
Cada seção é um bloco vítreo com respiro. A página conta uma história linear, de cima pra baixo:

1. Capa: nome do sistema, uma frase-tese (use a tese do inventário), e os 4 números âncora em destaque (tipos, unidades, % catalogado, eventos).
2. O que o sistema sabe: o modelo Item + Unidade física explicado com a metáfora do "modelo na prateleira vs a peça real com etiqueta". Mostre as 8 categorias e a distribuição real.
3. Quanto vale o patrimônio: as 3 dimensões de condição (estado, desgaste, depreciação) e a conta de valor atual, explicada sem fórmula assustadora, como "o sistema sabe quanto cada peça vale hoje sem reavaliação manual".
4. O loop operacional: o coração. Diagrama do fluxo Alocar, Check-out, Campo, Check-in, Resolver pendência. Cada etapa com uma frase do que o motor garante. Destaque o gate de prontidão e o "nada some no escuro".
5. Web e campo, mesmo motor: como a gestão (web, escritório) e o campo (iPhone, galpão, RFID/QR) usam a mesma regra, sem dois sistemas conflitantes.
6. RFID, software pronto para a prova de campo: use o bloco "Contexto RFID" abaixo. Mostre o fluxo de ponta a ponta (tag lida pelo RFD40, recebida no iPhone, enviada pro sistema, registrada no histórico), o tratamento de tag conhecida (associa ao equipamento) e desconhecida (registra para tratar depois), e o plano de teste em três passos (bancada, galpão, fluxo real pequeno). Deixe claro o status: software pronto para prova física, ainda não validado em campo.
7. Segurança e auditoria: papéis (quem lê, quem opera, quem manda), e a trilha de registro de tudo que sai e volta.
8. Estado honesto: pronto vs por ativar, com os números que provam (catálogo 100%, QR em 50%, loop em validação). O RFID já tem a seção 6, aqui é só o resumo do todo.
9. Fecho: a frase-tese de novo, agora carregada de tudo que veio antes.

Ajuste a quantidade de seções se a narrativa pedir, mas mantenha a ordem do chão (dados) ao topo (tese).

### Contexto RFID (base factual da seção 6, não invente além disso)
Foi feita a integração de software entre o app do iPhone, o SDK da Zebra e o sistema da MMD. A integração foi pensada no fluxo inteiro, não só no leitor.

O que o software já faz:
- O app já está preparado para receber leituras do RFD40.
- O sistema já grava essas leituras como histórico RFID.
- Tag já cadastrada: o sistema associa a leitura ao equipamento correto.
- Tag ainda não cadastrada: o sistema não descarta, registra como tag desconhecida para tratar depois.
- O fluxo é ponta a ponta: tag lida pelo RFD40, recebida no iPhone, enviada para o sistema, registrada no histórico.

O que falta: a prova de campo com leitor físico, iPhone e tags reais no ambiente da MMD. Validar pareamento, distância de leitura, velocidade, estabilidade e leitura em equipamentos reais.

Plano da próxima etapa, teste controlado com 10 a 20 equipamentos já etiquetados:
1. Bancada: leitura simples e próxima.
2. Galpão: equipamentos no ambiente real.
3. Fluxo real pequeno: inventário, saída para evento ou retorno.
O objetivo não é implantar em tudo de uma vez. É confirmar que o fluxo funciona de ponta a ponta e descobrir os ajustes finos antes de escalar para o inventário completo.

Para o teste precisamos de: RFD40, iPhone, acesso ao app, tags RFID reais e alguns equipamentos separados.

Status correto hoje: software RFID pronto para prova física. O que ainda não dá pra dizer: RFID validado em campo. Os 0 registros de RFID no banco são coerentes com isso, a etiquetagem física e a prova de campo ainda não começaram.

### Regras visuais
- Liquid Glass 2030, dark-first. Superfícies vítreas translúcidas, acento ciano, bom contraste, tipografia limpa (Inter Tight para texto, mono para números e códigos como `MMD-ILU-0001`). Use os tokens reais do `globals.css`.
- Diagramas são SVG inline desenhados à mão (caixas, setas, fluxos), não imagens nem libs. O diagrama do loop operacional é a peça central, capriche nele: largo e baixo, fácil de ler de relance, não uma escada vertical gigante.
- Responsivo de verdade: tem que ficar bom no MacBook (apresentação na tela grande) e no iPhone (Marco pode abrir no celular). Teste os dois.
- Pode ter microinterações leves (hover nos cards, um número que conta ao entrar na tela), com CSS e JS vanilla inline. Nada que distraia da explicação.
- Acessível: contraste adequado, texto legível, navegação por teclado não quebrada.

### Modo de trabalho do loop (como iterar)
1. Mantenha o estado em `tasks/apresentacao-marcelo/progresso.md`: um checklist com cada seção e o status (pendente, feito, verificado). Crie na primeira iteração se não existir.
2. A cada ciclo: leia o progresso, pegue o próximo item não concluído, implemente ou refine só ele (não reescreva a página inteira toda vez), salve o HTML.
3. Verifique no navegador de verdade: abra o arquivo (`file://` do caminho absoluto) com as ferramentas de browser disponíveis (chrome-devtools MCP ou skill de browse), tire screenshot no tamanho desktop e no tamanho iPhone, confira render, contraste, layout e se os números batem com o inventário. Conserte o que estiver torto antes de marcar verificado.
4. Atualize o progresso e siga para o próximo item. Uma seção bem feita e verificada por ciclo vale mais que a página inteira meia-boca.
5. Pare quando o Definition of Done fechar inteiro. Não fique refinando sem fim.

### Definition of Done (verificável, tudo precisa bater)
- [ ] `index.html` abre no navegador sem erro de console e sem dependência externa.
- [ ] As 9 seções existem, na ordem narrativa, cada uma em linguagem de dono de empresa.
- [ ] Todo número na tela bate com `inventario-motor.md`. Zero número inventado.
- [ ] O diagrama do loop operacional é SVG inline, largo e baixo, legível de relance.
- [ ] A seção RFID mostra o fluxo ponta a ponta, o tratamento de tag conhecida e desconhecida, o plano de teste em três passos e o status "pronto para prova física, não validado em campo".
- [ ] Layout verificado por screenshot em desktop e em iPhone, ambos sem quebra.
- [ ] A seção de estado honesto mostra pronto e por ativar (loop em validação, etiquetagem física a iniciar).
- [ ] Nenhum em-dash, nenhuma reticência dramática, nenhum jargão técnico cru como título.
- [ ] Fidelidade visual ao Liquid Glass: tokens reais do `globals.css`, dark-first, acento ciano, superfícies vítreas.
- [ ] `progresso.md` com todos os itens marcados como verificados.

### Não faça
- Não invente capacidade, número ou integração que não esteja no inventário.
- Não use bibliotecas, frameworks, CDNs ou fontes externas que exijam rede.
- Não toque no app `apps/web` nem em migrations, RLS, RPC ou contrato de API.
- Não diga que o RFID está validado em campo. A posição correta: software pronto para prova física, validação de campo pendente. Os 0 registros no banco refletem que a prova ainda não rodou, não que o software não exista.
- Não encha de animação que rouba atenção da explicação.
- Não declare pronto sem o screenshot de verificação. Prosa descritiva não conta como prova.

## Fim do prompt

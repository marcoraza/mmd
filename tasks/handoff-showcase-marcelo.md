# Handoff completo: treinamento e showcase MMD para Marcelo

Você está assumindo a entrega do sistema de treinamento do MMD Estoque. Trabalhe no repositório `/Users/marko/Projects/mmd` e conduza a frente até haver material validado, gravado e utilizável pelo Marcelo sem acompanhamento constante do Marco.

## Missão

Transformar o produto atual em um treinamento privado, didático e verificável, com duas propostas separadas:

1. Web: gestão do estoque e ciclo completo de um Evento.
2. iOS: instalação no iPhone e operação de campo com Zebra RFD40, QR, check-out e retorno.

O resultado final terá um hub privado dentro do MMD, dois showcases independentes, um vídeo mestre narrado, os dois cortes independentes, texto por capítulo, troubleshooting e acompanhamento simples de conclusão.

O critério de sucesso é objetivo: depois da primeira instalação assistida, Marcelo consegue repetir a operação consultando o material, sem depender do Marco para cada passo.

## Linear

Use `MAR-85 Treinamento: autonomia do Marcelo` como issue matriz. Ordem de execução:

1. `MAR-215 Base de treino: evento isolado e reutilizável`
2. `MAR-216 iOS: instalação assistida no aparelho do Marcelo`
3. `MAR-217 iOS: showcase da operação com RFD40`
4. `MAR-218 Web: showcase do ciclo completo do evento`
5. `MAR-99 Hub: treinamento Web e iOS`
6. `MAR-100 Tutorial: limites e solução de erros`
7. `MAR-219 Vídeo: narração e cortes Web/iOS`
8. `MAR-98 Handoff: primeira operação do Marcelo`

As issues `MAR-215` a `MAR-219`, `MAR-99` e `MAR-100` já estão em `In Progress` porque possuem trabalho local comprovado. `MAR-98` continua em `Todo`. Comente evidências concretas ao fechar cada etapa: commit, build, teste, URL, screenshot, vídeo ou blocker. Não marque `Done` por texto descritivo.

## Estado verificado em 17/07/2026

- Branch atual: `cc/sprint-auth-ios`.
- HEAD: `72cc9f6 ios: sessao Supabase Auth com login, Keychain e refresh single-flight`.
- `main` está em `005d99f`.
- Web vivo: `https://mmd-zeta.vercel.app`.
- Supabase: projeto `bphmxticdyuctovfumcj`.
- Xcode local: 26.3.
- Simulador disponível: iPhone 17, iOS 26.3.
- O build `Release` do iOS foi corrigido e passou para arm64 device.
- A suíte iOS passou com 91 de 91 testes no thread de execução.
- O SDK Zebra oficial foi religado via SPM no commit exato `0d450520eb700a96e10e0dbd8d1c3e13eed5f111`, usando o produto `Zebra123RFIDsdkSPM`.
- `ZebraRFIDManager.swift` foi ajustado contra as APIs reais do framework e o runtime agora falha fechado quando o SDK está ausente, sem fingir hardware com mock.
- Uma Release assinada foi instalada e aberta no iPhone físico `marko`. Marco confirmou na tela `Modo ativo: ZEBRA SDK`.
- Marco confirmou que o iPhone, o RFD40 e as tags reais estão com o Marcelo.
- O Evento `TRN-MARCELO-01` foi criado no backend real com 4 linhas de packing, 5 unidades e prontidão inicial 4 de 5. O post-check terminou sem mudanças pendentes.
- O hub local foi restaurado com `/treinamento`, `/treinamento/web`, `/treinamento/ios`, 13 capítulos Web e 9 capítulos iOS.
- A migration `20260717004500_training_progress.sql` existe localmente, mas não foi aplicada no remoto. O hub ainda não foi publicado.
- O preview Web tem 8 cenas reais e 14 destaques. O iOS tem 6 cenas e 13 destaques, ainda rotulados como storyboard.
- Existe uma prova de movimento de 56 segundos em `out/training-showcase-preview/mmd-tutorial-motion-v1.mp4`.
- O preview de 5:45 no Claude Design ficou interrompido antes das correções finais. Ainda expõe um endpoint do Supabase, um EPC bruto, um foco incorreto e a palavra `Mock` na capa.
- O working tree possui 34 entradas modificadas ou não rastreadas e ainda não há commit de entrega.

Conclusão obrigatória: não refaça a integração Zebra nem recrie o Evento de treinamento. Preserve e revise o trabalho local. O próximo gate físico é instalar no aparelho do Marcelo, conectar o RFD40 e capturar leituras reais. Storyboard e mock não entram no corte final como prova física.

## Fontes de verdade

Leia antes de editar:

- `AGENTS.md`
- `docs/mar-171-agent-brief.md`
- `docs/handoff.md`
- `tasks/mar-171-supervisor.md`
- `docs/guia-marcelo.md`, sabendo que partes estão desatualizadas
- `tasks/apresentacao-marcelo/`, somente como referência de narrativa e evidência antiga
- código atual de `apps/web` e `apps/ios/MMDEstoque`
- últimas 10 sessões disponíveis de Claude Code e Codex relacionadas ao repo, se o harness permitir
- últimas mudanças Git e diff da branch atual contra `main`

Código e execução real ganham de documento antigo. Quando houver divergência, atualize o handoff e registre a correção.

## Plano obrigatório antes de editar

Escreva em `tasks/todo.md` um plano numerado no formato `passo -> verificação`. Preserve conteúdo existente. O plano mínimo deve cobrir:

1. Auditoria e blockers -> builds e runtime identificados.
2. Evento de treino -> estado inicial reproduzível.
3. Web -> fluxo ponta a ponta executado.
4. iOS -> instalação, SDK e device real validados.
5. RFD40 -> pareamento e leituras reais persistidas.
6. Captação -> takes conferidos antes da edição.
7. Hub -> auth, capítulos e progresso funcionando.
8. Entrega -> vídeos, legendas, transcript, QA e Linear atualizados.

## Gate 0: não gravar antes disso

### Web

Rode em `apps/web`:

```bash
npm install
npm exec tsc -- --noEmit
npm run lint
npm run build
node --test --experimental-strip-types src/lib/*.test.ts src/lib/data/*.test.ts
```

Suba localmente a mesma revisão que será gravada. Use backend real apenas com as variáveis já existentes e o Evento isolado. Nunca mostre valores de env, tokens, cookies ou service role em vídeo, log ou screenshot.

### iOS

O build `Release` já foi corrigido. Reprove no checkout atual antes de gravar:

```bash
xcodebuild \
  -project apps/ios/MMDEstoque/MMDEstoque.xcodeproj \
  -scheme MMDEstoque \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Depois rode a suíte Debug no iPhone 17 disponível. Um teste RFID isolado passando não substitui a suíte completa.

### Zebra real

Antes de qualquer captura apresentada como real:

1. Preserve a resolução SPM no commit `0d450520eb700a96e10e0dbd8d1c3e13eed5f111` e o produto `Zebra123RFIDsdkSPM`.
2. Reprove o build arm64 de device e a suíte completa. O estado de referência é Release verde e 91 de 91 testes.
3. Prove na UI que `runtimeMode == .zebra`, nunca `.zebraFallbackMock`.
4. Instale um build assinado no iPhone físico que está com o Marcelo.
5. Confirme login, refresh da sessão e acesso ao Evento `TRN-MARCELO-01`.
6. Descubra e conecte o RFD40 real do Marcelo.
7. Leia pelo menos 5 tags físicas, incluindo uma conhecida e uma ainda não vinculada.
8. Prove persistência e efeito operacional no backend.
9. Registre versão do app, versão do SDK, aparelho, data e resultado no shot log.

O iPhone, o RFD40 e as tags já existem e estão com o Marcelo. Se a dependência local não puder ser reproduzida, faltar signing ou faltar credencial, pare essa frente e peça exatamente o item ausente ao Marco. Continue somente com Web, hub, roteiro e captação simulada rotulada como `Simulação`. Simulação nunca entra no corte final como prova física.

## Base de treino

Crie um Evento isolado chamado `Treinamento · Marcelo`. Ele usa o backend real e não pode misturar movimentação com Evento de cliente.

Requisitos:

- conjunto pequeno e determinístico de itens e unidades
- pelo menos 5 tags reais quando o hardware estiver disponível
- uma tag conhecida
- uma tag desconhecida para o fluxo de tratamento
- packing incompleto para mostrar prontidão e bloqueio
- packing completo para liberar saída
- uma unidade apta a retornar OK
- uma unidade apta a demonstrar problema ou pendência
- mecanismo idempotente para preparar o estado inicial
- relatório de estado antes e depois de cada take

Não delete nem restaure dados de produção sem confirmação explícita do Marco. Prefira registros dedicados ao treinamento e transições reversíveis. Qualquer script de preparação deve ter modo `probe` sem escrita e listar exatamente o que será alterado.

## Showcase Web

Proposta: gestão de um Evento do começo ao fim. O Web não é uma versão grande do app de campo.

Roteiro obrigatório:

1. Login: entrar como usuário real sem exibir senha.
2. Dashboard: explicar disponíveis, em campo, manutenção, prontidão e alertas.
3. Catálogo: localizar um item, abrir detalhe, diferenciar tipo de item e unidade física.
4. Evento: abrir `Treinamento · Marcelo` e explicar ficha, cliente, datas e contexto.
5. Packing: adicionar ou revisar itens e mostrar cobertura própria e aluguel avulso quando aplicável.
6. Alocação: selecionar unidades, mostrar disponibilidade e conflito de forma didática.
7. Gate de saída: mostrar por que uma saída bloqueia e o que precisa ser corrigido.
8. Check-out: concluir a saída válida e provar mudança de estado.
9. Dashboard depois da saída: mostrar o reflexo operacional, sem corte que esconda a atualização.
10. Retorno: conferir item OK, item com problema e item não devolvido, explicando a pendência.
11. QR: gerar ou abrir uma etiqueta e mostrar a ficha pública segura.
12. Auditoria: mostrar quem fez, quando fez e o histórico criado.
13. Fecho: recapitular o ciclo em linguagem operacional, sem slogan.

Grave o fluxo corrido depois de validar cada capítulo isoladamente. Não improvise o roteiro durante o take final.

## Showcase iOS

Proposta: execução de campo no iPhone, com o RFD40 e QR como fallback. Não repetir a gestão do Web.

### Capítulo de instalação assistida

Mostre a instalação real no aparelho do Marcelo:

1. Pré-requisitos no Mac e no iPhone.
2. Conexão do iPhone por cabo e confiança no computador.
3. Seleção do aparelho no Xcode.
4. Adição do Apple ID gratuito e personal signing.
5. Seleção correta de Team e bundle id, sem mostrar dados sensíveis.
6. Build e instalação no aparelho.
7. Confiança no perfil de desenvolvedor, caso o iOS peça.
8. Primeiro launch.
9. Explicação curta de que assinatura gratuita expira e pode exigir reinstalação em cerca de 7 dias.
10. Depois da validação, registrar como próximo passo a conta Apple Developer paga e distribuição por TestFlight.

Não diga que TestFlight está disponível antes de existir conta paga, archive válido e distribuição aprovada.

### Capítulo de operação

Parta do estado sem configuração e sem leitor conectado:

1. Login no app com sessão real.
2. Configuração segura de ambiente, sem exibir chave ou token.
3. Desativação explícita do leitor simulado.
4. Prova visual do modo `Zebra SDK`.
5. Preparação do RFD40 conforme documentação oficial: carga, modo, pareamento e permissões.
6. Busca, descoberta e conexão do leitor.
7. Câmera externa mostra RFD40, gatilho, tags e distância. Captura do iPhone mostra a resposta do app.
8. Leitura de tag conhecida e abertura da unidade correta.
9. Leitura de tag desconhecida e registro para tratamento, sem descarte silencioso.
10. Abertura do Evento `Treinamento · Marcelo`.
11. Conferência de packing e leitura em lote.
12. Check-out pelo app usando a mesma regra do Web.
13. Prova no Web ou backend de que a saída foi registrada.
14. Retorno pelo app com resultado OK.
15. Retorno com problema ou pendência e explicação do efeito.
16. QR como fallback quando RFID não estiver disponível.
17. Recuperação de erro: leitor desconectado, tag não encontrada e sessão expirada.
18. Fecho: o que o operador faz no iPhone e o que o sistema garante por trás.

## Captação técnica

Grave imagem limpa primeiro. Narração vem depois da edição do fluxo.

### Preparação comum

- Ative Não Perturbe em Mac e iPhone.
- Feche mensageria, email, gerenciador de senhas, terminais com secrets e abas pessoais.
- Use usuário e dados exclusivos de treinamento.
- Fixe idioma, timezone, escala, zoom e aparência antes do primeiro take.
- Desative atualizações automáticas e processos que possam abrir popups.
- Sincronize relógios do Mac, iPhone e câmera.
- Nomeie takes como `YYYYMMDD-superficie-capitulo-takeNN`.
- Mantenha um `shot-log.md` com arquivo, duração, estado inicial, estado final e observações.

### Web

- Capture em 2560x1440, 60 fps quando a máquina sustentar sem frame drop.
- Exporte o corte Web em 2560x1440, 30 fps.
- Use Chrome limpo, zoom 100%, cursor visível e movimentos lentos.
- Não mostre barra de favoritos, extensões, DevTools, URL com token ou notificações.
- Faça pausa de 1 segundo antes e depois de cada ação importante para permitir edição.
- Evite scroll rápido. Dados e labels precisam permanecer legíveis no vídeo final.

### iPhone e RFD40

Use duas fontes sincronizadas:

1. Tela do iPhone via QuickTime, cabo USB e `Nova Gravação de Filme`, selecionando o iPhone como câmera.
2. Câmera externa em tripé mostrando mão, iPhone, RFD40, gatilho e tags.

Configuração da câmera externa:

- 4K, 30 fps
- shutter próximo de 1/60
- foco, exposição e balanço de branco travados
- enquadramento 16:9, ângulo superior ou 45 graus
- luz contínua sem reflexo que impeça ler a tela
- fundo limpo e tags identificáveis sem expor patrimônio de cliente

No início de cada take, faça um gesto ou toque visível nas duas fontes para sincronização. Preserve o beep real do leitor em trilha baixa quando ele ajudar a confirmar a ação. Não use beep inserido para fingir leitura.

O capítulo de instalação pode usar uma composição 16:9 com Xcode em destaque e a tela do iPhone em inset. O showcase operacional iOS deve ter também um corte vertical 1080x1920, sem transformar a interface em miniatura dentro de um canvas horizontal.

### Edição e export

Entregue:

- `mmd-treinamento-master.mp4`, alvo de 25 a 35 minutos
- `mmd-showcase-web.mp4`, alvo de 10 a 15 minutos
- `mmd-showcase-ios.mp4`, alvo de 12 a 18 minutos
- versão vertical do fluxo operacional iOS
- `.vtt` em pt-BR para cada vídeo
- transcript integral em Markdown
- roteiro final com timecodes e capítulos
- thumbnails e stills de cada capítulo

Encode recomendado para distribuição Web:

```bash
ffmpeg -i INPUT.mov \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart OUTPUT.mp4
```

Narração:

- voz sintética natural em pt-BR
- texto escrito depois do picture lock
- ritmo calmo, frases curtas e vocabulário de operação
- sem jargão técnico cru
- sem música competindo com a voz
- loudness consistente, sem clipping
- legenda revisada contra o áudio final

Use chamadas visuais apenas quando ajudarem a localizar uma ação. Nada de cobrir a interface com anéis, setas e texto. O padrão do `raza-showcase` serve para seleção de cenas e clareza, não para transformar o tutorial em apresentação de marketing.

## Hub privado

Implemente no app Web existente, protegido pela mesma autenticação do MMD. Não publique como Artifact e não crie landing page.

Rotas sugeridas:

- `/treinamento`
- `/treinamento/web`
- `/treinamento/ios`

O hub deve conter:

- entrada clara para Web e iOS como propostas diferentes
- vídeo de cada frente
- capítulos navegáveis com timecode
- texto curto do que a pessoa fará e do resultado esperado
- detalhes expansíveis para instalação, erros e recuperação
- versão validada e data da última validação
- status simples de conclusão por usuário autenticado
- indicação honesta de dependências físicas ou operacionais

Atualize o conteúdo quando o fluxo mudar. Ajuste cosmético que não altera operação não invalida o tutorial.

Para vídeos privados, prefira o Supabase Storage já existente, em bucket privado, com URL assinada emitida no servidor para usuário autenticado. Não coloque arquivos grandes no Git. Se o bucket ou as políticas exigirem migration, crie e valide localmente, mas peça confirmação ao Marco antes de aplicar no Supabase remoto.

## Troubleshooting mínimo

Cubra em linguagem simples:

- login recusado ou sessão expirada
- app gratuito expirou e precisa ser reinstalado
- iPhone não aparece no Xcode
- perfil de desenvolvedor não confiável
- RFD40 não aparece
- app mostra `Simulado` ou `Simulado (fallback)`
- leitor desconecta no meio da leitura
- tag conhecida não resolve equipamento
- tag desconhecida
- QR não abre
- Evento bloqueado para saída
- retorno cria pendência
- Web sem acesso ao backend

Cada erro deve ter: sintoma, causa provável, ação segura e quando chamar Marco.

## QA e Definition of Done

- Web typecheck, lint, testes e build verdes.
- iOS Debug e Release verdes.
- Testes iOS completos verdes.
- Build instalado em iPhone físico.
- UI mostra `Zebra SDK`, sem fallback.
- RFD40 real pareado e conectado.
- Pelo menos 5 tags reais lidas.
- Tag conhecida e desconhecida comprovadas.
- Check-out e retorno reais refletidos no backend.
- Evento de treino isolado e reproduzível.
- Web gravado do login ao retorno.
- iOS gravado da instalação à operação.
- Câmera externa e captura da tela sincronizadas.
- Nenhum secret, dado pessoal ou notificação nos frames.
- Vídeo mestre e cortes independentes exportados.
- Áudio sem clipping e legendas sincronizadas.
- Hub privado exige login e funciona em desktop e mobile.
- Progresso simples persiste para o usuário.
- Versão e data validadas aparecem no conteúdo.
- Screenshots desktop e mobile do hub salvos como evidência.
- Linear atualizado com links e provas.
- `git status` sem arquivos efêmeros, vídeos brutos ou secrets.

## Condições de parada

Pare e pergunte ao Marco antes de:

- aplicar migration ou alterar dados reais fora do Evento de treino
- apagar ou restaurar registros remotos
- publicar vídeo que mostre rosto, voz ou dados pessoais de terceiro
- comprar Apple Developer Program ou qualquer serviço
- usar um SDK Zebra sem licença ou origem oficial
- afirmar que RFID está validado sem device, SDK, leitor e tags reais
- fazer deploy de produção

Ao encontrar blocker, reporte em quatro linhas: `Verifiquei`, impacto, item necessário e o que continua executável em paralelo.

## Relatório final

Abra com `Implementado e funcionando` somente quando todos os critérios aplicáveis estiverem provados. Liste comportamento visível, links, builds, testes, evidência física, versão gravada e risco residual. Use um bloco `Ainda não fechado` para qualquer item que dependa de hardware, conta paga, TestFlight, migration remota ou validação do Marcelo.

Não encerre com proposta abstrata. Deixe o próximo passo operacional já preparado.

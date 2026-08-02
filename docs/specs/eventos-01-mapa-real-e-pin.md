# Spec · Eventos 01 · Mapa real e pin do destino

Status: `ready-for-agent`

Fatia de localização real da aba Eventos no Event Pro. Este setor substitui o
mapa ilustrativo pelo destino verdadeiro do Evento. Não inclui rota nem
localização do funcionário.

## Problem Statement

A aba Eventos exibe um mapa visualmente convincente, mas inteiramente
ilustrativo. As ruas, o pin e a curva são geometrias fixas, sem relação com o
local cadastrado. O produto também possui apenas o nome livre do local no modelo
iOS, embora a ficha do Evento já guarde endereço e cidade/UF no Supabase.

Esse estado cria duas falhas operacionais. Primeiro, o operador não consegue
ver onde o Evento realmente acontecerá. Segundo, qualquer distância ou rota
derivada desse mapa seria inventada. A ausência de uma coordenada persistida
também impede que todos os aparelhos apontem para a mesma portaria, doca ou
entrada de carga.

O endereço textual sozinho não resolve o problema. Uma busca pode encontrar o
empreendimento correto e ainda posicionar o resultado na entrada errada. O
produto precisa obter uma coordenada a partir do endereço, mostrar essa
coordenada num mapa real e permitir correção direta sem transformar o fluxo em
um formulário com confirmação redundante.

## Solution

O Event Pro passa a usar MapKit nativo para buscar locais e exibir cartografia
real. Ao selecionar uma sugestão de endereço, o app recebe a coordenada do Apple
Maps, mostra o pin automaticamente e salva a coordenada no Evento sem botão
adicional de confirmação. O endereço humano continua vindo da ficha do Evento.

O mapa compacto da aba Eventos mostra o destino salvo e preserva a composição
visual atual. Quando um usuário autorizado entra em edição, o app abre uma
superfície expandida no padrão Uber: o pin fica fixo no centro e o mapa se move
sob ele. Ao terminar o gesto, a nova coordenada é salva automaticamente e o app
oferece desfazer.

Esta fatia não acessa a posição atual do iPhone. Buscar, mostrar e ajustar o
destino não solicita permissão de localização. A coordenada armazenada pertence
ao Evento, nunca ao funcionário.

## User Stories

1. Como responsável pelo Evento, quero buscar o local pelo nome, para encontrar espaços conhecidos sem digitar o endereço completo.
2. Como responsável pelo Evento, quero buscar pelo endereço completo, para localizar um destino que não aparece pelo nome comercial.
3. Como responsável pelo Evento, quero ver sugestões enquanto digito, para escolher um resultado reconhecido pelo Apple Maps.
4. Como responsável pelo Evento, quero que cada sugestão mostre nome e endereço, para distinguir locais com nomes parecidos.
5. Como responsável pelo Evento, quero que o endereço já existente na ficha seja usado como ponto de partida da busca, para não digitar a mesma informação de novo.
6. Como responsável pelo Evento, quero que selecionar uma sugestão mostre o pin imediatamente, para verificar visualmente onde o resultado caiu.
7. Como responsável pelo Evento, quero que a sugestão escolhida seja salva automaticamente, para não enfrentar uma etapa redundante de confirmação.
8. Como responsável pelo Evento, quero editar um destino já salvo, para corrigir um resultado antigo ou impreciso.
9. Como responsável pelo Evento, quero arrastar o mapa sob um pin fixo, para posicionar o destino com precisão sem tentar agarrar um alvo pequeno.
10. Como responsável pelo Evento, quero marcar a portaria ou a entrada de carga real, para a equipe não chegar no acesso social errado.
11. Como responsável pelo Evento, quero que a nova posição seja salva quando eu terminar o gesto, para o fluxo se comportar como um app de mobilidade.
12. Como responsável pelo Evento, quero desfazer a última alteração do pin, para recuperar o ponto anterior após um movimento acidental.
13. Como responsável pelo Evento, quero receber confirmação visual curta de que o local foi atualizado, para saber que a gravação terminou.
14. Como responsável pelo Evento, quero que uma falha de gravação restaure o último pin válido, para o mapa nunca mostrar como salvo algo que não chegou ao banco.
15. Como operador de campo, quero ver um mapa real no card do Evento, para reconhecer visualmente o destino antes da montagem.
16. Como operador de campo, quero que o mapa acompanhe o Evento selecionado na agenda, para nunca confundir destinos ao navegar rapidamente.
17. Como operador de campo, quero ver o nome e o endereço junto do mapa, para continuar operando quando a cartografia não carregar.
18. Como operador de campo, quero um estado explícito quando o Evento ainda não possui pin, para não interpretar um mapa genérico como destino verdadeiro.
19. Como operador de campo, quero que o app não solicite minha localização para mostrar o destino, para manter privacidade e evitar um prompt sem necessidade.
20. Como operador de campo, quero que o mapa compacto preserve o gesto horizontal entre Eventos, para o novo mapa não quebrar a navegação existente.
21. Como Marcelo, quero que todos os aparelhos carreguem a mesma coordenada do Supabase, para a equipe inteira receber o mesmo destino.
22. Como Marcelo, quero limitar a edição do destino a usuários autorizados, para um operador não mover a entrada do Evento por acidente.
23. Como Marcelo, quero que eventos antigos sem coordenada continuem abrindo normalmente, para a migration não quebrar o histórico.
24. Como Marcelo, quero que endereço e pin sejam conceitos separados, para ajustar a doca sem adulterar o endereço oficial do local.
25. Como usuário de VoiceOver, quero ouvir o nome do local e o estado do pin, para entender o destino sem depender apenas do mapa.
26. Como equipe de desenvolvimento, queremos ignorar respostas antigas de busca e gravação, para uma interação rápida nunca sobrescrever a escolha mais recente.
27. Como equipe de desenvolvimento, queremos que a coordenada seja validada no banco, para latitude e longitude inválidas ou incompletas nunca virarem estado persistido.
28. Como equipe de desenvolvimento, queremos testar a feature sem chamar Apple Maps ou Supabase reais, para a suíte ser rápida e determinística.

## Implementation Decisions

- A implementação usa MapKit nativo no Event Pro. MapKit JS, Google Maps, Mapbox e Apple Maps Server API não entram nesta fatia.
- A fonte textual do destino continua sendo a ficha do Evento: nome do local, endereço e cidade/UF. O modelo iOS passa a decodificar apenas o subconjunto necessário dessa ficha, sem duplicar o endereço em uma nova coluna.
- A busca combina as partes disponíveis do destino e usa a busca local do MapKit. Uma resposta só vira destino depois que o usuário escolhe uma sugestão; o primeiro resultado nunca é aceito silenciosamente.
- Selecionar uma sugestão é a confirmação implícita da escolha. O app mostra o pin e inicia a gravação automaticamente. Não existe botão "Confirmar local".
- O Evento recebe latitude, longitude e horário da última atualização do destino. Latitude e longitude são opcionais para preservar eventos legados, mas devem existir juntas e respeitar os limites geográficos válidos.
- O pin pertence ao Evento e é persistido no Supabase. O app não serializa nem armazena objetos internos do MapKit.
- A leitura dos novos campos usa a consulta PostgREST já existente. A escrita ganha uma operação direta e autenticada para atualizar somente os campos do destino. Nenhum endpoint do web é criado ou alterado.
- A escrita preserva o contrato atual de Supabase Auth e RLS: usuários autenticados podem ler Eventos; perfis `editor` e `admin` podem atualizar o destino; perfil `viewer` permanece somente leitura. A migration não amplia acesso para `anon`.
- A policy de atualização mantém `USING` e `WITH CHECK`, apoiada pela policy de leitura exigida pelo Postgres para `UPDATE`. O cliente nunca usa chave `service_role`.
- O mapa compacto da aba Eventos é passivo. Ele preserva o carrossel horizontal e abre a superfície expandida por toque, evitando conflito entre o gesto de trocar Evento e o pan do mapa.
- A composição compacta preserva altura, full bleed, paleta escura, pin branco com halo, sincronização com a agenda e transição de câmera. Ruas, água e quarteirões passam a representar a cartografia real, portanto não serão idênticos à geometria ilustrativa atual.
- A superfície expandida usa um pin visualmente fixo no centro. O usuário move o mapa sob o pin, padrão de apps de mobilidade. A coordenada candidata é o centro final da câmera.
- O app persiste a coordenada quando o gesto de câmera termina, não durante cada frame do movimento. Uma nova edição invalida qualquer gravação anterior ainda em voo.
- Após uma gravação bem-sucedida, o app mostra feedback curto com ação de desfazer. Desfazer restaura a coordenada persistida anterior, não apenas a representação local.
- Se a gravação falhar, a interface volta ao último destino confirmado pelo Supabase e mostra erro acionável. Um pin otimista nunca permanece com aparência de salvo após falha.
- Mover o pin manualmente não reescreve o endereço humano da ficha. Essa ação existe para marcar portaria, doca ou acesso específico dentro do mesmo local.
- Se a busca falhar, não encontrar resultados ou perder conectividade, o destino anterior permanece intacto. O usuário pode tentar novamente sem perder o endereço cadastrado.
- Evento sem coordenada não recebe pin aproximado, mapa aleatório nem geocodificação automática em background. A interface mostra o endereço e o estado "Local ainda não definido".
- Respostas antigas de busca são descartadas quando a consulta muda. O mesmo princípio vale para troca rápida do Evento selecionado: um resultado nunca pode aparecer no Evento seguinte.
- A feature não usa a localização atual do aparelho, não adiciona descrição de uso de localização ao app e não solicita `When In Use`.
- O app não persiste cache próprio de tiles, resultados do Apple Maps ou posição do funcionário. O Supabase guarda apenas a coordenada do destino e seu horário de atualização.
- O target de testes do Event Pro nasce nesta fatia se ainda não tiver sido criado por uma frente anterior. Se o setor RFID Fundação já tiver criado o target quando a implementação começar, esta feature reutiliza o mesmo target e convenções.
- A entrega inclui estado de loading discreto, erro de busca, erro de gravação, ausência de resultados, evento sem pin e fallback textual quando a cartografia não carregar.
- Acessibilidade inclui rótulo do destino, estado de edição, nome e endereço das sugestões, anúncio após atualização e áreas de toque compatíveis com uso em campo.

## Testing Decisions

- A costura comportamental única é um ViewModel da localização do Evento. Ele recebe busca de lugares e persistência do destino por interfaces injetadas. A view não fala diretamente com MapKit nem com rede.
- Testes observam comandos e estado público da feature. Não inspecionam câmera interna do MapKit, implementação de URLSession ou detalhes de renderização SwiftUI.
- Selecionar uma sugestão deve publicar o pin correspondente, persistir a coordenada e terminar no estado salvo sem exigir confirmação adicional.
- Resultado de busca que chega depois de uma nova consulta deve ser ignorado.
- Busca vazia, sem resultados, offline ou com erro deve preservar o último destino persistido.
- Abrir um Evento legado sem coordenada deve produzir o estado "Local ainda não definido" sem falha de decoding.
- Terminar a edição do mapa deve persistir apenas a coordenada final, mesmo que a câmera tenha emitido várias mudanças intermediárias.
- Duas edições rápidas devem deixar persistida a coordenada da edição mais recente.
- Gravação bem-sucedida deve disponibilizar desfazer com a coordenada anterior.
- Desfazer deve persistir o valor anterior e atualizar o mapa, não apenas mudar estado local.
- Falha ao salvar uma seleção ou ajuste deve restaurar o último destino persistido e expor erro recuperável.
- Trocar o Evento durante uma busca ou gravação deve impedir que o resultado altere o Evento recém-selecionado.
- Perfil `viewer` deve ver o destino, não receber comandos de edição e ter a tentativa direta de `UPDATE` negada pelo banco.
- Perfis `editor` e `admin` devem conseguir atualizar o destino sob sessão autenticada, sem ampliar privilégios de `anon`.
- O contrato PostgREST deve ser coberto no mesmo target com rede stubada: nomes das colunas, payload mínimo da atualização e decoding de coordenadas opcionais.
- A migration deve provar os constraints de par obrigatório e faixas válidas, além de aceitar os dois campos nulos para dados legados.
- O prior art de rede é a suíte do APIClient do MMDEstoque. O padrão de ViewModel injetado acompanha as specs RFID do Event Pro, sem criar uma segunda arquitetura de testes.
- A verificação visual é manual e documentada em simulador e iPhone: busca por nome, busca por endereço, seleção automática, edição estilo Uber, desfazer, fallback offline e troca rápida de Eventos.
- O aceite visual compara a composição compacta nova com a atual. O critério é preservar hierarquia e interação, não reproduzir geografia falsa.
- Build, suíte do Event Pro e testes dos constraints são pré-condições. Pronto exige também o fluxo completo rodado em aparelho: buscar, selecionar, fechar, reabrir e encontrar o mesmo pin vindo do Supabase.

## Out of Scope

- Localização atual do funcionário.
- Permissão `When In Use`, localização em background ou rastreamento.
- Cálculo de rota, distância, quilômetros, ETA ou trânsito.
- Linha de rota no mapa compacto.
- Navegação curva a curva dentro do Event Pro.
- Abertura do Apple Maps para navegação.
- MapKit JS ou mapa interativo no web.
- Mudança nos endpoints do web.
- Geocodificação automática de todos os Eventos existentes.
- Backfill silencioso de coordenadas a partir de texto livre.
- Múltiplos pins por Evento, como entrada social, doca e estacionamento separados.
- Histórico completo de alterações do destino além da auditoria já prevista pela plataforma.
- Cache offline próprio de mapas.
- Reescrita da ficha do Evento a partir da posição manual do pin.

## Further Notes

- Estimativa: 4 a 5 dias de uma pessoa sênior, incluindo migration, feature iOS, testes e QA em aparelho.
- O pin é obrigatório como coordenada para um Evento localizado, mas não existe como etapa manual de confirmação. Selecionar endereço salva; editar corrige.
- O endereço continua sendo a descrição humana. O pin é a verdade operacional de chegada.
- Uma conta Apple gratuita permite desenvolver e testar o mapa e o pin em aparelho pessoal com as limitações de provisioning. TestFlight para o cliente continua exigindo Apple Developer Program pago.
- A evolução natural posterior é rota sob demanda com Core Location e `MKDirections`. Ela deve consumir o pin desta spec sem mudar seu contrato.

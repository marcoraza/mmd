# Finalização do mockup Event Pro com versão C e gauntlet

Status: `ready-for-agent`

## Problem Statement

O mockup Event Pro alcançou um nível alto de craft na Home e na tela de Eventos, mas ainda não funciona como um artefato final único. A Home e Eventos usam barras inferiores diferentes, telas antigas ainda podem reaparecer, os fluxos seguintes variam em tipografia, espaçamento, componentes e comportamento, e o trabalho de experimentação continua misturado com o que já foi aprovado.

Marco precisa de um mockup navegável e sólido para a primeira apresentação: todas as telas devem falar a mesma língua, nenhum botão pode terminar em uma tela legada ou morta e cada fluxo deve ser aprovado separadamente antes de o próximo começar.

## Solution

Criar uma versão C como única linha de trabalho, mantendo A e B congeladas lado a lado como referências internas. A versão C começa como cópia fiel do estado aprovado e adota a barra inferior da Home como navegação canônica em todo o mockup.

A finalização será executada por sessões independentes. Cada sessão trata um único pedaço do fluxo e passa por quatro rodadas de gauntlet visual com três papéis: orquestrador, construtor e crítico cego. Marco aprova o melhor resultado de uma sessão antes de liberar a seguinte.

O mockup final será um único HTML canônico, sem seletor de experimentos, sem comparações internas e sem tela legada acessível. O artefato A/B/C existe apenas durante a finalização; somente C evolui.

## User Stories

1. Como operador de estoque, quero encontrar a mesma barra inferior em todas as telas, para que a navegação seja previsível.
2. Como operador de estoque, quero reconhecer a aba ativa imediatamente, para que eu saiba onde estou no app.
3. Como operador de estoque, quero voltar para a Home sem encontrar uma versão antiga, para que o app pareça um produto único.
4. Como operador de estoque, quero abrir Eventos pela barra da Home, para que a troca de área não altere a linguagem visual.
5. Como operador de estoque, quero abrir Catálogo pela mesma navegação, para consultar equipamentos sem mudar de contexto visual.
6. Como operador de estoque, quero abrir Identificar pela mesma navegação, para iniciar uma leitura RFID sem procurar uma ação separada.
7. Como operador de estoque, quero abrir um evento e reconhecer os mesmos pesos tipográficos, espaçamentos e superfícies da Home, para que a tela pareça parte do mesmo app.
8. Como operador de estoque, quero entender nome, local, data e progresso do evento em um olhar, para agir sem interpretar uma tela carregada.
9. Como operador de estoque, quero ver as zonas de separação com estados claros, para saber o que está completo, pendente ou bloqueado.
10. Como operador de estoque, quero continuar uma conferência de saída a partir do evento, para que o trabalho não dependa de navegação paralela.
11. Como operador de estoque, quero ler itens por RFID ou QR no mesmo fluxo, para continuar mesmo quando um meio de leitura não estiver disponível.
12. Como operador de estoque, quero ver o leitor conectado, desconectado e com bateria baixa, para confiar no estado do hardware representado no mockup.
13. Como operador de estoque, quero receber feedback enquanto a leitura acontece, para entender que o app está ativo.
14. Como operador de estoque, quero ver itens identificados, inesperados, repetidos e faltantes com distinção clara, para resolver exceções sem ambiguidade.
15. Como operador de estoque, quero arrastar sheets para baixo e fechá-las sem reabertura indevida, para que a interação pareça nativa.
16. Como operador de estoque, quero confirmar a saída somente quando a conferência estiver resolvida, para evitar uma ação visualmente contraditória.
17. Como operador de estoque, quero ver um estado de sucesso depois da saída, para saber que o fluxo terminou.
18. Como operador de estoque, quero conferir o retorno usando a mesma gramática da saída, para reduzir reaprendizado.
19. Como operador de estoque, quero marcar item correto, danificado ou pendente, para que o retorno represente os estados operacionais importantes.
20. Como operador de estoque, quero consultar as últimas movimentações e abrir a lista completa, para entender o histórico demonstrado pelo mockup.
21. Como operador de estoque, quero consultar o Catálogo com busca, filtros e detalhe consistentes, para que essa área não pareça um produto diferente.
22. Como operador de estoque, quero acessar Mais ou Ajustes sem encontrar controles técnicos expostos, para que o mockup pareça pronto para apresentação.
23. Como apresentador do produto, quero percorrer o caminho completo sem botão morto, para demonstrar a proposta sem explicar limitações do protótipo.
24. Como apresentador do produto, quero selecionar uma cena previsível por URL, para repetir a demonstração e a captura visual.
25. Como responsável pelo produto, quero manter A e B intactas durante a finalização, para comparar C com o que já estava aprovado.
26. Como responsável pelo produto, quero aprovar cada fluxo antes do seguinte, para que nenhuma decisão importante seja enterrada por trabalho posterior.
27. Como responsável pelo produto, quero quatro rodadas de construção e crítica por fluxo, para elevar acabamento sem perder o melhor resultado anterior.
28. Como responsável pelo produto, quero que o crítico julgue imagens sem conhecer qual é a versão nova, para reduzir viés de confirmação.
29. Como responsável pelo produto, quero que cada rodada preserve critérios já aprovados, para evitar regressões silenciosas.
30. Como responsável pelo produto, quero encerrar a fase com um HTML canônico limpo, para que o mockup final não carregue ferramentas de experimentação.

## Implementation Decisions

- A e B são referências internas congeladas. Nenhuma sessão pode alterar sua marcação, estilos ou comportamento.
- C é a única versão mutável e começa como cópia do estado atualmente aprovado.
- A barra inferior da Home é a navegação canônica. A barra específica de Eventos e o botão RFID separado deixam de existir na versão C.
- A navegação canônica possui Início, Eventos, Catálogo e Identificar. A aba ativa usa o mesmo tratamento visual da Home.
- O trabalho é dividido em sessões sequenciais e julgáveis isoladamente. A ordem inicial é: fundação da barra, detalhe do evento, conferência de saída, fluxo RFID completo, separação por zona, retorno, Catálogo, Mais/Ajustes e consolidação global.
- Cada sessão começa do melhor estado aprovado da sessão anterior.
- Cada sessão executa quatro rodadas de gauntlet.
- Há três papéis: o agente principal orquestra; um Claude Opus novo constrói; outro Claude Opus novo critica às cegas pelo canal Claude. O modelo real é registrado pelo retorno do harness.
- O construtor é dono único dos arquivos de C naquela sessão. A e B são somente leitura.
- O crítico recebe a barra, as imagens A/B embaralhadas e os critérios mensuráveis. Ele não recebe a justificativa do construtor antes do pick.
- O ratchet mantém o melhor: uma rodada nova só substitui o melhor quando vence o pick e não transforma um critério aprovado em falha.
- Marco é o freio humano. O próximo fluxo só começa depois de sua aprovação explícita.
- Cor, tipografia, espaço, radius, sombras, ícones e motion devem vir da gramática aprovada da Home. Valores isolados novos exigem justificativa na régua da sessão.
- Motion existe apenas para orientar estado, continuidade ou gesto; usa transform e opacity e permanece abaixo de 300 ms.
- Cada fluxo deve ter uma cena determinística para captura e comparação. Dados de demonstração permanecem fixos durante todas as rodadas da sessão.
- O HTML canônico final será derivado de C depois da aprovação global. Controles A/B/C, instrumentos de gauntlet e parâmetros experimentais não entram nele.

## Testing Decisions

- O principal seam de teste é o mockup C completo no navegador, exercitado por uma única URL canônica com cenas e estados determinísticos. Esse seam cobre navegação, visual, interação e continuidade sem testar detalhes internos dos wrappers.
- Cada sessão captura a página inteira e o estado específico do fluxo em viewport desktop de comparação e viewport mobile de 390 px.
- A validação externa verifica comportamento observável: aba ativa, tela visível, sheet aberta ou fechada, texto essencial, contagem fixa e ausência de tela legada.
- A fundação da barra testa Início, Eventos, Catálogo e Identificar a partir de pelo menos duas telas diferentes.
- Detalhe do evento testa abertura, volta, hierarquia do cabeçalho, lista de zonas e CTA principal.
- Conferência de saída testa estados pendente, parcial, completo, exceção e conclusão.
- RFID testa leitor desconectado, conectado, leitura ativa, resultado, item inesperado, sheet arrastável e fechamento sem reabertura.
- Separação testa zonas completas e incompletas, paginação entre zonas e item fora da lista.
- Retorno testa item correto, defeito, pendência e confirmação.
- Catálogo testa busca, filtros, lista vazia e detalhe.
- Mais/Ajustes testa leitor, conta e ações secundárias sem controles técnicos expostos.
- O gauntlet mede a versão candidata contra o melhor anterior, nunca apenas contra memória ou opinião textual.
- Uma captura branca, cortada, com fonte fallback ou de build antigo anula a rodada.
- A aprovação final exige navegação manual completa e captura do melhor antes, melhor depois e barra interna lado a lado.

## Out of Scope

- Implementação em SwiftUI ou no app de produção.
- Supabase real, autenticação real ou persistência.
- TestFlight, signing, iPhone físico ou Zebra RFD40 real.
- Integração com hardware, Bluetooth, câmera ou permissões reais.
- Cobertura de todos os estados administrativos do produto web.
- Novo redesign da Home ou da tela principal de Eventos já aprovadas.
- Novas funcionalidades que não sejam necessárias para completar a demonstração do fluxo.

## Further Notes

- O objetivo desta especificação é encerrar o mockup, não reabrir a direção visual.
- Home e Eventos são a identidade interna e a principal barra de coerência.
- As referências externas, quando usadas pelo gauntlet, medem apenas acabamento. Parecer com elas é falha.
- A primeira sessão de tela após a fundação é Detalhe do evento.
- O resultado de cada sessão precisa ser apresentado a Marco no preview antes da próxima sessão.

# MMD Estoque Inteligente

Contexto do sistema de estoque inteligente da MMD Eventos, cobrindo a demonstração comercial, a operação com dados reais e o uso de identificação por QR Code e RFID.

Tese do MVP real: sistema web e mobile para transformar evento fechado em ficha, packing, conferência de saída, retorno e dashboard consolidado, com QR/RFID para rastrear unidades.

## Language

**Demo Marcelo**:
Versão demonstrável do sistema para validar valor com Marcelo sem expor o estoque real.
_Avoid_: produção real, entrega final

**Dados reais**:
Informações verdadeiras do estoque da MMD usadas em ambiente controlado.
_Avoid_: dados demo, fixtures

**RFID fisico**:
Leitura de tags reais em equipamentos ou lotes usando leitor Zebra em campo.
_Avoid_: tela RFID, RFID simulado

**Etiquetar**:
Gestão da associação entre uma tag RFID com EPC já gravado e uma unidade rastreável. Inclui vincular, substituir, desvincular, impedir duplicidade e registrar autoria da alteração.
_Avoid_: programar EPC, gravar tag virgem, bloquear memória da tag

**Operação RFID**:
Conjunto completo de ações de estoque feitas no app com o RFD40: conectar, reconectar e desconectar o leitor; exibir bateria, gatilho, falhas e estado real; identificar unidades; etiquetar; conferir saída e retorno; localizar uma unidade por proximidade; resolver tags desconhecidas ou duplicadas.
_Avoid_: manutenção do leitor, atualização de firmware, configuração de Wi-Fi, ajuste manual de antena

**Identificar**:
Operação RFID global para ler várias tags, resolver unidades progressivamente e abrir a ficha de qualquer resultado, sem movimentar estoque.
_Avoid_: check-out implícito, tela de gestão do leitor, leitura simulada

**Localizar**:
Operação RFID de proximidade para encontrar uma unidade etiquetada. Pode partir de qualquer ficha de unidade ou de uma pendência, sem alterar o estado da unidade. Quando existir pendência, a resolução exige confirmação humana e registro da localização.
_Avoid_: radar simulado, marcar como encontrado apenas por receber sinal, tela autônoma de item perdido

**Workspace Localizar**:
Experiência focada em tela cheia para procurar uma unidade enquanto a pessoa se movimenta pelo galpão. Mostra unidade, última localização, proximidade real com resposta visual, háptica e sonora, além da confirmação humana de encontro.
_Avoid_: sheet pequena, scanner geral, medidor apenas decorativo

**MVP operacional real**:
Versão pronta para uso com estoque verdadeiro, acesso controlado, app instalado em aparelho e leitor RFID físico validado em campo.
_Avoid_: demo completa, protótipo, mock

**Produção real pública**:
Ambiente público do sistema usando dados reais da MMD atrás de autenticação própria.
_Avoid_: produção demo, preview privado, local real

**Equipe operacional**:
Pessoa autenticada que opera o estoque no dia a dia.
_Avoid_: viewer, leitor, visitante

**Usuário admin**:
Pessoa autenticada que pode administrar usuários, permissões e ações destrutivas.
_Avoid_: dono, superusuário informal

**Ficha pública QR**:
Página acessível por QR físico que identifica o equipamento sem expor dados sensíveis.
_Avoid_: ficha interna, detalhe completo

**Ficha interna**:
Página autenticada com dados completos de item, unidade, valor, localização e histórico.
_Avoid_: ficha pública, QR público

**Status público QR**:
Estado simplificado exibido na ficha pública: Ativo, Em uso, Indisponível ou Falar com MMD.
_Avoid_: status interno, localização, evento

**Unidade rastreável**:
Peça física individual do estoque que pode receber código, QR Code e RFID próprios.
_Avoid_: item agregado, tipo de equipamento

**Lote legado**:
Agrupamento antigo de peças físicas que existe temporariamente até ser convertido em unidades rastreáveis.
_Avoid_: lote operacional novo

**Conversão de lote**:
Processo de criar unidades rastreáveis a partir de um lote legado antes de apagar o lote original.
_Avoid_: arquivamento de lote, manter lote ativo

**Remoção de lotes**:
Delete físico dos lotes existentes para eliminar o modelo de lote da operação.
_Avoid_: arquivamento, esconder da UI

**Ficha de evento**:
Cadastro operacional do evento, reunindo dados do evento, endereço, montagem, desmontagem, responsáveis e checklist.
_Avoid_: cadastro de item, detalhe de equipamento

**Evento fechado**:
Evento contratado que já deve entrar no sistema para preparação operacional.
_Avoid_: lead, orçamento aberto

**Identificação mínima da unidade**:
Dados mínimos para reconhecer e movimentar uma peça física sem travar o trabalho de campo.
_Avoid_: ficha de evento, cadastro completo de patrimônio

**Packing list**:
Lista operacional de itens e quantidades necessários para preparar um evento.
_Avoid_: checklist do evento, orçamento

**Planilha padrão de packing**:
Arquivo em formato combinado usado para importar itens e quantidades para a packing list de um evento.
_Avoid_: planilha livre, inventário original

**Linha ambígua de packing**:
Linha importada que pode corresponder a mais de um item do catálogo.
_Avoid_: erro silencioso, escolha automática

**Sugestão de packing**:
Rascunho de packing list gerado por histórico, template salvo ou IA para revisão humana.
_Avoid_: packing automática obrigatória

**Alocação**:
Escolha das unidades rastreáveis específicas que serão usadas para atender uma packing list.
_Avoid_: packing genérica, reserva informal

**Aluguel avulso**:
Equipamento alugado de parceiro para cobrir falta de estoque próprio em um evento.
_Avoid_: reserva externa, terceirizado

**Checklist de saída**:
Conferência de que a packing list está atendida antes do equipamento sair para o evento.
_Avoid_: checklist do evento, checklist manual genérico

**Conferência de saída**:
Workspace único e retomável do Evento que salva as leituras automaticamente e mostra o que já foi conferido, o que falta e o que precisa de revisão.
_Avoid_: separar por veículo, criar cargas, exigir uma sequência de recibos

**Check-out físico**:
Transação que registra a saída das unidades efetivamente conferidas por RFID, QR Code ou confirmação manual. Apenas unidades presentes na conferência mudam para EM_CAMPO.
_Avoid_: mover toda a alocação por presunção, usar o scanner apenas como animação, marcar unidade ausente como saída

**Revisar**:
Camada única de exceções da leitura atual. Reúne itens fora da lista, tags desconhecidas, conflitos e unidades indisponíveis sem interromper o scanner.
_Avoid_: modal por erro, tela separada para cada exceção, bloquear toda a leitura

**Recibo operacional**:
Registro persistente de uma escrita confirmada pelo backend, com unidades, método, operador, horário e motivo quando houver exceção.
_Avoid_: overlay genérico de sucesso, confirmação antes do ACK, histórico apenas visual

**Corte visual**:
Rodada comparável de cinco opções para uma única tela, estado ou componente, mantendo função e dados constantes enquanto varia hierarquia, composição, tipografia, espaçamento, gesto e motion.
_Avoid_: cinco produtos diferentes, implementação final sem validação, showcase desconectado do fluxo

**Conferência de retorno**:
Conferência das unidades próprias depois do evento, marcando se voltaram OK, com problema ou não voltaram.
_Avoid_: check-in genérico, inventário completo

**Pendente de resolução**:
Estado de unidade que não voltou do evento e ainda precisa ser localizada ou decidida.
_Avoid_: baixa imediata, perdido definitivo

**Dashboard consolidado**:
Visão de gestão que reúne prontidão de eventos, uso por categoria, manutenção/perdas e patrimônio.
_Avoid_: relatório isolado, painel financeiro

**Orçamento e contrato**:
Registro web do status, link ou anexo comercial de um evento.
_Avoid_: financeiro completo, contrato jurídico gerado pelo sistema

## Relationships

- A **Demo Marcelo** pode usar dados demo para provar o fluxo sem revelar **Dados reais**
- **Dados reais** exigem controle de acesso antes de uso público
- **RFID fisico** depende de tags reais, leitor real e teste em campo
- **RFID fisico** só é aprovado quando RFD40 pareia no iPhone, lê pelo menos 5 tags reais, resolve essas tags nos **Dados reais** e muda status via check-out/check-in
- **Etiquetar** opera EPCs já presentes nas tags e não programa nem bloqueia a memória física da tag
- **Etiquetar** permite vincular, substituir e desvincular uma tag, rejeita associação duplicada e registra quem realizou a alteração
- **Etiquetar** parte da ficha de uma unidade ou de uma tag desconhecida encontrada por **Identificar** ou por uma Conferência
- Mover uma tag entre unidades ou substituir a tag atual acontece como uma única transação auditada
- Toda **Operação RFID** da rotina da MMD acontece no app
- **Operação RFID** não inclui manutenção técnica do RFD40, atualização de firmware, configuração de Wi-Fi nem ajuste manual de antena
- O app tenta reconectar o último RFD40 confiável apenas quando uma **Operação RFID** começa
- O gatilho físico só lê enquanto um workspace RFID está ativo; pressionar inicia e soltar pausa
- Perda de conexão pausa a leitura, preserva o rascunho e oferece QR Code ou confirmação manual quando o contexto permitir
- **Identificar** é a única entrada RFID global; **Etiquetar**, **Localizar** e as Conferências aparecem no contexto da unidade ou do Evento
- Tags desconhecidas não interrompem **Identificar** nem a Conferência e podem abrir **Etiquetar** com o EPC já preenchido
- **Localizar** fica disponível em qualquer unidade etiquetada e não cria, por si só, uma pendência
- Unidade ausente na **Conferência de retorno** ou marcada manualmente como não localizada fica **Pendente de resolução**
- **Localizar** uma unidade **Pendente de resolução** exige confirmação humana de que ela foi encontrada e registro da localização para encerrar a pendência
- A interface de **Localizar** preserva e evolui o medidor de proximidade do app legado, agora alimentado por sinal real e adaptado ao sistema visual atual
- **Workspace Localizar** ocupa a tela inteira, mantém a ação de encontro acessível e retorna ao perfil ou à pendência de origem ao fechar
- **Workspace Localizar** responde à proximidade com sinais visual, háptico e sonoro progressivos
- Um **MVP operacional real** inclui **Dados reais** e **RFID fisico**, não apenas telas demonstráveis
- Um **MVP operacional real** exige web com auth, iOS instalado em aparelho, RFD40 pareado lendo tags reais e check-out/check-in gravando em **Dados reais**
- O primeiro **MVP operacional real** deve rodar em **Produção real pública**
- **Produção real pública** usa autenticação própria com **Equipe operacional** e **Usuário admin**
- **Equipe operacional** opera projetos, packing, check-out, check-in, condição e edição operacional do estoque
- O trabalho principal da **Equipe operacional** é preparar evento, conferir saída, conferir retorno e marcar problema
- A **Ficha de evento** é o cadastro principal do produto
- A **Ficha de evento** é preenchida quando existe **Evento fechado**
- Marcelo, **Usuário admin** ou **Equipe operacional** podem preencher a **Ficha de evento** no web
- A **Ficha de evento** cria o projeto e vira base para packing, check-out e retorno
- No web, a **Ficha de evento** é preenchimento completo
- No mobile, a **Ficha de evento** vira resumo operacional, checklist e ações de campo
- Depois da **Ficha de evento**, a **Packing list** é o próximo passo obrigatório
- A **Packing list** nasce por edição manual assistida, sugestão automática ou importação de planilha
- Importação de **Packing list** usa **Planilha padrão de packing**
- **Planilha padrão de packing** contém codigo_mmd, categoria, item, subcategoria, marca, modelo, quantidade e observacao
- Na **Planilha padrão de packing**, codigo_mmd é o match principal; os demais campos servem como fallback
- **Linha ambígua de packing** exige escolha humana antes de entrar na **Packing list**
- **Sugestão de packing** usa histórico parecido primeiro, templates salvos segundo e IA apenas como rascunho revisável
- A sugestão automática da **Packing list** nunca bloqueia ajuste manual da **Equipe operacional**
- Depois da **Packing list**, a próxima etapa é **Alocação**
- **Alocação** conecta a necessidade do evento às unidades rastreáveis específicas que sairão do estoque
- **Alocação** alerta conflitos de disponibilidade, mas não bloqueia operação automaticamente
- Falta de estoque próprio pode ser resolvida com **Aluguel avulso**
- **Aluguel avulso** entra como linha da **Packing list**, sem virar patrimônio da MMD
- **Checklist de saída** bate quando todos os itens da **Packing list** têm quantidade atendida por unidade própria ou **Aluguel avulso** resolvido
- **Equipe operacional** pode confirmar saída incompleta, registrando um motivo curto
- A **Conferência de saída** é única por Evento, salva progresso automaticamente, pode ser fechada e retomada
- A **Conferência de saída** não modela veículos nem cargas separadas
- **Check-out físico** usa a lista de unidades conferidas como fonte de verdade da saída
- **Check-out físico** usa RFID como método principal e QR Code como fallback por unidade
- Confirmação manual no **Check-out físico** exige selecionar a unidade exata, registrar motivo e identificar o método no recibo
- **Check-out físico** não permite confirmar todas as unidades nem fazer inclusão manual em massa
- Unidade alocada e não conferida não muda para EM_CAMPO
- Unidade disponível do mesmo Item substitui automaticamente o serial alocado e registra a troca
- Unidade de Item fora do packing entra em **Revisar** com as ações Adicionar e Ignorar
- Unidade indisponível, em conflito ou com tag desconhecida entra em **Revisar**
- Exceções não pausam nem cobrem a lista durante a leitura
- Confirmação incompleta pela **Equipe operacional** fica auditada, mas não cria leitura nem registra saída de unidade ausente
- Unidades restantes podem ser adicionadas depois pela mesma **Conferência de saída**
- O **Recibo operacional** do **Check-out físico** registra unidades, método de conferência, operador, horário e eventual motivo
- Toda nova superfície visual passa por um **Corte visual** com cinco opções antes de entrar na implementação final
- Marco escolhe uma opção, a próxima rodada parte apenas da base escolhida, e a superfície é travada antes de avançar
- Uma superfície travada só volta a variar quando Marco reabre explicitamente a decisão
- Backend, contratos, modelos e testes podem avançar em paralelo aos **Cortes visuais**
- Decisão técnica não pode encerrar antecipadamente uma escolha visual que ainda não foi validada
- Na **Conferência de retorno**, cada unidade própria fica como voltou OK, voltou com problema ou não voltou
- Unidade lida na **Conferência de retorno** começa como voltou OK; a **Equipe operacional** só toca nas exceções
- Marcar voltou com problema exige condição e observação curta; unidade esperada não lida vira **Pendente de resolução**
- Unidade que voltou com problema muda para manutenção e recebe observação vinculada ao evento de retorno
- Unidade que não voltou fica **Pendente de resolução**, não baixa imediata
- Marcelo resolve **Pendente de resolução**, decidindo se a unidade foi encontrada, virou manutenção, virou baixa ou gera cobrança
- Cobrança por unidade não devolvida fica apenas como observação textual no MVP
- **Dashboard consolidado** prioriza próximos eventos e prontidão, depois uso por categoria, manutenção/perdas e patrimônio
- Prontidão de evento considera ficha preenchida, packing criada, quantidade atendida e pendências de conflito ou aluguel avulso
- **Orçamento e contrato** ficam no web como registro de status, link ou anexo, sem motor financeiro ou jurídico completo
- **Orçamento e contrato** usam status: orçamento enviado, aprovado, contrato enviado e contrato assinado
- Evento pode avançar para operação de estoque quando o orçamento está aprovado, mesmo antes do contrato assinado
- **Identificação mínima da unidade** existe para permitir movimentação sem exigir cadastro patrimonial completo
- **Usuário admin** gerencia usuários, permissões e ações destrutivas como baixa, venda e exclusão
- A **Ficha pública QR** pode mostrar nome e status genérico, mas não mostra valor, serial, localização ou histórico
- A **Ficha interna** exige autenticação e pode mostrar dados completos
- A **Ficha pública QR** usa **Status público QR**, não o status operacional interno
- Em **Produção real pública**, a **Ficha pública QR** é a única área pública; todo o restante exige autenticação
- A **Ficha pública QR** permite avisar a MMD por telefone ou WhatsApp, sem formulário público
- Todo equipamento físico, incluindo cabo, deve virar **Unidade rastreável**
- **Lote legado** não é a regra operacional futura para cabos
- **Remoção de lotes** elimina todos os lotes mesmo sem conferência prévia de contagem
- **Remoção de lotes** aceita perder o vínculo histórico direto de leituras antigas que apontavam para lote
- Após **Remoção de lotes**, `/lotes` deixa de ser navegação principal e redireciona para cabos no catálogo

## Example dialogue

> **Dev:** "A **Demo Marcelo** vai mostrar **RFID fisico**?"
> **Domain expert:** "Não. A demo mostra a tela e o fluxo administrativo; **RFID fisico** só conta como pronto depois de testar com leitor e tags reais."

## Flagged ambiguities

- "processo" foi usado para três frentes diferentes. Resolvido: vamos tratar como trilhas separadas, **Demo Marcelo**, **Dados reais** e **RFID fisico**.
- "MVP completo" foi usado para significar **MVP operacional real**. Resolvido: essa frase só vale quando dados reais, acesso controlado, app em aparelho e RFID físico tiverem sido provados.
- "produção" foi usado tanto para demo pública quanto para dados reais. Resolvido: **Produção real pública** significa dados reais com autenticação própria.
- "viewer/editor/admin" foi resolvido no produto como dois perfis humanos: **Equipe operacional** e **Usuário admin**.
- "job" foi evitado como termo canônico. Resolvido: usar **Evento fechado**.
- "cadastro" foi resolvido como **Ficha de evento** quando usado sem complemento. Cadastro de equipamento deve ser chamado de **Identificação mínima da unidade** ou ficha interna, conforme o caso.
- "lote de cabo" conflitou entre documentação antiga e código novo. Resolvido: cabos novos devem ser **Unidade rastreável**; lotes existentes são **Lote legado**.
- "apagar lote" foi resolvido como **Remoção de lotes**, não apenas esconder da operação ou arquivar.
- "etiquetar" foi resolvido como **Etiquetar**, a gestão auditável da associação entre EPC existente e unidade rastreável, sem programação física da memória da tag.
- "todo o manuseio RFID" foi resolvido como **Operação RFID**, cobrindo a rotina operacional completa no app e excluindo manutenção técnica do leitor.
- "item perdido" foi separado em **Localizar**, a ação de busca, e **Pendente de resolução**, o estado operacional que precisa de decisão humana.
- "check-out" foi resolvido como **Check-out físico**, cuja fonte de verdade são as unidades realmente conferidas e não toda a alocação presumida.
- "erro de leitura" foi agrupado em **Revisar**, uma única camada de exceções que não interrompe o scanner.
- "sucesso" de uma escrita foi resolvido como **Recibo operacional**, persistido apenas depois da confirmação do backend.
- "cinco opções" foi resolvido como **Corte visual**, um gate iterativo e sequencial de validação para cada nova superfície.

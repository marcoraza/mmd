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
- **Usuário admin** pode forçar saída com **Checklist de saída** incompleto, registrando motivo
- Na **Conferência de retorno**, cada unidade própria fica como voltou OK, voltou com problema ou não voltou
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

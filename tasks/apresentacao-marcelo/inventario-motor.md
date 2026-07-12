# Inventário do Motor MMD Estoque Inteligente

Fonte de verdade factual para a apresentação ao Marcelo. Levantado em 2026-06-23 a partir do banco Supabase ao vivo (`bphmxticdyuctovfumcj`, Postgres 17), das migrations em `supabase/migrations/`, do app web (`apps/web`) e do app iOS (`apps/ios`).

Marcação: `OBSERVADO` = lido direto da fonte. `INFERIDO` = leitura que segue dos fatos.

---

## 1. Números reais do banco (OBSERVADO, ao vivo)

| Tabela | Linhas | O que é |
|---|---|---|
| items | 539 | Tipos de equipamento (o "modelo", ex: refletor LED Par X) |
| serial_numbers | 1058 | Unidades físicas individuais, cada uma rastreável |
| projetos | 11 | Eventos cadastrados |
| packing_list | 65 | Linhas de alocação (item reservado pra um evento) |
| movimentacoes | 2 | Histórico de saída/retorno registrado |
| lotes | 152 | Legado (cabos em bloco, em descontinuação) |
| packing_templates | 0 | Modelos de packing salvos |
| rfid_readers | 0 | Leitores RFID registrados |
| rfid_scans | 0 | Leituras RFID registradas |
| checkout_overrides | 0 | Saídas forçadas por admin (auditoria) |
| retorno_pendencias | 0 | Itens que não voltaram (em aberto) |
| profiles | 1 | Usuário cadastrado |

### Catálogo por categoria (539 tipos)
AUDIO 205, ILUMINACAO 195, ACESSORIO 32, ESTRUTURA 26, EFEITO 23, CABO 20, ENERGIA 20, VIDEO 18.

### Situação das 1058 unidades físicas
DISPONIVEL 1049, EMPRESTADO 4, VENDIDO 3, BAIXA 2. Nenhuma em campo ou manutenção agora.

### Status dos 11 eventos
CONFIRMADO 4, PLANEJAMENTO 3, FINALIZADO 2, EM_CAMPO 1, CANCELADO 1.

### Cobertura de etiquetagem
- 539 de 539 tipos com código interno MMD (100% catalogado).
- 530 de 1058 unidades já com QR Code gerado (~50% do parque).
- 0 de 1058 unidades com tag RFID vinculada.

INFERIDO: o inventário está digitalizado e organizado (catálogo 100%, metade já com QR). RFID ainda não foi vinculado a nenhuma unidade nem rodou em campo (readers, scans e tags em zero). O loop de saída/retorno foi exercitado pouco (2 movimentações). Esse é o estado honesto: base sólida montada, operação ao vivo ainda por ativar.

---

## 2. Modelo de dados central (o vocabulário)

Espelha a linguagem de locação AV: **Item** (tipo) + **Serial Number** (unidade física).

- **Item**: o modelo. Tem nome, categoria, marca, modelo, valor de mercado, código interno `MMD-{CAT}-{0001}`.
- **Serial Number**: a peça real na prateleira. Tem código interno único, número de série de fábrica, tag RFID, QR Code, status, estado, desgaste, valor atual, localização.
- **Projeto** (Evento): o trabalho. Tem cliente, datas, local, status, ficha operacional, dados comerciais leves.
- **Packing List**: o que cada evento leva. Liga item + quantidade + seriais designados.
- **Movimentação**: o registro de cada transição (saída, retorno, manutenção, transferência, dano).
- **Lote**: legado. Cabos em bloco. Não volta como regra operacional.

### Categorias (8) e prefixos
ILUMINACAO (ILU), AUDIO (AUD), CABO (CAB), ENERGIA (ENE), ESTRUTURA (EST), EFEITO (EFE), VIDEO (VID), ACESSORIO (ACE).

### Status de uma unidade (serial_numbers)
DISPONIVEL, PACKED, EM_CAMPO, RETORNANDO, MANUTENCAO, EMPRESTADO, VENDIDO, BAIXA.

### Status de um evento (projetos)
PLANEJAMENTO, CONFIRMADO, EM_CAMPO, FINALIZADO, CANCELADO.

---

## 3. Sistema de condição e valor (3 dimensões)

Cada unidade carrega três medidas que juntas dizem quanto ela vale hoje.

1. **Estado** (ciclo de vida): NOVO (fator 1.00), SEMI_NOVO (0.85), USADO (0.65), RECONDICIONADO (0.50).
2. **Desgaste** (condição física, 1 a 5): 5 excelente, 4 bom, 3 regular, 2 desgastado, 1 crítico.
3. **Depreciação** (valor atual): `valor original × (desgaste / 5) × fator do estado`.

INFERIDO: isso transforma "tenho um monte de equipamento" em "sei quanto vale meu patrimônio hoje, peça por peça", sem reavaliação manual.

---

## 4. O loop operacional (o coração do motor)

Fluxo central: **ALOCAR → CHECK-OUT → (campo) → CHECK-IN → resolver pendência**.

### Alocar
Monta o packing do evento. Adiciona item + quantidade, designa seriais específicos.
- Auto-alocação com rotação justa: prioriza quem ficou mais tempo parado (`last_moved_at` ASC), depois menor desgaste. Distribui o uso pelo parque em vez de gastar sempre as mesmas peças.
- Detecção de conflito: avisa se a mesma unidade está reservada em dois eventos com datas sobrepostas.
- Cobertura: soma unidades próprias + aluguel avulso de terceiros, calcula prontidão (readiness) em %.

### Check-out (saída)
Antes de liberar, passa por um **gate de prontidão**:
- Bloqueios duros: evento não confirmado, packing vazio, item com 0% de cobertura.
- Avisos: ficha do evento incompleta, cobertura parcial, conflito de datas.
- Override de admin: dono pode forçar a saída com motivo, e isso fica registrado em auditoria (`checkout_overrides`).
- Execução: uma transação atômica no banco (RPC `checkout_projeto` ou `checkout_projeto_com_override`) marca todas as unidades como EM_CAMPO e grava a movimentação de SAIDA. Tudo ou nada, sem meio-termo que deixe estoque inconsistente.

### Check-in (retorno e conferência)
Na volta, unidade por unidade: novo desgaste (1 a 5) + resultado.
- OK volta pra DISPONIVEL.
- PROBLEMA vai pra MANUTENCAO.
- NAO_VOLTOU vira RETORNANDO e abre uma pendência.
- Execução atômica (RPC `checkin_projeto`): atualiza status, grava movimentação de RETORNO, abre pendências.

### Resolver pendência (quando algo não volta)
Só admin. Para cada item em aberto: ENCONTRADA (volta ao estoque), MANUTENCAO, BAIXA, ou COBRANCA (cobra do cliente). RPC `resolver_retorno_pendencia`.

INFERIDO: o motor garante que nada "some no escuro". Toda peça que sai tem destino registrado, e o que não volta entra numa fila de resolução com responsável.

---

## 5. RPCs (as operações atômicas no banco)

Seis funções expostas. As quatro primeiras são o loop:

| RPC | O que faz |
|---|---|
| checkout_projeto | Saída atômica: unidades para EM_CAMPO + movimentação SAIDA |
| checkout_projeto_com_override | Saída forçada por admin, com registro de auditoria |
| checkin_projeto | Retorno atômico: status, desgaste, movimentação, pendências |
| resolver_retorno_pendencia | Fecha item que não voltou (admin) |
| current_user_role | Retorna o papel do usuário (movida pra schema privado) |
| item_categoria_prefix | Gera o prefixo de categoria do código interno |

---

## 6. Motor web (gestão, escritório)

Next.js 16 (App Router, React 19, React Compiler), Tailwind v4, design system próprio Liquid Glass 2030. Deploy Vercel.

- **Camada de dados** (`src/lib/data/`): leitura. Catálogo, unidades, dashboard, eventos, movimentações, RFID, QR. Roda no servidor com chave de serviço.
- **Camada de ações** (`src/lib/actions/`): mutação. Checkout, checkin, alocação, criação de evento, ficha, comercial, import de packing por planilha, vínculo de RFID. Cada ação valida papel do usuário antes de tocar o banco.
- **Núcleo de regras** (`src/lib/*-core.ts`): lógica pura e testável separada do banco. Gate de checkout, ordenação de alocação, conferência de retorno, depreciação, nomenclatura, label de item.
- **Tempo real**: o app escuta mudanças no banco por websocket (postgres_changes) e atualiza a tela sozinho. Dois operadores veem o mesmo estado sem recarregar.
- **API** (`src/app/api/`): rotas que o app iOS consome (checkout, retorno, resumo de evento, folha de QR).

---

## 7. Motor iOS (campo, galpão)

Swift/SwiftUI. Consome a mesma fronteira do web, não cria regra paralela.

- **APIClient**: chama as rotas da web (`POST /api/eventos/{id}/checkout` e `/retorno`) e o Supabase pra resolver tags/QR. Mesma autenticação.
- **RFIDManager**: fachada que esconde o hardware da tela. O app já está preparado para receber leituras do RFD40 via SDK da Zebra.
  - MockRFIDManager: simulador completo e funcional (leitores fake, tags SGTIN-96 realistas, descoberta, taxa de falha). Permite demonstrar o fluxo sem o leitor físico.
  - Integração com o SDK da Zebra: o caminho do RFD40 real está montado, com fallback automático pro simulador se o SDK não estiver presente, sem quebrar.
- **CheckoutViewModel / ReturnViewModel**: o fluxo de campo. Escaneia (RFID ou QR), resolve a peça no banco, confere contra o packing, finaliza pela API.
- **Production gate**: checklist interno que valida build assinado, iPhone real, RFD40 pareado, tags reais lidas e fallback QR testado antes de liberar como produção.

INFERIDO: o app de campo está com a lógica pronta e o fluxo RFID integrado de ponta a ponta no software. O que falta é a prova com hardware real no ambiente da MMD (ver seção 9).

---

## 8. Segurança e auditoria

- **RLS** (Row Level Security) ligada em todas as tabelas. Em produção, usuário anônimo não escreve.
- **Papéis**: viewer (lê), editor (opera o dia a dia), admin (apaga, força saída, resolve pendência).
- A função de papel foi movida pra um schema privado (`app_private`), fora da API pública, pra não vazar como endpoint.
- **QR público é mínimo**: não mostra valor, número de série de fábrica, RFID, localização nem histórico.
- **Trilha de auditoria**: toda saída forçada, movimentação e pendência fica registrada com quem fez e quando.

---

## 9. Integração RFID (software pronto, prova de campo pendente)

Foi feita a integração de software entre o app do iPhone, o SDK da Zebra e o sistema da MMD. A integração foi pensada no fluxo inteiro, não só no leitor: tag lida pelo RFD40, recebida no iPhone, enviada para o sistema e registrada no histórico.

O que o software já faz:
- O app já está preparado para receber leituras do RFD40.
- O sistema já consegue gravar essas leituras como histórico RFID.
- Quando uma tag já está cadastrada, o sistema associa a leitura ao equipamento correto.
- Quando uma tag ainda não está cadastrada, o sistema não descarta a leitura: registra como tag desconhecida para tratar depois.

OBSERVADO no banco: hoje há 0 tags vinculadas e 0 leituras registradas. Isso é coerente com o estágio, a etiquetagem física e a prova de campo ainda não começaram. O software trata os dois casos (tag conhecida e desconhecida), só não rodou com hardware real ainda.

O que falta: validar o comportamento real no galpão da MMD, com leitor físico, iPhone e tags reais. Pontos a confirmar: pareamento, distância de leitura, velocidade, estabilidade e leitura em equipamentos reais.

### Plano da próxima etapa (teste controlado, 10 a 20 equipamentos etiquetados)
1. Bancada: leitura simples e próxima, confirmar o fluxo básico.
2. Galpão: equipamentos no ambiente real, distância e estabilidade.
3. Fluxo real pequeno: usar o leitor num inventário, numa saída para evento ou num retorno.

O objetivo do teste não é implantar em tudo de uma vez. É confirmar que o fluxo funciona de ponta a ponta e descobrir os ajustes finos antes de escalar para o inventário completo.

Para o teste precisamos de: RFD40, iPhone, acesso ao app, tags RFID reais e alguns equipamentos separados.

Status correto hoje: software RFID pronto para prova física. O que ainda não dá pra dizer: RFID validado em campo.

## 9b. Resto do estado (pronto vs por ativar)

PRONTO:
- Banco completo, populado com inventário real (539 tipos, 1058 unidades), 100% catalogado.
- Loop operacional implementado de ponta a ponta no banco (RPCs atômicas) e no web.
- Gate de prontidão, alocação justa, conferência de retorno, fila de pendências, auditoria.
- App de campo com fluxo completo, RFID integrado no software, demonstrável no simulador.
- Metade do parque já com QR Code.

POR ATIVAR:
- Prova de campo do RFID e início da etiquetagem física (ver seção 9).
- Exercitar o loop em produção com volume (2 movimentações até agora).
- Cadastro de usuários e papéis em uso real (1 profile hoje).

---

## 10. Tese de uma frase

INFERIDO: o sistema substitui a planilha por um motor que sabe, peça por peça, o que a MMD tem, quanto vale, onde está e pra onde vai, com cada saída e retorno registrados e nada sumindo no escuro.

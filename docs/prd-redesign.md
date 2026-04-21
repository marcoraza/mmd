# PRD: MMD Estoque Inteligente — Redesign Completo

## Produto

Sistema de gestao de estoque para empresa de locacao de equipamentos AV/eventos. Controle patrimonial, rastreamento por RFID/QR Code, checkout/retorno de projetos, depreciacao automatica.

Usuarios: gestor (web, desktop/tablet) e operador de campo (iOS, mobile).
Este PRD cobre apenas a interface web (gestao).

---

## Navegacao Global

### Sidebar (desktop)

Sidebar fixa com:

- **Marca:** "MMD ESTOQUE" com indicador visual de status
- **Metrica hero:** Valor total atual do patrimonio, com variacao percentual (depreciacao)
- **4 mini-widgets:**
  - Total de equipamentos
  - Disponiveis
  - Em campo
  - Desgaste medio (barra segmentada 1-5)
- **Menu de navegacao (6 itens):**
  - Dashboard
  - Inventario
  - Lotes
  - Projetos
  - Movimentacoes
  - Configuracoes
- **Indicador ativo** no item de menu atual
- **Icone de notificacoes** com contador de alertas pendentes
- **Versao do sistema** no footer

### Bottom Nav (mobile)

Barra fixa inferior com os mesmos 6 itens de navegacao, icone + label.
Indicador visual no item ativo.

### Page Header

Toda pagina tem header com:
- Titulo da pagina
- Subtitulo contextual (ex: contagem de itens, nome do projeto)
- Slot de acao (botao primario da pagina)

---

## 1. Dashboard

**Rota:** `/`
**Proposito:** Visao geral instantanea do patrimonio, saude dos equipamentos, atividade recente.

### KPIs Primarios (4 metricas)

| Metrica | Origem | Formato |
|---------|--------|---------|
| Valor Original Total | soma(items.valor_mercado_unitario x items.quantidade_total) | Currency R$ |
| Valor Atual Total | soma(serial_numbers.valor_atual) | Currency R$ |
| Taxa de Depreciacao | (original - atual) / original x 100 | Percentual com gauge circular |
| Equipamentos Criticos | count(serial_numbers onde desgaste <= 2) | Numero com label "DESGASTE <= 2" |

### KPIs Secundarios (4 metricas)

| Metrica | Origem |
|---------|--------|
| Total de Equipamentos | count(serial_numbers) |
| Disponiveis | count(serial_numbers onde status = DISPONIVEL) |
| Em Manutencao | count(serial_numbers onde status = MANUTENCAO) |
| Total de Lotes | count(lotes) |

### Valor por Categoria (grafico de barras)

Uma barra por categoria (8 categorias: ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO).
Valor: soma de valor_mercado_unitario dos serial_numbers agrupados por items.categoria.

### Distribuicao de Status (barras horizontais)

Uma barra horizontal por status (DISPONIVEL, PACKED, EM_CAMPO, MANUTENCAO, INATIVO).
Mostra: label, contagem, barra proporcional ao total.

### Atividade Recente (feed)

Ultimas 10 movimentacoes.
Cada entrada mostra:
- Tipo da movimentacao (SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA, DANO)
- Nome do equipamento ou codigo interno
- Quem registrou (registrado_por)
- Metodo de scan (RFID, QRCODE, MANUAL)
- Timestamp formatado

### Top Categorias por Valor (ranking)

Categorias ordenadas por valor total descendente.
Mostra: nome da categoria, barra proporcional, valor total formatado.

### Desgaste por Categoria (barras segmentadas)

Para cada categoria: barra segmentada de 5 blocos mostrando media de desgaste, com valor numerico.

### Itens Criticos (tabela compacta)

Top 10 equipamentos com menor desgaste.
Campos: codigo interno, nome do item, categoria, desgaste (1-5), valor atual.

### Top 10 Mais Valiosos (tabela)

10 equipamentos de maior valor atual.
Campos: posicao, nome do item (+ codigo interno), categoria, valor original unitario, desgaste (barra), valor atual.

### Perda Patrimonial por Categoria (tabela)

Para cada categoria:
- Valor original total
- Valor atual total
- Perda em R$ (original - atual)
- Percentual de depreciacao

Ordenado por perda descendente.

### Projetos Ativos (cards)

Projetos com status CONFIRMADO ou EM_CAMPO.
Cada card: nome do projeto, cliente, data inicio/fim, local, quantidade de itens alocados, progresso (itens despachados / total packing list).

---

## 2. Inventario

### 2.1 Lista de Itens

**Rota:** `/items`

**Funcionalidades:**
- Busca textual por nome, marca, modelo
- Filtro por categoria (chips multi-selecao, 8 categorias)
- Filtro por status predominante (DISPONIVEL, EM_CAMPO, MANUTENCAO)
- Ordenacao por qualquer coluna (click no header, toggle asc/desc)
- Paginacao (20 itens por pagina)
- Botao "Novo Item" que leva ao formulario de criacao
- Responsive: tabela no desktop, cards no mobile

**Campos da tabela:**

| Campo | Origem | Interacao |
|-------|--------|-----------|
| Nome | items.nome | Link para detalhe |
| Categoria | items.categoria | Badge |
| Subcategoria | items.subcategoria | Texto secundario |
| Marca | items.marca | Texto |
| Modelo | items.modelo | Texto |
| Tipo Rastreamento | items.tipo_rastreamento | Badge (INDIVIDUAL, LOTE, BULK) |
| Quantidade Total | items.quantidade_total | Numero |
| Disponiveis | count(serial_numbers onde status=DISPONIVEL) | Numero verde |
| Valor Unitario | items.valor_mercado_unitario | Currency |
| Foto | items.foto_url | Thumbnail ou placeholder |

**Campos do card mobile:** nome, categoria (badge), subcategoria, marca + modelo, quantidade, disponiveis, valor unitario.

### 2.2 Detalhe do Item

**Rota:** `/items/[id]`

**Header do item:**
- Nome (titulo principal)
- Marca e modelo (subtitulo)
- Categoria (badge)
- Subcategoria
- Tipo de rastreamento (badge)
- Foto do item (items.foto_url) ou placeholder
- Notas do item (items.notas), exibido se preenchido

**Metricas do item:**

| Metrica | Origem |
|---------|--------|
| Quantidade Total | items.quantidade_total |
| Disponiveis | count(serials onde status=DISPONIVEL) |
| Em Campo | count(serials onde status=EM_CAMPO) |
| Em Manutencao | count(serials onde status=MANUTENCAO) |
| Valor Unitario | items.valor_mercado_unitario |
| Valor Total Atual | soma(serial_numbers.valor_atual) |
| Desgaste Medio | avg(serial_numbers.desgaste) |
| Depreciacao Media | avg(serial_numbers.depreciacao_pct) |

**Acoes do item:**
- Editar (navega para form de edicao)
- Excluir (confirmacao, impede se tem serials associados com status != DISPONIVEL)

#### Tabela de Serial Numbers

Lista todos os serial numbers vinculados ao item.

| Campo | Origem | Editavel? |
|-------|--------|-----------|
| Codigo Interno | serial_numbers.codigo_interno | Nao (gerado) |
| Serial de Fabrica | serial_numbers.serial_fabrica | Sim (criacao e edicao) |
| Status | serial_numbers.status | Sim (select: DISPONIVEL, PACKED, EM_CAMPO, MANUTENCAO, INATIVO) |
| Estado | serial_numbers.estado | Sim (select: NOVO, SEMI_NOVO, USADO, RECONDICIONADO) |
| Desgaste | serial_numbers.desgaste | Sim (1-5) |
| Depreciacao % | serial_numbers.depreciacao_pct | Exibido (calculado automaticamente) |
| Valor Atual | serial_numbers.valor_atual | Exibido (calculado: valor_mercado x desgaste/5 x fator_estado) |
| Tag RFID | serial_numbers.tag_rfid | Sim |
| QR Code | serial_numbers.qr_code | Sim |
| Localizacao | serial_numbers.localizacao | Sim |
| Notas | serial_numbers.notas | Sim |

**Acoes por serial:**
- Editar inline (abre form com campos editaveis)
- Excluir (somente se status = DISPONIVEL, com confirmacao)
- Adicionar novo serial (form inline, codigo gerado automaticamente no padrao MMD-{CAT}-{NNNN})

#### Historico de Movimentacoes

Lista cronologica de todas as movimentacoes dos serials deste item.

| Campo | Origem |
|-------|--------|
| Tipo | movimentacoes.tipo (SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA, DANO) |
| Codigo do Serial | serial_numbers.codigo_interno |
| Status Anterior | movimentacoes.status_anterior |
| Status Novo | movimentacoes.status_novo |
| Projeto | projetos.nome (via movimentacoes.projeto_id) |
| Registrado Por | movimentacoes.registrado_por |
| Metodo de Scan | movimentacoes.metodo_scan (RFID, QRCODE, MANUAL) |
| Notas | movimentacoes.notas |
| Data/Hora | movimentacoes.timestamp |

### 2.3 Formulario de Item (criar e editar)

**Rotas:** `/items/new` e `/items/[id]/edit`

| Campo | Tipo | Obrigatorio |
|-------|------|-------------|
| Nome | text | Sim |
| Categoria | select (8 opcoes) | Sim |
| Subcategoria | text | Nao |
| Marca | text | Nao |
| Modelo | text | Nao |
| Tipo de Rastreamento | select (INDIVIDUAL, LOTE, BULK) | Sim |
| Quantidade Total | number (min 1) | Sim |
| Valor de Mercado Unitario | currency (R$) | Nao |
| Foto | upload de imagem (salva em Supabase Storage, grava URL em items.foto_url) | Nao |
| Notas | textarea | Nao |

**Acoes:** Salvar (criar ou atualizar) + Cancelar (volta).

---

## 3. Lotes

**Rota:** `/lotes`
**Proposito:** Gerenciar agrupamentos de equipamentos genericos (cabos, acessorios) rastreados por lote.

### Lista de Lotes

**Funcionalidades:**
- Busca por codigo do lote ou descricao
- Filtro por status (DISPONIVEL, EM_CAMPO, MANUTENCAO)
- Botao "Novo Lote"

**Campos da tabela:**

| Campo | Origem |
|-------|--------|
| Codigo do Lote | lotes.codigo_lote |
| Item Vinculado | items.nome (via lotes.item_id) |
| Categoria | items.categoria (badge) |
| Subcategoria | items.subcategoria |
| Descricao | lotes.descricao |
| Quantidade | lotes.quantidade |
| Status | lotes.status (badge) |
| Tag RFID | lotes.tag_rfid |
| QR Code | lotes.qr_code |

**Acoes por lote:**
- Editar (form inline)
- Excluir (com confirmacao)

### Formulario de Lote (criar e editar)

| Campo | Tipo | Obrigatorio | Editavel apos criacao? |
|-------|------|-------------|------------------------|
| Item | select (todos os items) | Sim | Nao |
| Codigo do Lote | text | Sim | Nao |
| Descricao | text | Nao | Sim |
| Quantidade | number (min 1) | Nao | Sim |
| Status | select (DISPONIVEL, EM_CAMPO, MANUTENCAO) | Nao | Sim |
| Tag RFID | text | Nao | Sim |
| QR Code | text | Nao | Sim |

---

## 4. Projetos

**Rota:** `/projetos`
**Proposito:** Gerenciar projetos/eventos, controlar alocacao de equipamentos e despacho.

### 4.1 Lista de Projetos

**Funcionalidades:**
- Busca por nome ou cliente
- Filtro por status (chips: PLANEJAMENTO, CONFIRMADO, EM_CAMPO, FINALIZADO, CANCELADO)
- Ordenacao por data de inicio (padrao: proximos primeiro)
- Botao "Novo Projeto"

**Campos da tabela/cards:**

| Campo | Origem |
|-------|--------|
| Nome | projetos.nome |
| Cliente | projetos.cliente |
| Data Inicio | projetos.data_inicio |
| Data Fim | projetos.data_fim |
| Local | projetos.local |
| Status | projetos.status (badge) |
| Itens Alocados | count(packing_list onde projeto_id) |
| Progresso | itens despachados / total packing list (barra ou percentual) |
| Notas | projetos.notas |

**Acoes por projeto:**
- Abrir detalhe
- Editar
- Cancelar (muda status para CANCELADO, com confirmacao)

### 4.2 Detalhe do Projeto

**Rota:** `/projetos/[id]`

**Header:**
- Nome do projeto
- Cliente
- Status (badge)
- Data inicio ate data fim
- Local
- Notas

**Metricas:**

| Metrica | Calculo |
|---------|---------|
| Total de Itens | soma(packing_list.quantidade) |
| Serials Designados | count(packing_list.serial_numbers_designados onde nao vazio) |
| Itens Despachados | count(movimentacoes.tipo=SAIDA onde projeto_id=este) |
| Itens Retornados | count(movimentacoes.tipo=RETORNO onde projeto_id=este) |
| Pendentes | despachados - retornados |

**Acoes do projeto:**
- Editar projeto
- Mudar status (transicao: PLANEJAMENTO -> CONFIRMADO -> EM_CAMPO -> FINALIZADO)
- Cancelar projeto

#### Packing List (editor principal)

Tabela editavel dos equipamentos alocados para o projeto.

| Campo | Origem |
|-------|--------|
| Item | items.nome (via packing_list.item_id) |
| Categoria | items.categoria |
| Quantidade Solicitada | packing_list.quantidade |
| Serials Designados | packing_list.serial_numbers_designados (lista de codigos internos) |
| Notas | packing_list.notas |

**Acoes do packing list:**
- Adicionar item ao packing list (select de items + quantidade)
- Remover item do packing list
- Designar serials especificos (selecionar dentre os DISPONIVEIS do item)
- Limpar designacao

#### Checkout (despacho de equipamentos)

Funcionalidade para registrar saida de equipamentos do projeto.

- Selecionar serials do packing list para despacho
- Ou escanear via codigo (simula input de RFID/QR)
- Ao confirmar checkout:
  - Cria movimentacao tipo SAIDA para cada serial
  - Atualiza serial_numbers.status para EM_CAMPO
  - Registra projeto_id, registrado_por, metodo_scan na movimentacao
  - Atualiza progresso do packing list

#### Retorno (recebimento de volta)

Funcionalidade para registrar retorno de equipamentos.

- Listar serials EM_CAMPO deste projeto
- Selecionar ou escanear serials que estao retornando
- Para cada serial retornado, permitir:
  - Atualizar desgaste (1-5)
  - Registrar dano (se houver)
  - Adicionar notas
- Ao confirmar retorno:
  - Cria movimentacao tipo RETORNO para cada serial
  - Atualiza serial_numbers.status para DISPONIVEL (ou MANUTENCAO se dano)
  - Atualiza desgaste e notas conforme informado

### 4.3 Formulario de Projeto (criar e editar)

| Campo | Tipo | Obrigatorio |
|-------|------|-------------|
| Nome | text | Sim |
| Cliente | text | Nao |
| Data Inicio | date | Nao |
| Data Fim | date | Nao |
| Local | text | Nao |
| Status | select (PLANEJAMENTO, CONFIRMADO, EM_CAMPO, FINALIZADO, CANCELADO) | Sim |
| Notas | textarea | Nao |

---

## 5. Movimentacoes

**Rota:** `/movimentacoes`
**Proposito:** Registro completo e timeline de todas as movimentacoes de equipamentos.

### Lista de Movimentacoes

**Funcionalidades:**
- Busca por codigo do serial ou nome do item
- Filtro por tipo (SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA, DANO)
- Filtro por periodo (date range)
- Filtro por projeto
- Filtro por metodo de scan (RFID, QRCODE, MANUAL)
- Ordenacao por timestamp (desc padrao)
- Paginacao

**Campos da tabela:**

| Campo | Origem |
|-------|--------|
| Tipo | movimentacoes.tipo (badge colorido) |
| Equipamento | serial_numbers.codigo_interno + items.nome |
| Projeto | projetos.nome (via movimentacoes.projeto_id) |
| Status Anterior | movimentacoes.status_anterior |
| Status Novo | movimentacoes.status_novo |
| Registrado Por | movimentacoes.registrado_por |
| Metodo | movimentacoes.metodo_scan (RFID, QRCODE, MANUAL) |
| Notas | movimentacoes.notas |
| Data/Hora | movimentacoes.timestamp |

### Registrar Movimentacao Manual

Botao "Nova Movimentacao" que abre formulario:

| Campo | Tipo | Obrigatorio |
|-------|------|-------------|
| Tipo | select (SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA, DANO) | Sim |
| Serial Number | search/select (busca por codigo interno) | Sim |
| Projeto | select (projetos ativos) | Nao (obrigatorio se SAIDA ou RETORNO) |
| Notas | textarea | Nao |

Ao salvar:
- Cria registro em movimentacoes com status_anterior (status atual do serial), status_novo (derivado do tipo), registrado_por ("web"), metodo_scan ("MANUAL")
- Atualiza serial_numbers.status conforme o tipo

---

## 6. Configuracoes

**Rota:** `/config`

### Informacoes do Sistema (somente leitura)
- Versao
- Stack tecnologico
- URL do banco de dados
- Status da conexao com Supabase

### Preferencias (editavel)
- Itens por pagina (20, 50, 100)
- Formato de moeda (R$ ou USD)
- Timezone para exibicao de timestamps

### Dados
- Botao "Exportar Inventario" (gera CSV com todos os items + serial_numbers)
- Botao "Exportar Movimentacoes" (gera CSV com historico completo)
- Contagem de registros por tabela (items, serial_numbers, lotes, projetos, movimentacoes)

---

## Enums e Opcoes

### Categorias (8)
ILUMINACAO, AUDIO, CABO, ENERGIA, ESTRUTURA, EFEITO, VIDEO, ACESSORIO

### Status de Serial Number (5)
DISPONIVEL, PACKED, EM_CAMPO, MANUTENCAO, INATIVO

### Status de Lote (3)
DISPONIVEL, EM_CAMPO, MANUTENCAO

### Estado do Equipamento (4)
NOVO, SEMI_NOVO, USADO, RECONDICIONADO

### Desgaste (escala 1-5)
5=Excelente, 4=Bom, 3=Regular, 2=Desgastado, 1=Critico

### Status de Projeto (5)
PLANEJAMENTO, CONFIRMADO, EM_CAMPO, FINALIZADO, CANCELADO

### Tipo de Movimentacao (5)
SAIDA, RETORNO, MANUTENCAO, TRANSFERENCIA, DANO

### Tipo de Rastreamento (3)
INDIVIDUAL, LOTE, BULK

### Metodo de Scan (3)
RFID, QRCODE, MANUAL

---

## Modelo de Dados (6 tabelas)

### items
id, nome, categoria, subcategoria, marca, modelo, tipo_rastreamento, quantidade_total, valor_mercado_unitario, foto_url, notas, created_at, updated_at

### serial_numbers
id, item_id (FK items), codigo_interno, serial_fabrica, tag_rfid, qr_code, status, estado, desgaste, depreciacao_pct, valor_atual, localizacao, notas, created_at, updated_at

### lotes
id, item_id (FK items), codigo_lote, descricao, quantidade, tag_rfid, qr_code, status, created_at, updated_at

### projetos
id, nome, cliente, data_inicio, data_fim, local, status, notas, created_at, updated_at

### packing_list
id, projeto_id (FK projetos), item_id (FK items), quantidade, serial_numbers_designados (uuid[]), notas

### movimentacoes
id, serial_number_id (FK serial_numbers), projeto_id (FK projetos), tipo, status_anterior, status_novo, registrado_por, metodo_scan, timestamp, notas

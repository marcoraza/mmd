export type Categoria =
  | 'ILUMINACAO'
  | 'AUDIO'
  | 'CABO'
  | 'ENERGIA'
  | 'ESTRUTURA'
  | 'EFEITO'
  | 'VIDEO'
  | 'ACESSORIO'

export type TipoRastreamento = 'INDIVIDUAL' | 'LOTE' | 'BULK'

export type StatusSerial =
  | 'DISPONIVEL'
  | 'PACKED'
  | 'EM_CAMPO'
  | 'RETORNANDO'
  | 'MANUTENCAO'
  | 'EMPRESTADO'
  | 'VENDIDO'
  | 'BAIXA'

export type Estado = 'NOVO' | 'SEMI_NOVO' | 'USADO' | 'RECONDICIONADO'

export type StatusProjeto =
  | 'PLANEJAMENTO'
  | 'CONFIRMADO'
  | 'EM_CAMPO'
  | 'FINALIZADO'
  | 'CANCELADO'

export type TipoMovimentacao = 'SAIDA' | 'RETORNO' | 'MANUTENCAO' | 'TRANSFERENCIA' | 'DANO'

export type MetodoScan = 'RFID' | 'QRCODE' | 'MANUAL'

export type StatusLote = 'DISPONIVEL' | 'EM_CAMPO' | 'MANUTENCAO'

export interface Item {
  id: string
  nome: string
  categoria: Categoria
  subcategoria?: string
  marca?: string
  modelo?: string
  tipo_rastreamento: TipoRastreamento
  quantidade_total: number
  valor_mercado_unitario?: number
  foto_url?: string
  notas?: string
  created_at: string
  updated_at: string
  serial_numbers?: SerialNumber[]
}

export interface SerialNumber {
  id: string
  item_id: string
  codigo_interno: string
  serial_fabrica?: string
  tag_rfid?: string
  qr_code?: string
  status: StatusSerial
  estado: Estado
  desgaste: number
  depreciacao_pct?: number
  valor_atual?: number
  localizacao?: string
  notas?: string
  created_at: string
  updated_at: string
  item?: Item
}

export interface Projeto {
  id: string
  nome: string
  cliente?: string
  data_inicio?: string
  data_fim?: string
  local?: string
  status: StatusProjeto
  notas?: string
  created_at: string
  updated_at: string
}

export interface PackingList {
  id: string
  projeto_id: string
  item_id: string
  quantidade: number
  serial_numbers_designados?: string[]
  notas?: string
}

export interface Movimentacao {
  id: string
  serial_number_id: string
  projeto_id?: string
  tipo: TipoMovimentacao
  status_anterior?: string
  status_novo?: string
  registrado_por?: string
  metodo_scan?: MetodoScan
  timestamp: string
  notas?: string
}

export interface Lote {
  id: string
  item_id: string
  codigo_lote: string
  descricao?: string
  quantidade: number
  tag_rfid?: string
  qr_code?: string
  status: StatusLote
  created_at: string
  updated_at: string
  item?: Item
}

// Dashboard aggregations
export interface DashboardStats {
  valorOriginal: number
  valorAtual: number
  taxaDepreciacao: number
  totalItens: number
  itensSemValor: number
  disponiveis: number
  emCampo: number
  desgasteMedio: number
  depreciacaoTotal: number
}

export interface CategoriaStats {
  categoria: Categoria
  count: number
  valor: number
  desgaste_medio: number
}

export interface StatusStats {
  status: StatusSerial
  count: number
}

export interface ItemCritico {
  codigo_interno: string
  nome: string
  categoria: Categoria
  desgaste: number
  valor_atual?: number
}

export type CreateItem = Omit<Item, 'id' | 'created_at' | 'updated_at' | 'serial_numbers'>
export type UpdateItem = Partial<CreateItem>

export type CreateSerialNumber = Omit<SerialNumber, 'id' | 'created_at' | 'updated_at' | 'item'>
export type UpdateSerialNumber = Partial<Omit<CreateSerialNumber, 'item_id' | 'codigo_interno'>>

export type CreateLote = Omit<Lote, 'id' | 'created_at' | 'updated_at' | 'item'>
export type UpdateLote = Partial<Omit<CreateLote, 'item_id'>>

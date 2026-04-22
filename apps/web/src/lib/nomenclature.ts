import type { Categoria } from '@/lib/types'
import { CATEGORIA_LABEL } from '@/components/catalog/helpers'

// Dicionario de tradução subcategoria -> nome completo pro sistema.
// Valores em CAPS vindos da planilha sao normalizados pra leitura humana.
// Chaves devem bater EXATAMENTE com o que tá no banco (sensitive a acento).
export const SUBCAT_LABEL: Record<string, string> = {
  // Áudio
  'MIC S/ FIO': 'Microfone sem fio',
  'MIC C/ FIO': 'Microfone com fio',
  'MIC LAPELA': 'Microfone de lapela',
  'MIC': 'Microfone',
  'CAIXA SOM': 'Caixa de som',
  'RX MIC': 'Receptor de microfone',
  'SUB': 'Subwoofer',
  'MESA SOM': 'Mesa de som',
  'AMP': 'Amplificador',
  'AMP FONES': 'Amplificador de fones',
  'AMP RF': 'Amplificador RF',
  'BASE MIC': 'Base de microfone',
  'BASE WIRELESS': 'Base wireless',
  'BAT MAO': 'Bateria de mão',
  'DI': 'Direct Box',
  'IN EAR S / FIO': 'In-ear sem fio',
  'CAPSULA MIC': 'Cápsula de microfone',
  'CAPT MIDI': 'Captador MIDI',
  'CDJ / XDJ / DDJ': 'Controlador DJ',
  'PROC AUDIO': 'Processador de áudio',
  'RECEPTOR DE ANTENA': 'Receptor de antena',
  'ANTENA DIRECIONAL': 'Antena direcional',
  'EQUALIZADOR': 'Equalizador',
  'FONE': 'Fone',
  'BATERIA': 'Bateria',
  'BODYPACK': 'Bodypack',
  'MIXER': 'Mixer',
  'SINTETIZADOR': 'Sintetizador',
  'MUSIC PLAYER': 'Music player',
  'EFFECTS': 'Efeitos',
  'CROSSOVER': 'Crossover',
  'LINE ARRAY': 'Line array',
  'LINE VERTICAL': 'Line vertical',
  'GUITAR SYNTHESIZER': 'Guitar synthesizer',
  'ACESSORIO': 'Acessório',
  // Iluminação
  'INDOOR': 'Moving indoor',
  'OUTDOOR': 'Moving outdoor',
  'MINI MOVING': 'Mini moving',
  'FIXA': 'Luz fixa',
  'MESA LUZ': 'Mesa de luz',
  'OUTRAS LUZES': 'Outras luzes',
  'LASER': 'Laser',
  'MINI BRUTE': 'Mini brute',
  'SPLITTER DMX': 'Splitter DMX',
  'CTRL DMX': 'Controlador DMX',
  'LUZ NEGRA': 'Luz negra',
  'RIBALTA LASER': 'Ribalta laser',
  'STROBO': 'Strobo',
  'BEAM': 'Beam',
  'COB': 'COB',
  '5R': 'Moving 5R',
  '9R': 'Moving 9R',
  'AZUL': 'Laser azul',
  'VERDE': 'Laser verde',
  // Estrutura
  'TRIPE MIC': 'Tripé de microfone',
  'TRIPE CAIXA': 'Tripé de caixa',
  'SUP TV': 'Suporte de TV',
  'BOX TRUSS': 'Box truss',
  'PRATICAVEL': 'Praticável',
  'GERAL': 'Estrutura geral',
  // Efeito
  'MAQ FUMACA': 'Máquina de fumaça',
  'MAQUINA DE FUMACA': 'Máquina de fumaça',
  'MAQUINA FUMACA': 'Máquina de fumaça',
  'MAQ FUMAÇA': 'Máquina de fumaça',
  'MAQUINA DE FUMAÇA': 'Máquina de fumaça',
  'HAZE': 'Máquina de haze',
  'MAQUINA HAZE': 'Máquina de haze',
  'BICO CO2': 'Bico CO2',
  'CO2': 'Bico CO2',
  'CILINDRO': 'Cilindro',
  'GLOBO': 'Globo',
  // Energia
  'REGUA': 'Régua de tomadas',
  'RÉGUA': 'Régua de tomadas',
  'REGUA 6 TOMADAS': 'Régua 6 tomadas',
  'DIST ENERGIA': 'Distribuidor de energia',
  'TRANSFORMADOR': 'Transformador',
  'FONTE': 'Fonte',
  // Vídeo
  'NOTEBOOK': 'Notebook',
  'PROJETOR': 'Projetor',
  'COMPUTADOR': 'Computador',
  'SENDBOX': 'Send box',
  'SUPORTE': 'Suporte',
  'TABLET': 'Tablet',
  // Acessório genéricos
  'MOVING BEAM': 'Moving beam',
  'ROTEADOR': 'Roteador',
  'CLIMATIZADOR': 'Climatizador',
  'CASE': 'Case',
  'PAR LEDS': 'Par LED',
  'PEDALEIRA': 'Pedaleira',
  'RADIO': 'Rádio',
  'RECEPTOR': 'Receptor',
  'RIBALTA': 'Ribalta',
  'TESTER DE CABOS DE AUDIO': 'Tester de cabos de áudio',
  'OUTRO': 'Outro',
}

const LOWER_WORDS = new Set(['de', 'da', 'do', 'das', 'dos', 'e', 'em', 'com', 'sem', 'para', 'por'])

function titleCase(s: string): string {
  return s
    .toLowerCase()
    .split(/\s+/)
    .map((w, i) => {
      if (!w.length) return w
      if (i > 0 && LOWER_WORDS.has(w)) return w
      return w[0].toUpperCase() + w.slice(1)
    })
    .join(' ')
}

export function resolveTipo(subcategoria: string | null | undefined, categoria: Categoria): string {
  if (!subcategoria) return CATEGORIA_LABEL[categoria]
  const key = subcategoria.trim().toUpperCase()
  const label = SUBCAT_LABEL[key] ?? SUBCAT_LABEL[subcategoria]
  if (label) return label
  return titleCase(subcategoria)
}

// Padrão de apresentação do label de um item no catálogo.
//
// Problema: os dados da planilha têm nome, modelo e marca desalinhados:
// - às vezes nome = modelo, marca vazia
// - às vezes nome = "MARCA MODELO", modelo vazio
// - às vezes nome = descritivo genérico ("Caixa de som 12\" ativo"), modelo = modelo técnico
// - às vezes tem prefixos sem sentido ("0.0 ...", "0. ...") vindos de células numéricas
//
// Solução: função central que recebe (nome, modelo, marca) e devolve um label
// primário e um subtítulo opcional, já limpos, aplicando title case onde faz
// sentido e preservando siglas e números.

export type ItemLabel = {
  primary: string
  secondary: string | null
}

const JUNK_PREFIXES = [
  /^0+\.?0+\s+/i,   // "0.0 ", "00 "
  /^0+\s+/,         // "0 "
  /^\.+\s*/,        // ". ", "..."
  /^-+\s*/,         // "- "
]

// Palavras comuns em title case tradicional (stopwords, preposições, conjunções)
const LOWER_WORDS = new Set([
  'de', 'da', 'do', 'das', 'dos', 'e', 'em', 'com', 'sem', 'para', 'por', 'o', 'a',
])

// Siglas / acrônimos / unidades que devem ficar em caps
const UPPER_TOKENS = new Set([
  'DJ', 'DI', 'RF', 'DMX', 'XLR', 'USB', 'HDMI', 'LED', 'UV', 'PAR', 'COB', 'TV',
  'CO2', 'SM', 'AM', 'FM', 'AC', 'DC', 'PRO', 'HD', 'SDI', 'DDJ', 'XDJ', 'CDJ',
  'BNC', 'TRS', 'TS', 'VDC', 'IEM',
])

function stripJunk(s: string): string {
  let out = s
  for (const re of JUNK_PREFIXES) out = out.replace(re, '')
  return out.trim()
}

function looksAllCaps(s: string): boolean {
  const letters = s.replace(/[^a-zA-ZÀ-ÿ]/g, '')
  if (letters.length < 3) return false
  return letters === letters.toUpperCase()
}

function smartCase(word: string): string {
  if (!word) return word
  const bare = word.replace(/[^a-zA-Z0-9]/g, '')
  // Preserva token composto (números+letras, ex: "SM58", "DI600P", "XLR-3")
  if (/\d/.test(bare)) return word.toUpperCase()
  if (UPPER_TOKENS.has(bare.toUpperCase())) return bare.toUpperCase()
  if (bare.length <= 3 && bare === bare.toUpperCase() && !LOWER_WORDS.has(bare.toLowerCase())) {
    // Siglas curtas (ex: "RX", "TX") mantidas em caps
    return word.toUpperCase()
  }
  const lower = word.toLowerCase()
  if (LOWER_WORDS.has(lower)) return lower
  return lower[0].toUpperCase() + lower.slice(1)
}

function smartTitleCase(s: string): string {
  const parts = s.split(/(\s+|[-/])/)
  return parts
    .map((chunk, i) => {
      if (/^\s+$/.test(chunk) || chunk === '-' || chunk === '/') return chunk
      const cased = smartCase(chunk)
      // Primeira palavra nunca fica lowercase
      if (i === 0 && LOWER_WORDS.has(cased.toLowerCase())) {
        return cased[0].toUpperCase() + cased.slice(1)
      }
      return cased
    })
    .join('')
    .replace(/\s+/g, ' ')
    .trim()
}

function normalize(s: string | null | undefined): string {
  return stripJunk((s ?? '').trim())
}

function prettify(s: string): string {
  if (!s) return s
  // Se parece all-caps extenso, passa por smart title case.
  if (looksAllCaps(s)) return smartTitleCase(s)
  // Caso contrário mantém case original (já veio humanizado).
  return s
}

/**
 * Calcula o label de exibição do item.
 * Regras:
 * 1. Limpa prefixos numéricos espúrios ("0.0 ...").
 * 2. Se nome já contém modelo (ou vice-versa), exibe apenas o mais informativo.
 * 3. Se marca está embutida no início do nome, não duplica (coluna Marca cuida).
 * 4. All-caps longos viram title case preservando siglas e alphanum tokens.
 */
export function formatItemLabel(
  nome: string | null | undefined,
  modelo: string | null | undefined,
  marca: string | null | undefined
): ItemLabel {
  const n0 = normalize(nome)
  const m0 = normalize(modelo)
  const brand = (marca ?? '').trim()

  // Remove marca do início/fim do nome e do modelo (a coluna Marca já mostra)
  const stripBrand = (s: string) => {
    if (!s || !brand) return s
    const re = new RegExp(`^${escapeRegex(brand)}\\s+|\\s+${escapeRegex(brand)}$`, 'i')
    return s.replace(re, '').trim()
  }
  const n = prettify(stripBrand(n0))
  const m = prettify(stripBrand(m0))

  if (!n && !m) return { primary: '–', secondary: null }
  if (!n) return { primary: m, secondary: null }
  if (!m) return { primary: n, secondary: null }

  const nLower = n.toLowerCase()
  const mLower = m.toLowerCase()
  if (nLower === mLower) return { primary: n, secondary: null }
  if (nLower.includes(mLower)) return { primary: n, secondary: null }
  if (mLower.includes(nLower)) return { primary: m, secondary: null }

  // Diferentes e complementares: modelo como identificador primário, nome como descritor
  return { primary: m, secondary: n }
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

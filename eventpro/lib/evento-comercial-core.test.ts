import assert from 'node:assert/strict'
import test from 'node:test'
import {
  comercialReadinessPct,
  normalizeEventoComercialInput,
  parseEventoComercialRecord,
  safeCommercialFileName,
  statusAllowsEstoque,
  type EventoComercialDocumento,
} from './evento-comercial-core.ts'

test('normalizes approved commercial status with document links', () => {
  const result = normalizeEventoComercialInput(
    {
      projetoId: 'proj-1',
      status: 'ORCAMENTO_APROVADO',
      orcamentoUrl: 'https://drive.google.com/orcamento',
      contratoUrl: 'https://drive.google.com/contrato',
      observacoes: 'Aprovado por e-mail.',
    },
    [],
    [],
    '2026-06-23T06:00:00.000Z',
  )

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.data.comercial.status, 'ORCAMENTO_APROVADO')
  assert.equal(result.data.comercial.permite_operacao_estoque, true)
  assert.equal(result.data.comercial.readiness_pct, 50)
  assert.equal(result.data.comercial.documentos.length, 2)
  assert.equal(result.data.comercial.documentos[0]?.tipo, 'ORCAMENTO')
  assert.equal(result.data.comercial.documentos[1]?.tipo, 'CONTRATO')
})

test('keeps existing uploads and adds new uploaded document', () => {
  const existing: EventoComercialDocumento[] = [
    {
      id: 'orcamento-upload-old',
      tipo: 'ORCAMENTO',
      origem: 'UPLOAD',
      titulo: 'Orçamento anexado',
      url: null,
      storage_path: 'proj-1/orcamento/old.pdf',
      filename: 'old.pdf',
      mime_type: 'application/pdf',
      tamanho_bytes: 123,
      atualizado_em: '2026-06-22T10:00:00.000Z',
    },
  ]

  const result = normalizeEventoComercialInput(
    {
      projetoId: 'proj-1',
      status: 'CONTRATO_ENVIADO',
      orcamentoUrl: '',
      contratoUrl: '',
      observacoes: '',
    },
    existing,
    [
      {
        tipo: 'CONTRATO',
        filename: 'contrato.pdf',
        storage_path: 'proj-1/contrato/new.pdf',
        mime_type: 'application/pdf',
        tamanho_bytes: 456,
      },
    ],
    '2026-06-23T06:00:00.000Z',
  )

  assert.equal(result.ok, true)
  if (!result.ok) return
  assert.equal(result.data.comercial.documentos.length, 2)
  assert.deepEqual(
    result.data.comercial.documentos.map((doc) => doc.storage_path),
    ['proj-1/orcamento/old.pdf', 'proj-1/contrato/new.pdf'],
  )
})

test('rejects invalid commercial URL', () => {
  const result = normalizeEventoComercialInput({
    projetoId: 'proj-1',
    status: 'ORCAMENTO_ENVIADO',
    orcamentoUrl: 'ftp://example.com/file.pdf',
  })

  assert.equal(result.ok, false)
  if (result.ok) return
  assert.match(result.error, /http ou https/)
})

test('parses unknown DB value as empty commercial record', () => {
  const record = parseEventoComercialRecord({ status: 'PAGO', documentos: 'bad' })

  assert.equal(record.status, null)
  assert.equal(record.documentos.length, 0)
  assert.equal(record.permite_operacao_estoque, false)
  assert.equal(record.readiness_pct, 0)
})

test('commercial readiness follows the four supported statuses', () => {
  assert.equal(comercialReadinessPct('ORCAMENTO_ENVIADO'), 25)
  assert.equal(comercialReadinessPct('ORCAMENTO_APROVADO'), 50)
  assert.equal(comercialReadinessPct('CONTRATO_ENVIADO'), 75)
  assert.equal(comercialReadinessPct('CONTRATO_ASSINADO'), 100)
  assert.equal(statusAllowsEstoque('ORCAMENTO_ENVIADO'), false)
  assert.equal(statusAllowsEstoque('ORCAMENTO_APROVADO'), true)
})

test('safeCommercialFileName strips accents and unsafe characters', () => {
  assert.equal(safeCommercialFileName('Orçamento final / Cliente.pdf'), 'Orcamento-final-Cliente.pdf')
})

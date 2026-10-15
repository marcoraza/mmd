import assert from 'node:assert/strict'
import test from 'node:test'

import { buildRfidScanPlan, parseRfidScanPayload, recordRfidScanBatch } from './rfid-scan-core.ts'

test('RFID scan plan resolves known tags and keeps orphan tags auditable', () => {
  const plan = buildRfidScanPlan({
    tags: [' e28011702000020a5c41b6e0 ', 'E28011702000020A5C41B7F1'],
    contexto: 'CHECK_OUT_EVENTO',
    projeto_id: 'project-1',
    operador: 'Marcelo',
    reader_id: 'reader-1',
    serialsByTag: new Map([
      [
        'E28011702000020A5C41B6E0',
        {
          id: 'serial-1',
          codigo_interno: 'MMD-ILU-0001',
          item_nome: 'Moving Beam 7R',
        },
      ],
    ]),
  })

  assert.equal(plan.resolved.length, 1)
  assert.equal(plan.unresolved.length, 1)
  assert.equal(plan.resolved[0].codigo_interno, 'MMD-ILU-0001')
  assert.deepEqual(plan.unresolved, ['E28011702000020A5C41B7F1'])
  assert.deepEqual(
    plan.scanRows.map((row) => ({
      tag_rfid: row.tag_rfid,
      serial_number_id: row.serial_number_id,
      projeto_id: row.projeto_id,
      operador: row.operador,
      contexto: row.contexto,
      reader_id: row.reader_id,
      notas: row.notas,
    })),
    [
      {
        tag_rfid: 'E28011702000020A5C41B6E0',
        serial_number_id: 'serial-1',
        projeto_id: 'project-1',
        operador: 'Marcelo',
        contexto: 'CHECK_OUT_EVENTO',
        reader_id: 'reader-1',
        notas: null,
      },
      {
        tag_rfid: 'E28011702000020A5C41B7F1',
        serial_number_id: null,
        projeto_id: 'project-1',
        operador: 'Marcelo',
        contexto: 'CHECK_OUT_EVENTO',
        reader_id: 'reader-1',
        notas: 'Tag RFID não reconhecida',
      },
    ],
  )
})

test('RFID scan payload rejects empty or invalid tag lists', () => {
  assert.deepEqual(parseRfidScanPayload({ tags: [] }), {
    ok: false,
    error: 'tags_invalidas',
  })
  assert.deepEqual(parseRfidScanPayload({ tags: ['***'] }), {
    ok: false,
    error: 'tags_invalidas',
  })
})

test('RFID scan batch persists reader and scan rows before returning scan ids', async () => {
  const insertedRows: unknown[] = []
  const result = await recordRfidScanBatch(
    {
      payload: {
        tags: ['E28011702000020A5C41B6E0', 'E28011702000020A5C41B7F1'],
        contexto: 'INVENTARIO',
        projeto_id: null,
        localizacao: 'Galpão',
        reader: {
          nome: 'RFD40 iPhone',
          modelo: 'Zebra RFD40',
          serial_fabrica: 'RFD40-001',
          bateria: 82,
        },
      },
      operador: 'Marcelo',
    },
    {
      async upsertReader() {
        return { id: 'reader-1' }
      },
      async findSerialsByTags() {
        return new Map([
          [
            'E28011702000020A5C41B6E0',
            {
              id: 'serial-1',
              codigo_interno: 'MMD-ILU-0001',
              item_nome: 'Moving Beam 7R',
            },
          ],
        ])
      },
      async insertScans(rows) {
        insertedRows.push(...rows)
        return rows.map((_, index) => ({ id: `scan-${index + 1}` }))
      },
    },
  )

  assert.equal(result.ok, true)
  assert.deepEqual(result.scan_ids, ['scan-1', 'scan-2'])
  assert.equal(result.resolved[0].codigo_interno, 'MMD-ILU-0001')
  assert.deepEqual(result.unresolved, ['E28011702000020A5C41B7F1'])
  assert.equal(insertedRows.length, 2)
})

test('RFID scan batch skips reader upsert when reader has no factory serial', async () => {
  const payload = parseRfidScanPayload({
    tags: ['TAG00001'],
    reader: { nome: 'RFD40 iPhone' },
  })

  assert.equal(payload.ok, true)
  if (!payload.ok) return

  let upsertCalls = 0
  const result = await recordRfidScanBatch(
    { payload: payload.payload, operador: 'Marcelo' },
    {
      async upsertReader() {
        upsertCalls += 1
        return { id: 'reader-1' }
      },
      async findSerialsByTags() {
        return new Map()
      },
      async insertScans(rows) {
        assert.equal(rows[0].reader_id, null)
        return [{ id: 'scan-1' }]
      },
    },
  )

  assert.equal(upsertCalls, 0)
  assert.deepEqual(result.scan_ids, ['scan-1'])
})

'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import type { CatalogData, CatalogItem } from '@/lib/data/items'
import type { Categoria } from '@/lib/types'
import { CategoryNav } from './CategoryNav'
import { OperationalBanner } from './OperationalBanner'
import { CatalogToolbar } from './CatalogToolbar'
import { ItemTable } from './ItemTable'
import { ItemSidePanel } from './ItemSidePanel'
import { LotesCard } from './LotesCard'
import { useCatalogView } from '@/hooks/useCatalogView'
import { useItemMutation } from '@/hooks/useItemMutation'
import { resolveTipo } from '@/lib/nomenclature'
import { SITUACAO_LABEL } from './helpers'

export function CatalogClient({ data }: { data: CatalogData }) {
  const [selectedCategoria, setSelectedCategoria] = useState<Categoria | 'ALL'>('ALL')
  const [query, setQuery] = useState('')
  const [selectedItem, setSelectedItem] = useState<CatalogItem | null>(null)
  const { view, update, toggleColumn } = useCatalogView()
  const { updateDesgaste, updateQuantidade, pending } = useItemMutation()

  // Estado local editável; parte dos dados vindos do server.
  const [items, setItems] = useState<CatalogItem[]>(data.items)
  useEffect(() => {
    setItems(data.items)
  }, [data.items])

  const handleCondicaoChange = useCallback(
    async (itemId: string, desgaste: number) => {
      const prev = items.find((i) => i.id === itemId)
      if (!prev) return
      setItems((list) =>
        list.map((it) =>
          it.id === itemId ? { ...it, condicao_media: desgaste } : it
        )
      )
      const ok = await updateDesgaste(itemId, desgaste)
      if (!ok) {
        setItems((list) =>
          list.map((it) =>
            it.id === itemId ? { ...it, condicao_media: prev.condicao_media } : it
          )
        )
      }
    },
    [items, updateDesgaste]
  )

  const handleQtdChange = useCallback(
    async (itemId: string, qtd: number) => {
      const prev = items.find((i) => i.id === itemId)
      if (!prev) return
      setItems((list) =>
        list.map((it) =>
          it.id === itemId ? { ...it, quantidade_total: qtd } : it
        )
      )
      const ok = await updateQuantidade(itemId, qtd)
      if (!ok) {
        setItems((list) =>
          list.map((it) =>
            it.id === itemId ? { ...it, quantidade_total: prev.quantidade_total } : it
          )
        )
      }
    },
    [items, updateQuantidade]
  )

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    let rows = items

    if (selectedCategoria !== 'ALL') {
      rows = rows.filter((i) => i.categoria === selectedCategoria)
    }
    if (q) {
      rows = rows.filter((i) =>
        [i.nome, i.marca, i.modelo, i.subcategoria, i.codigo_interno, i.id]
          .filter(Boolean)
          .some((v) => (v as string).toLowerCase().includes(q))
      )
    }

    const dir = view.sortDir === 'asc' ? 1 : -1
    const sorted = [...rows].sort((a, b) => {
      switch (view.sortKey) {
        case 'codigo':
          return (a.codigo_interno ?? '').localeCompare(b.codigo_interno ?? '', 'pt-BR') * dir
        case 'tipo':
          return resolveTipo(a.subcategoria, a.categoria).localeCompare(
            resolveTipo(b.subcategoria, b.categoria),
            'pt-BR'
          ) * dir
        case 'nome':
          return a.nome.localeCompare(b.nome, 'pt-BR') * dir
        case 'marca':
          return (a.marca ?? '').localeCompare(b.marca ?? '', 'pt-BR') * dir
        case 'qtd':
          return (a.quantidade_total - b.quantidade_total) * dir
        case 'situacao':
          return SITUACAO_LABEL[a.situacao].localeCompare(SITUACAO_LABEL[b.situacao], 'pt-BR') * dir
        case 'ciclo':
          return (a.ciclo ?? '').localeCompare(b.ciclo ?? '', 'pt-BR') * dir
        case 'condicao':
          return (a.condicao_media - b.condicao_media) * dir
        case 'valor':
          return (a.valor_atual_total - b.valor_atual_total) * dir
        default:
          return 0
      }
    })

    return sorted
  }, [items, selectedCategoria, query, view.sortKey, view.sortDir])

  const totalAtivos = data.banner.total_ativos

  return (
    <>
      <CategoryNav
        categories={data.categories}
        totalAtivos={totalAtivos}
        selected={selectedCategoria}
        onSelect={setSelectedCategoria}
      />

      <OperationalBanner stats={data.banner} />

      <div style={{ marginTop: 20 }}>
        <CatalogToolbar
          query={query}
          onQueryChange={setQuery}
          visibleCount={filtered.length}
          totalCount={data.items.length}
        />
      </div>

      <div style={{ marginTop: 16 }}>
        <ItemTable
          items={filtered}
          columns={view.columns}
          groupBy={view.groupBy}
          sortKey={view.sortKey}
          sortDir={view.sortDir}
          onSort={(key, dir) => update({ sortKey: key, sortDir: dir })}
          onGroup={(g) => update({ groupBy: g })}
          onToggleColumn={toggleColumn}
          onSelect={setSelectedItem}
          selectedId={selectedItem?.id ?? null}
          onCondicaoChange={handleCondicaoChange}
          onQtdChange={handleQtdChange}
          pending={pending}
        />
      </div>

      <LotesCard total={data.total_lotes} />

      <ItemSidePanel
        item={selectedItem ? items.find((i) => i.id === selectedItem.id) ?? selectedItem : null}
        onClose={() => setSelectedItem(null)}
        onCondicaoChange={handleCondicaoChange}
        pending={pending}
      />
    </>
  )
}

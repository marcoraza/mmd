'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import type { CatalogData, CatalogItem, CatalogUnit } from '@/lib/data/items'
import type { Categoria } from '@/lib/types'
import { CategoryNav } from './CategoryNav'
import { OperationalBanner } from './OperationalBanner'
import { CatalogToolbar } from './CatalogToolbar'
import type { BannerFilter } from './OperationalBanner'
import { ItemTable } from './ItemTable'
import { ItemSidePanel } from './ItemSidePanel'
import { LotesCard } from './LotesCard'
import { UnitsTable } from './UnitsTable'
import { ViewModeToggle, type CatalogMode } from './ViewModeToggle'
import { useCatalogView } from '@/hooks/useCatalogView'
import { useUnitsView } from '@/hooks/useUnitsView'
import { useItemMutation } from '@/hooks/useItemMutation'
import { resolveTipo } from '@/lib/nomenclature'
import { SITUACAO_LABEL } from './helpers'

const MODE_STORAGE_KEY = 'mmd.catalog.mode.v1'

export function CatalogClient({
  data,
  units,
}: {
  data: CatalogData
  units: CatalogUnit[]
}) {
  const [selectedCategoria, setSelectedCategoria] = useState<Categoria | 'ALL'>('ALL')
  const [bannerFilter, setBannerFilter] = useState<BannerFilter | null>(null)
  const [query, setQuery] = useState('')
  const [selectedItem, setSelectedItem] = useState<CatalogItem | null>(null)
  const [mode, setMode] = useState<CatalogMode>('tipos')

  const { view, update } = useCatalogView()
  const { view: unitsView, toggleSort: toggleUnitSort } = useUnitsView()
  const { updateDesgaste, updateQuantidade, pending } = useItemMutation()

  // Estado local editável; parte dos dados vindos do server.
  const [items, setItems] = useState<CatalogItem[]>(data.items)
  useEffect(() => {
    setItems(data.items)
  }, [data.items])

  // Hydrate mode from localStorage.
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(MODE_STORAGE_KEY)
      if (raw === 'tipos' || raw === 'unidades') setMode(raw)
    } catch {}
  }, [])

  const handleModeChange = useCallback((next: CatalogMode) => {
    setMode(next)
    try {
      window.localStorage.setItem(MODE_STORAGE_KEY, next)
    } catch {}
  }, [])

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
    if (bannerFilter) {
      rows = rows.filter((i) => matchBannerFilter(i, bannerFilter))
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
  }, [items, selectedCategoria, bannerFilter, query, view.sortKey, view.sortDir])

  const filteredUnits = useMemo(() => {
    const q = query.trim().toLowerCase()
    let rows = units

    if (selectedCategoria !== 'ALL') {
      rows = rows.filter((u) => u.item_categoria === selectedCategoria)
    }
    if (bannerFilter) {
      rows = rows.filter((u) => matchUnitBannerFilter(u, bannerFilter))
    }
    if (q) {
      rows = rows.filter((u) =>
        [
          u.codigo_interno,
          u.serial_fabrica,
          u.tag_rfid,
          u.qr_code,
          u.item_nome,
          u.item_marca,
          u.item_modelo,
          u.item_subcategoria,
          u.localizacao,
        ]
          .filter(Boolean)
          .some((v) => (v as string).toLowerCase().includes(q))
      )
    }

    return rows
  }, [units, selectedCategoria, bannerFilter, query])

  const visibleCount = mode === 'tipos' ? filtered.length : filteredUnits.length
  const totalCount = mode === 'tipos' ? data.items.length : units.length

  const totalAtivos = data.banner.total_ativos

  const handleSelectUnitItem = useCallback(
    (itemId: string) => {
      const target = items.find((i) => i.id === itemId)
      if (target) setSelectedItem(target)
    },
    [items]
  )

  return (
    <>
      <CategoryNav
        categories={data.categories}
        totalAtivos={totalAtivos}
        selected={selectedCategoria}
        onSelect={setSelectedCategoria}
      />

      <OperationalBanner
        stats={data.banner}
        active={bannerFilter}
        onFilter={(f) => setBannerFilter((prev) => (prev === f ? null : f))}
      />

      <div
        style={{
          marginTop: 20,
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          flexWrap: 'wrap',
        }}
      >
        <ViewModeToggle
          mode={mode}
          onChange={handleModeChange}
          tiposCount={data.items.length}
          unidadesCount={units.length}
        />
        <div style={{ flex: 1, minWidth: 280 }}>
          <CatalogToolbar
            query={query}
            onQueryChange={setQuery}
            visibleCount={visibleCount}
            totalCount={totalCount}
          />
        </div>
      </div>

      <div style={{ marginTop: 16 }}>
        {mode === 'tipos' ? (
          <ItemTable
            items={filtered}
            columns={view.columns}
            groupBy={view.groupBy}
            sortKey={view.sortKey}
            sortDir={view.sortDir}
            onSort={(key, dir) => update({ sortKey: key, sortDir: dir })}
            onSelect={setSelectedItem}
            selectedId={selectedItem?.id ?? null}
            onCondicaoChange={handleCondicaoChange}
            onQtdChange={handleQtdChange}
            pending={pending}
          />
        ) : (
          <UnitsTable
            units={filteredUnits}
            groupBy={unitsView.groupBy}
            sortKey={unitsView.sortKey}
            sortDir={unitsView.sortDir}
            onSort={toggleUnitSort}
            onSelectItem={handleSelectUnitItem}
          />
        )}
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

function matchBannerFilter(item: CatalogItem, filter: BannerFilter): boolean {
  switch (filter) {
    case 'disponivel':
      return item.disponivel_count > 0
    case 'em_campo':
      return item.em_campo_count > 0
    case 'manutencao':
      return item.manutencao_count > 0
    case 'criticos':
      return item.criticos_count > 0
    case 'regular':
      return item.regular_count > 0
    case 'otimo':
      return item.otimo_count > 0
  }
}

function matchUnitBannerFilter(unit: CatalogUnit, filter: BannerFilter): boolean {
  switch (filter) {
    case 'disponivel':
      return unit.status === 'DISPONIVEL'
    case 'em_campo':
      return unit.status === 'EM_CAMPO' || unit.status === 'PACKED' || unit.status === 'RETORNANDO'
    case 'manutencao':
      return unit.status === 'MANUTENCAO'
    case 'criticos':
      return unit.desgaste <= 2
    case 'regular':
      return unit.desgaste === 3
    case 'otimo':
      return unit.desgaste >= 4
  }
}

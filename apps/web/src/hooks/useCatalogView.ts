'use client'

import { useEffect, useState } from 'react'

export type ColumnKey =
  | 'codigo'
  | 'marca'
  | 'tipo'
  | 'qtd'
  | 'situacao'
  | 'ciclo'
  | 'condicao'
  | 'valor'

export type SortKey =
  | 'codigo'
  | 'tipo'
  | 'nome'
  | 'marca'
  | 'qtd'
  | 'situacao'
  | 'ciclo'
  | 'condicao'
  | 'valor'
export type SortDir = 'asc' | 'desc'
export type GroupBy = 'none' | 'categoria' | 'subcategoria' | 'situacao' | 'ciclo'

export type CatalogView = {
  sortKey: SortKey
  sortDir: SortDir
  groupBy: GroupBy
  columns: Record<ColumnKey, boolean>
}

export const DEFAULT_VIEW: CatalogView = {
  sortKey: 'nome',
  sortDir: 'asc',
  groupBy: 'none',
  columns: {
    codigo: true,
    marca: true,
    tipo: true,
    qtd: true,
    situacao: true,
    ciclo: true,
    condicao: true,
    valor: false,
  },
}

const STORAGE_KEY = 'mmd.catalog.view.v1'

function sanitize(raw: unknown): CatalogView {
  if (!raw || typeof raw !== 'object') return DEFAULT_VIEW
  const v = raw as Partial<CatalogView>
  return {
    sortKey: v.sortKey ?? DEFAULT_VIEW.sortKey,
    sortDir: v.sortDir ?? DEFAULT_VIEW.sortDir,
    groupBy: v.groupBy ?? DEFAULT_VIEW.groupBy,
    columns: { ...DEFAULT_VIEW.columns, ...(v.columns ?? {}) },
  }
}

export function useCatalogView() {
  const [view, setView] = useState<CatalogView>(DEFAULT_VIEW)
  const [hydrated, setHydrated] = useState(false)

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY)
      if (raw) setView(sanitize(JSON.parse(raw)))
    } catch {}
    setHydrated(true)
  }, [])

  useEffect(() => {
    if (!hydrated) return
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(view))
    } catch {}
  }, [view, hydrated])

  function update(patch: Partial<CatalogView>) {
    setView((v) => ({ ...v, ...patch }))
  }

  function toggleColumn(key: ColumnKey) {
    setView((v) => ({ ...v, columns: { ...v.columns, [key]: !v.columns[key] } }))
  }

  function reset() {
    setView(DEFAULT_VIEW)
  }

  return { view, update, toggleColumn, reset, hydrated }
}

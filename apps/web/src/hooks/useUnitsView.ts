'use client'

import { useEffect, useState } from 'react'
import type {
  UnitGroupBy,
  UnitSortDir,
  UnitSortKey,
} from '@/components/catalog/UnitsTable'

export type UnitsView = {
  sortKey: UnitSortKey
  sortDir: UnitSortDir
  groupBy: UnitGroupBy
}

export const DEFAULT_UNITS_VIEW: UnitsView = {
  sortKey: 'codigo',
  sortDir: 'asc',
  groupBy: 'none',
}

const STORAGE_KEY = 'mmd.catalog.units.view.v1'

function sanitize(raw: unknown): UnitsView {
  if (!raw || typeof raw !== 'object') return DEFAULT_UNITS_VIEW
  const v = raw as Partial<UnitsView>
  return {
    sortKey: v.sortKey ?? DEFAULT_UNITS_VIEW.sortKey,
    sortDir: v.sortDir ?? DEFAULT_UNITS_VIEW.sortDir,
    groupBy: v.groupBy ?? DEFAULT_UNITS_VIEW.groupBy,
  }
}

export function useUnitsView() {
  const [view, setView] = useState<UnitsView>(DEFAULT_UNITS_VIEW)
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

  function update(patch: Partial<UnitsView>) {
    setView((v) => ({ ...v, ...patch }))
  }

  function toggleSort(key: UnitSortKey) {
    setView((v) => {
      if (v.sortKey === key) {
        return { ...v, sortDir: v.sortDir === 'asc' ? 'desc' : 'asc' }
      }
      return { ...v, sortKey: key, sortDir: 'asc' }
    })
  }

  return { view, update, toggleSort, hydrated }
}

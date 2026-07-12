'use client'

import { useStoredState } from './useStoredState'
import type { UnitGroupBy, UnitSortDir, UnitSortKey } from '@/components/catalog/UnitsTable'

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
  const [view, setView] = useStoredState<UnitsView>(STORAGE_KEY, DEFAULT_UNITS_VIEW, (raw) =>
    sanitize(JSON.parse(raw)),
  )

  function update(patch: Partial<UnitsView>) {
    setView({ ...view, ...patch })
  }

  function toggleSort(key: UnitSortKey) {
    if (view.sortKey === key) {
      setView({ ...view, sortDir: view.sortDir === 'asc' ? 'desc' : 'asc' })
    } else {
      setView({ ...view, sortKey: key, sortDir: 'asc' })
    }
  }

  return { view, update, toggleSort }
}

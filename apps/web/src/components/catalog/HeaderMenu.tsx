'use client'

import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Icons } from '@/components/mmd/Icons'
import type { ColumnKey, GroupBy, SortDir, SortKey } from '@/hooks/useCatalogView'

const MENU_WIDTH = 220

export type HeaderMenuProps = {
  label: string
  sortKey: SortKey
  align: 'left' | 'right'
  columnKey: ColumnKey | '__item__'
  groupTarget: GroupBy | null
  currentSortKey: SortKey
  currentSortDir: SortDir
  currentGroupBy: GroupBy
  onSort: (key: SortKey, dir: SortDir) => void
  onGroup: (g: GroupBy) => void
  onHide?: () => void
}

export function HeaderMenu({
  label,
  sortKey,
  align,
  columnKey,
  groupTarget,
  currentSortKey,
  currentSortDir,
  currentGroupBy,
  onSort,
  onGroup,
  onHide,
}: HeaderMenuProps) {
  const [open, setOpen] = useState(false)
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null)
  const moreRef = useRef<HTMLButtonElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    if (!open || !moreRef.current) return
    function place() {
      const btn = moreRef.current
      if (!btn) return
      const r = btn.getBoundingClientRect()
      const left =
        align === 'right'
          ? Math.max(8, r.right - MENU_WIDTH)
          : Math.max(8, Math.min(window.innerWidth - MENU_WIDTH - 8, r.left))
      const top = r.bottom + 4
      setPos({ top, left })
    }
    place()
    window.addEventListener('resize', place)
    window.addEventListener('scroll', place, true)
    return () => {
      window.removeEventListener('resize', place)
      window.removeEventListener('scroll', place, true)
    }
  }, [open, align])

  useEffect(() => {
    if (!open) return
    function onDoc(e: MouseEvent) {
      const t = e.target as Node
      if (moreRef.current?.contains(t)) return
      if (menuRef.current?.contains(t)) return
      setOpen(false)
    }
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  const active = currentSortKey === sortKey
  const arrow = active ? (currentSortDir === 'asc' ? '↑' : '↓') : ''
  const isGrouped = groupTarget !== null && currentGroupBy === groupTarget
  const groupingActive = currentGroupBy !== 'none'

  const hasExtras = !!groupTarget || (!!onHide && columnKey !== '__item__') || (!groupTarget && groupingActive)

  function handleSortClick() {
    const nextDir: SortDir = active ? (currentSortDir === 'asc' ? 'desc' : 'asc') : 'asc'
    onSort(sortKey, nextDir)
  }

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: align === 'right' ? 'flex-end' : 'flex-start',
        gap: 2,
        width: '100%',
      }}
    >
      <button
        type="button"
        onClick={handleSortClick}
        title={`Ordenar por ${label.toLowerCase()}`}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 4,
          background: 'transparent',
          border: 'none',
          padding: '2px 6px',
          borderRadius: 'var(--r-sm)',
          color: active ? 'var(--fg-0)' : 'inherit',
          fontWeight: active ? 600 : 'inherit',
          fontFamily: 'inherit',
          fontSize: 'inherit',
          letterSpacing: 'inherit',
          textTransform: 'inherit',
          cursor: 'pointer',
        }}
      >
        <span>{label}</span>
        {arrow && <span style={{ fontSize: 11, opacity: 0.85 }}>{arrow}</span>}
        {isGrouped && (
          <span
            style={{
              fontSize: 9,
              padding: '0 4px',
              borderRadius: 2,
              background: 'var(--fg-0)',
              color: 'var(--bg-0)',
              letterSpacing: 0.3,
            }}
          >
            GRUPO
          </span>
        )}
      </button>

      {hasExtras && (
        <button
          ref={moreRef}
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-haspopup="menu"
          title={`Mais opções de ${label}`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: open ? 'var(--glass-bg-strong)' : 'transparent',
            border: 'none',
            padding: '2px 4px',
            borderRadius: 'var(--r-sm)',
            color: 'var(--fg-2)',
            cursor: 'pointer',
          }}
        >
          {Icons.dot3}
        </button>
      )}

      {open && pos && (
        <div
          ref={menuRef}
          role="menu"
          style={{
            position: 'fixed',
            top: pos.top,
            left: pos.left,
            width: MENU_WIDTH,
            background: 'var(--bg-1)',
            border: '1px solid var(--glass-border-strong)',
            borderRadius: 'var(--r-md)',
            boxShadow: 'var(--glass-shadow-elevated)',
            zIndex: 1000,
            padding: 4,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {groupTarget && !isGrouped && (
            <MenuItem
              onClick={() => {
                onGroup(groupTarget)
                setOpen(false)
              }}
            >
              Agrupar por {label.toLowerCase()}
            </MenuItem>
          )}
          {groupTarget && isGrouped && (
            <MenuItem
              onClick={() => {
                onGroup('none')
                setOpen(false)
              }}
            >
              Remover agrupamento
            </MenuItem>
          )}
          {!groupTarget && groupingActive && (
            <MenuItem
              onClick={() => {
                onGroup('none')
                setOpen(false)
              }}
            >
              Remover agrupamento
            </MenuItem>
          )}
          {onHide && columnKey !== '__item__' && (
            <MenuItem
              onClick={() => {
                onHide()
                setOpen(false)
              }}
              danger
            >
              Esconder coluna
            </MenuItem>
          )}
        </div>
      )}
    </div>
  )
}

function MenuItem({
  children,
  onClick,
  danger,
}: {
  children: React.ReactNode
  onClick: () => void
  danger?: boolean
}) {
  return (
    <button
      type="button"
      role="menuitem"
      onClick={onClick}
      style={{
        textAlign: 'left',
        background: 'transparent',
        border: 'none',
        padding: '8px 10px',
        borderRadius: 'var(--r-sm)',
        color: danger ? 'var(--accent-red)' : 'var(--fg-0)',
        fontFamily: 'inherit',
        fontSize: 13,
        cursor: 'pointer',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.background = 'var(--glass-bg)'
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.background = 'transparent'
      }}
    >
      {children}
    </button>
  )
}

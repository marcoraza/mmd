'use client'

import { useEffect, useState, useCallback } from 'react'
import Link from 'next/link'
import { Plus } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { PageHeader } from '@/components/layout/PageHeader'
import { ItemTable } from '@/components/items/ItemTable'
import { ItemCard } from '@/components/items/ItemCard'
import { SearchInput } from '@/components/ui/SearchInput'
import { FilterChips } from '@/components/ui/FilterChips'
import { Pagination } from '@/components/ui/Pagination'
import type { Item, Categoria } from '@/lib/types'

const CATEGORIA_OPTIONS: { value: Categoria; label: string }[] = [
  { value: 'ILUMINACAO', label: 'Iluminação' },
  { value: 'AUDIO', label: 'Áudio' },
  { value: 'CABO', label: 'Cabo' },
  { value: 'ENERGIA', label: 'Energia' },
  { value: 'ESTRUTURA', label: 'Estrutura' },
  { value: 'EFEITO', label: 'Efeito' },
  { value: 'VIDEO', label: 'Vídeo' },
  { value: 'ACESSORIO', label: 'Acessório' },
]

const PAGE_SIZE = 20

export default function ItemsPage() {
  const [items, setItems] = useState<Item[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [categorias, setCategorias] = useState<Categoria[]>([])
  const [page, setPage] = useState(1)
  const [sortBy, setSortBy] = useState('nome')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc')
  const [isMobile, setIsMobile] = useState(false)

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])

  const fetchItems = useCallback(async () => {
    setLoading(true)

    let query = supabase
      .from('items')
      .select('*, serial_numbers(id, status)', { count: 'exact' })

    if (search) {
      query = query.or(`nome.ilike.%${search}%,marca.ilike.%${search}%,modelo.ilike.%${search}%`)
    }
    if (categorias.length > 0) {
      query = query.in('categoria', categorias)
    }

    query = query.order(sortBy as keyof Item, { ascending: sortDir === 'asc' })
    query = query.range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1)

    const { data, count, error } = await query
    if (!error && data) {
      setItems(data as Item[])
      setTotal(count ?? 0)
    }
    setLoading(false)
  }, [search, categorias, page, sortBy, sortDir])

  useEffect(() => {
    fetchItems()
  }, [fetchItems])

  function handleSort(col: string) {
    if (sortBy === col) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortBy(col)
      setSortDir('asc')
    }
    setPage(1)
  }

  function toggleCategoria(cat: Categoria) {
    setCategorias((prev) =>
      prev.includes(cat) ? prev.filter((c) => c !== cat) : [...prev, cat],
    )
    setPage(1)
  }

  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div>
      <PageHeader
        title="Inventário"
        subtitle={`${total} itens`}
        action={
          <Link
            href="/items/new"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              fontFamily: '"Space Mono", monospace',
              fontSize: 11,
              letterSpacing: '0.1em',
              color: '#FFFFFF',
              backgroundColor: '#000000',
              border: 'none',
              borderRadius: 999,
              padding: '7px 16px',
              textDecoration: 'none',
            }}
          >
            <Plus size={12} />
            NOVO ITEM
          </Link>
        }
      />

      {/* Search + filters */}
      <div style={{ padding: '16px 32px', borderBottom: '1px solid #E8E8E8' }}>
        <SearchInput
          value={search}
          onChange={(v) => { setSearch(v); setPage(1) }}
          placeholder="Buscar por nome, marca ou modelo..."
          className="mb-4"
        />
        <FilterChips
          options={CATEGORIA_OPTIONS}
          selected={categorias}
          onToggle={toggleCategoria}
        />
      </div>

      {/* Table / cards */}
      <div style={{ padding: '0 0 16px' }}>
        {loading ? (
          <div style={{ padding: '32px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', textAlign: 'center' }}>
            CARREGANDO...
          </div>
        ) : items.length === 0 ? (
          <div style={{ padding: '32px', fontFamily: '"Space Mono", monospace', fontSize: 11, color: '#CCCCCC', textAlign: 'center' }}>
            NENHUM ITEM ENCONTRADO
          </div>
        ) : isMobile ? (
          <div className="flex flex-col gap-2 px-4 pt-4">
            {items.map((item) => <ItemCard key={item.id} item={item} />)}
          </div>
        ) : (
          <div style={{ paddingTop: 16 }}>
            <ItemTable
              items={items}
              sortBy={sortBy}
              sortDir={sortDir}
              onSort={handleSort}
            />
          </div>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div style={{ padding: '0 32px 16px', borderTop: '1px solid #E8E8E8' }}>
          <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
        </div>
      )}
    </div>
  )
}

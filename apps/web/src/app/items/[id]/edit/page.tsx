import { notFound } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { PageHeader } from '@/components/layout/PageHeader'
import { ItemForm } from '@/components/items/ItemForm'
import type { Item } from '@/lib/types'

interface Props {
  params: Promise<{ id: string }>
}

export default async function EditItemPage({ params }: Props) {
  const { id } = await params
  const { data } = await supabase.from('items').select('*').eq('id', id).single()
  if (!data) notFound()

  return (
    <div>
      <PageHeader title="Editar Item" subtitle={(data as Item).nome} />
      <ItemForm item={data as Item} />
    </div>
  )
}

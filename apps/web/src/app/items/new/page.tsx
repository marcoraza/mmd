import { PageHeader } from '@/components/layout/PageHeader'
import { ItemForm } from '@/components/items/ItemForm'

export default function NewItemPage() {
  return (
    <div>
      <PageHeader title="Novo Item" subtitle="Cadastrar equipamento" />
      <ItemForm />
    </div>
  )
}

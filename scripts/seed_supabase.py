from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
from pathlib import Path
from typing import Any

from supabase import Client, create_client


ROOT_DIR = Path(__file__).resolve().parents[1]
ITEMS_PATH = ROOT_DIR / "data" / "items.json"
SERIALS_PATH = ROOT_DIR / "data" / "serial_numbers.json"
LOTES_PATH = ROOT_DIR / "data" / "lotes.json"
MIGRATIONS_DIR = ROOT_DIR / "supabase" / "migrations"

ITEM_COLUMNS = [
    "id",
    "nome",
    "categoria",
    "subcategoria",
    "marca",
    "modelo",
    "tipo_rastreamento",
    "quantidade_total",
    "valor_mercado_unitario",
    "foto_url",
    "notas",
]

SERIAL_COLUMNS = [
    "id",
    "item_id",
    "codigo_interno",
    "serial_fabrica",
    "tag_rfid",
    "qr_code",
    "status",
    "estado",
    "desgaste",
    "depreciacao_pct",
    "valor_atual",
    "localizacao",
    "notas",
]

LOTE_COLUMNS = [
    "id",
    "item_id",
    "codigo_lote",
    "descricao",
    "quantidade",
    "tag_rfid",
    "qr_code",
    "status",
]


def load_json(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, list):
        raise ValueError(f"{path} nao contem uma lista JSON.")
    return payload


def sanitize_records(records: list[dict[str, Any]], allowed_columns: list[str]) -> list[dict[str, Any]]:
    return [{column: record.get(column) for column in allowed_columns} for record in records]


def chunked(records: list[dict[str, Any]], size: int) -> list[list[dict[str, Any]]]:
    return [records[index : index + size] for index in range(0, len(records), size)]


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Variavel de ambiente obrigatoria ausente: {name}")
    return value


def create_supabase_client() -> Client:
    url = require_env("SUPABASE_URL")
    service_role_key = require_env("SUPABASE_SERVICE_ROLE_KEY")
    return create_client(url, service_role_key)


def load_stdin_secrets() -> None:
    payload = json.loads(sys.stdin.readline())
    if not isinstance(payload, dict):
        raise SystemExit("Secrets via stdin precisam vir em um objeto JSON.")
    for key, value in payload.items():
        if value is None:
            continue
        os.environ[key] = str(value)


def prompt_for_secrets() -> None:
    prompts = [
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_PROJECT_ID",
        "SUPABASE_DB_PASSWORD",
    ]
    for key in prompts:
        os.environ[key] = getpass.getpass(f"{key}: ")


def resolve_db_host() -> str:
    project_id = os.environ.get("SUPABASE_PROJECT_ID")
    if project_id:
        return f"db.{project_id}.supabase.co"
    return require_env("SUPABASE_DB_HOST")


def open_db_connection():
    import psycopg

    return psycopg.connect(
        host=resolve_db_host(),
        port=int(os.environ.get("SUPABASE_DB_PORT", "5432")),
        dbname=os.environ.get("SUPABASE_DB_NAME", "postgres"),
        user=os.environ.get("SUPABASE_DB_USER", "postgres"),
        password=require_env("SUPABASE_DB_PASSWORD"),
        sslmode=os.environ.get("SUPABASE_DB_SSLMODE", "require"),
    )


def apply_migration_sql(only: str | None = None) -> None:
    files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if only:
        target = MIGRATIONS_DIR / only
        if not target.exists():
            raise SystemExit(f"Migration nao encontrada: {target}")
        files = [target]
    if not files:
        raise SystemExit(f"Nenhuma migration encontrada em {MIGRATIONS_DIR}")
    connection = open_db_connection()
    try:
        with connection:
            with connection.cursor() as cursor:
                for path in files:
                    print(f"  applying {path.name}...")
                    cursor.execute(path.read_text(encoding="utf-8"))
                cursor.execute("NOTIFY pgrst, 'reload schema';")
    finally:
        connection.close()


def upsert_in_batches(client: Client, table: str, records: list[dict[str, Any]], chunk_size: int) -> None:
    for batch in chunked(records, chunk_size):
        client.table(table).upsert(batch, on_conflict="id").execute()


def fetch_count(client: Client, table: str) -> int | None:
    response = client.table(table).select("id", count="exact").limit(1).execute()
    return response.count


def fetch_rls_summary() -> list[tuple[str, bool, int]]:
    connection = open_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT c.relname, c.relrowsecurity, COUNT(p.policyname) AS policy_count
                FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                LEFT JOIN pg_policies p ON p.schemaname = n.nspname AND p.tablename = c.relname
                WHERE n.nspname = 'public'
                  AND c.relname IN ('items', 'serial_numbers', 'projetos', 'packing_list', 'movimentacoes', 'lotes')
                GROUP BY c.relname, c.relrowsecurity
                ORDER BY c.relname
                """
            )
            return [(row[0], bool(row[1]), int(row[2])) for row in cursor.fetchall()]
    finally:
        connection.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Faz seed dos JSONs no Supabase.")
    parser.add_argument("--dry-run", action="store_true", help="Nao escreve no Supabase, apenas mostra contagens.")
    parser.add_argument("--chunk-size", type=int, default=200, help="Tamanho do lote para upsert.")
    parser.add_argument("--apply-migration", action="store_true", help="Aplica todas as migrations em supabase/migrations/*.sql (em ordem) antes do seed.")
    parser.add_argument("--migration-file", type=str, default=None, help="Nome de um arquivo unico em supabase/migrations/ a aplicar (ex: 00006_rfid_infrastructure.sql). Requer --apply-migration.")
    parser.add_argument("--stdin-secrets", action="store_true", help="Le credenciais via stdin em JSON e popula o ambiente do processo.")
    parser.add_argument("--prompt-secrets", action="store_true", help="Solicita credenciais de forma interativa sem eco no terminal.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.stdin_secrets:
        load_stdin_secrets()
    if args.prompt_secrets:
        prompt_for_secrets()

    items = sanitize_records(load_json(ITEMS_PATH), ITEM_COLUMNS)
    serials = sanitize_records(load_json(SERIALS_PATH), SERIAL_COLUMNS)
    lotes = sanitize_records(load_json(LOTES_PATH), LOTE_COLUMNS)

    print(f"Itens prontos para seed: {len(items)}")
    print(f"Serial numbers prontos para seed: {len(serials)}")
    print(f"Lotes prontos para seed: {len(lotes)}")

    if args.dry_run:
        print("Dry-run ativo. Nenhuma escrita foi feita no Supabase.")
        return

    if args.apply_migration:
        print("Aplicando migrations...")
        apply_migration_sql(only=args.migration_file)
        print("Migrations aplicadas.")
    elif args.migration_file:
        raise SystemExit("--migration-file exige --apply-migration")

    client = create_supabase_client()
    upsert_in_batches(client, "items", items, args.chunk_size)
    upsert_in_batches(client, "serial_numbers", serials, args.chunk_size)
    upsert_in_batches(client, "lotes", lotes, args.chunk_size)

    item_count = fetch_count(client, "items")
    serial_count = fetch_count(client, "serial_numbers")
    lote_count = fetch_count(client, "lotes")

    print("Seed concluido.")
    print(f"Itens no banco: {item_count}")
    print(f"Serial numbers no banco: {serial_count}")
    print(f"Lotes no banco: {lote_count}")

    if os.environ.get("SUPABASE_DB_PASSWORD") and (os.environ.get("SUPABASE_PROJECT_ID") or os.environ.get("SUPABASE_DB_HOST")):
        print("Resumo RLS:")
        for table_name, rls_enabled, policy_count in fetch_rls_summary():
            print(f"- {table_name}: rls={rls_enabled} policies={policy_count}")


if __name__ == "__main__":
    main()

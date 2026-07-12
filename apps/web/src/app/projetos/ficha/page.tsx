'use client'

import Link from 'next/link'
import type { ReactNode } from 'react'

const checklistRows = [
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
  '15',
]

function Field({ label }: { label: string }) {
  return (
    <label className="field">
      <span>{label}</span>
      <input aria-label={label} />
    </label>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="section">
      <h2>{title}</h2>
      {children}
    </section>
  )
}

export default function FichaProjetoPage() {
  return (
    <div className="page-shell">
      <div className="screen-actions" aria-label="Ações da ficha">
        <Link href="/projetos">Voltar</Link>
        <button type="button" onClick={() => window.print()}>
          Imprimir PDF
        </button>
      </div>

      <main className="sheet" aria-label="Ficha Event Pro para cadastro de evento">
        <header className="header">
          <div>
            <p className="brand">Event Pro</p>
            <h1>Ficha rápida do evento</h1>
          </div>
          <p className="purpose">
            Preenchimento simples para cadastrar o evento, a operação e a checklist no sistema.
          </p>
        </header>

        <div className="form-grid">
          <div className="column">
            <Section title="1. Evento no sistema">
              <Field label="Nome do evento" />
              <Field label="Cliente ou empresa" />
              <div className="pair-grid">
                <Field label="Data inicial" />
                <Field label="Data final" />
              </div>
              <Field label="Status inicial" />
            </Section>

            <Section title="2. Endereço do evento">
              <Field label="Local, espaço ou salão" />
              <Field label="Endereço completo" />
              <div className="pair-grid">
                <Field label="Cidade e UF" />
                <Field label="Referência de acesso" />
              </div>
            </Section>
          </div>

          <div className="column">
            <Section title="3. Montagem">
              <div className="third-grid">
                <Field label="Dia" />
                <Field label="Início" />
                <Field label="Fim" />
              </div>
              <Field label="Equipe da montagem" />
              <Field label="Responsável da montagem" />
              <Field label="Telefone" />
            </Section>

            <Section title="4. Desmontagem">
              <div className="third-grid">
                <Field label="Dia" />
                <Field label="Início" />
                <Field label="Fim" />
              </div>
              <Field label="Equipe da desmontagem" />
              <Field label="Responsável da desmontagem" />
              <Field label="Telefone" />
            </Section>

            <Section title="5. Responsáveis gerais">
              <div className="pair-grid">
                <Field label="Responsável principal" />
                <Field label="Telefone" />
              </div>
              <div className="pair-grid">
                <Field label="Responsável pelo checklist" />
                <Field label="Telefone" />
              </div>
            </Section>
          </div>

          <div className="column">
            <Section title="6. Checklist do evento">
              <table>
                <thead>
                  <tr>
                    <th className="number-col">#</th>
                    <th>Item da checklist</th>
                    <th className="owner-col">Responsável</th>
                    <th className="status-col">OK</th>
                  </tr>
                </thead>
                <tbody>
                  {checklistRows.map((row) => (
                    <tr key={row}>
                      <td>{row}</td>
                      <td />
                      <td />
                      <td />
                    </tr>
                  ))}
                </tbody>
              </table>
            </Section>
          </div>
        </div>
      </main>

      <style>{`
        body {
          background: #edf0f4;
        }

        .page-shell {
          min-height: 100dvh;
          padding: 24px;
          color: #14171f;
          font-family: var(--font-sans-raw);
        }

        .screen-actions {
          width: min(100%, 1122px);
          margin: 0 auto 14px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 12px;
        }

        .screen-actions a,
        .screen-actions button {
          border: 1px solid #cfd5df;
          border-radius: 8px;
          background: #ffffff;
          color: #14171f;
          padding: 9px 13px;
          font: inherit;
          font-size: 13px;
          text-decoration: none;
          cursor: pointer;
        }

        .sheet {
          width: 1122px;
          min-height: 793px;
          margin: 0 auto;
          padding: 26px 34px;
          background: #ffffff;
          border: 1px solid #d8dde6;
          box-shadow: 0 22px 70px rgba(20, 23, 31, 0.13);
        }

        .header {
          display: grid;
          grid-template-columns: 1fr 420px;
          gap: 24px;
          align-items: end;
          padding-bottom: 10px;
          border-bottom: 3px solid #2585ff;
        }

        .brand {
          margin: 0 0 8px;
          color: #2585ff;
          font-size: 15px;
          line-height: 1;
          font-weight: 750;
          letter-spacing: 0;
        }

        h1 {
          margin: 0;
          color: #10131a;
          font-size: 26px;
          line-height: 1;
          font-weight: 720;
          letter-spacing: 0;
        }

        .purpose {
          margin: 0;
          color: #4f5968;
          font-size: 11px;
          line-height: 1.35;
        }

        .form-grid {
          display: grid;
          grid-template-columns: 0.96fr 1fr 1.08fr;
          gap: 22px;
          margin-top: 14px;
        }

        .column {
          display: grid;
          align-content: start;
          gap: 12px;
          min-width: 0;
        }

        .section {
          margin-top: 0;
        }

        h2 {
          margin: 0 0 10px;
          color: #10131a;
          font-size: 13px;
          line-height: 1.1;
          font-weight: 760;
          letter-spacing: 0;
        }

        .field {
          display: grid;
          gap: 4px;
          min-width: 0;
        }

        .field + .field,
        .pair-grid + .field,
        .third-grid + .field {
          margin-top: 8px;
        }

        .field span {
          color: #566171;
          font-size: 8px;
          line-height: 1;
          font-weight: 720;
          letter-spacing: 0.18px;
          text-transform: uppercase;
        }

        input,
        textarea {
          width: 100%;
          border: 1px solid #aeb6c4;
          border-radius: 7px;
          background: #ffffff;
          color: #10131a;
          padding: 6px 8px;
          font: inherit;
          font-size: 12px;
          outline: none;
        }

        input {
          height: 28px;
        }

        .pair-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
        }

        .third-grid {
          display: grid;
          grid-template-columns: 1fr 0.75fr 0.75fr;
          gap: 8px;
        }

        table {
          width: 100%;
          border-collapse: collapse;
          table-layout: fixed;
        }

        th,
        td {
          border: 1px solid #9fa8b7;
          text-align: left;
          vertical-align: middle;
        }

        th {
          height: 28px;
          padding: 5px 7px;
          background: #f2f6ff;
          color: #222936;
          font-size: 8px;
          line-height: 1;
          font-weight: 760;
          text-transform: uppercase;
          letter-spacing: 0.18px;
        }

        td {
          height: 29px;
          padding: 5px 7px;
          color: #222936;
          font-size: 12px;
        }

        .number-col {
          width: 36px;
        }

        .owner-col {
          width: 132px;
        }

        .status-col {
          width: 44px;
          text-align: center;
        }

        tbody td:first-child,
        tbody td:last-child {
          text-align: center;
          color: #566171;
          font-weight: 650;
        }

        @media screen and (max-width: 1160px) {
          .sheet {
            width: 100%;
            min-height: auto;
          }

          .header,
          .form-grid,
          .pair-grid,
          .third-grid {
            grid-template-columns: 1fr;
          }
        }

        @media print {
          @page {
            size: A4 landscape;
            margin: 7mm;
          }

          html,
          body {
            width: auto !important;
            height: auto !important;
            min-height: 0 !important;
            margin: 0 !important;
            padding: 0 !important;
            background: #ffffff !important;
          }

          body > div {
            display: block !important;
            height: auto !important;
            min-height: auto !important;
            overflow: visible !important;
          }

          nav[aria-label='Navegação principal'],
          .skip-link {
            display: none !important;
          }

          #main-content {
            display: block !important;
            overflow: visible !important;
            padding: 0 !important;
          }

          .screen-actions {
            display: none !important;
          }

          .page-shell {
            min-height: 0;
            padding: 0;
            background: #ffffff !important;
          }

          .sheet {
            width: 283mm;
            min-height: 0;
            margin: 0;
            padding: 6mm;
            border: 0;
            box-shadow: none;
            print-color-adjust: exact;
            -webkit-print-color-adjust: exact;
          }
        }
      `}</style>
    </div>
  )
}

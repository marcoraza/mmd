export const MAX_MCP_BODY_BYTES = 128 * 1024

export class McpRequestTooLargeError extends Error {}

export function asPlainMcpRequest(request: Request) {
  const hasBody = request.method !== 'GET' && request.method !== 'HEAD' && request.body
  return new Request(request.url, {
    method: request.method,
    headers: new Headers(request.headers),
    body: hasBody ? request.body : undefined,
    signal: request.signal,
    ...(hasBody ? { duplex: 'half' } : {}),
  } as RequestInit)
}

export async function enforceMcpRequestBodyLimit(request: Request) {
  if (request.method === 'GET' || request.method === 'HEAD' || !request.body) return request

  const contentLength = Number(request.headers.get('content-length') ?? '0')
  if (Number.isFinite(contentLength) && contentLength > MAX_MCP_BODY_BYTES) {
    throw new McpRequestTooLargeError()
  }

  const reader = request.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  try {
    while (true) {
      const next = await reader.read()
      if (next.done) break
      total += next.value.byteLength
      if (total > MAX_MCP_BODY_BYTES) throw new McpRequestTooLargeError()
      chunks.push(next.value)
    }
  } finally {
    reader.releaseLock()
  }

  const body = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    body.set(chunk, offset)
    offset += chunk.byteLength
  }
  return new Request(request, { body: total ? body : undefined })
}

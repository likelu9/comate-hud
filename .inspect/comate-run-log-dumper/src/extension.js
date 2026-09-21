/**
 * Comate run lifecycle log dumper — Pi ExtensionFactory
 *
 * Writes one JSONL log file per run into:
 *   ~/Documents/WPSComate/logs/<runId>.log
 *
 * Export contract (SDK P0):
 *   export function createExtension(ctx) -> ExtensionFactory
 */
import { appendFile, mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { homedir } from 'node:os'
import { randomUUID } from 'node:crypto'

const LOG_DIR = join(homedir(), 'Documents', 'WPSComate', 'logs')
const UNKNOWN_RUN_ID = 'unknown-run'
const MAX_TEXT_CHARS = 16000
const MAX_ARG_CHARS = 32000
const DEFAULT_CONTEXT_WINDOW = 200000

/**
 * @param {import('@ks-comate/comate-agent-sdk').PluginExtensionLoadContext} ctx
 * @returns {import('@earendil-works/pi-coding-agent').ExtensionFactory}
 */
export function createExtension(ctx) {
  let seq = 0
  let activeRunId = undefined
  let activeRunIdSource = undefined
  let activeCorrelationId = randomUUID()
  let lastRequest = undefined
  const writeChains = new Map()

  /** @param {unknown[]} values */
  function resolveRun(values) {
    for (const value of values) {
      const found = findRunId(value)
      if (found) return found
    }
    if (activeRunId) return { runId: activeRunId, source: activeRunIdSource ?? 'active' }
    return { runId: UNKNOWN_RUN_ID, source: 'fallback' }
  }

  /** @param {string} runId */
  function fileNameForRun(runId) {
    return `${String(runId).replace(/[^a-zA-Z0-9._-]/g, '_')}.log`
  }

  /** @param {string} runId @param {Record<string, unknown>} line */
  function append(runId, line) {
    const previous = writeChains.get(runId) ?? Promise.resolve()
    const next = previous.then(async () => {
      await mkdir(LOG_DIR, { recursive: true })
      await appendFile(join(LOG_DIR, fileNameForRun(runId)), `${safeStringify(line)}\n`, 'utf8')
    }).catch((err) => {
      console.warn(
        '[comate-run-log-dumper] write failed:',
        err instanceof Error ? err.message : err,
      )
    })
    writeChains.set(runId, next)
  }

  /** @param {string} type @param {unknown[]} sources @param {Record<string, unknown>} data */
  function log(type, sources, data = {}) {
    const run = resolveRun(sources)
    if (run.runId !== UNKNOWN_RUN_ID) {
      activeRunId = run.runId
      activeRunIdSource = run.source
    }
    seq += 1
    append(run.runId, {
      ts: new Date().toISOString(),
      seq,
      type,
      runId: run.runId,
      runIdSource: run.source,
      correlationId: activeCorrelationId,
      pluginId: ctx.pluginId,
      agentId: ctx.agentId,
      ...data,
    })
  }

  return (pi) => {
    pi.on('session_start', (event, piCtx) => {
      activeCorrelationId = randomUUID()
      log('session_start', [event, piCtx], {
        reason: event?.reason,
        session: summarizeSession(event, piCtx),
      })
    })

    pi.on('before_agent_start', (event, piCtx) => {
      activeCorrelationId = randomUUID()
      log('run_start', [event, piCtx], {
        source: 'pi:before_agent_start',
        event: summarizeObject(event),
      })
    })

    pi.on('before_provider_request', (event, piCtx) => {
      const requestSeq = seq + 1
      const correlationId = randomUUID()
      activeCorrelationId = correlationId
      lastRequest = { correlationId, requestSeq, ts: new Date().toISOString() }
      const model = extractModel(event?.payload, piCtx)
      const userMessages = extractUserMessages(event?.payload)
      for (const message of userMessages) {
        log('user_message', [event, piCtx, event?.payload], {
          source: 'pi:before_provider_request',
          requestSeq,
          requestCorrelationId: correlationId,
          message,
        })
      }
      log('model_request_start', [event, piCtx, event?.payload], {
        source: 'pi:before_provider_request',
        requestSeq,
        requestCorrelationId: correlationId,
        model,
        context: estimateContextFromProviderPayload(event?.payload, piCtx),
        userMessageCount: userMessages.length,
        payload: summarizeProviderPayload(event?.payload),
      })
    })

    pi.on('after_provider_response', (event, piCtx) => {
      log('model_request_end', [event, piCtx], {
        source: 'pi:after_provider_response',
        requestSeq: lastRequest?.requestSeq,
        requestCorrelationId: lastRequest?.correlationId,
        status: event?.status,
        headers: summarizeHeaders(event?.headers),
      })
    })

    pi.on('message_end', (event, piCtx) => {
      const message = event?.message
      if (isUpdateMessage(message)) return
      const m = isRecord(message) ? message : undefined
      log('assistant_message', [event, piCtx, message], {
        source: 'pi:message_end',
        role: m?.role,
        model: m?.model,
        stopReason: m?.stopReason,
        usage: m?.usage,
        content: summarizeContent(m?.content),
      })
    })

    pi.on('turn_end', (event, piCtx) => {
      const message = event?.message
      if (isUpdateMessage(message)) return
      const m = isRecord(message) ? message : undefined
      log('turn_end', [event, piCtx, message], {
        source: 'pi:turn_end',
        role: m?.role,
        model: m?.model,
        stopReason: m?.stopReason,
        usage: m?.usage,
        finalMessage: summarizeContent(m?.content),
      })
    })

    pi.on('tool_call', (event, piCtx) => {
      log('tool_call', [event, piCtx], {
        source: 'pi:tool_call',
        tool: event?.toolName ?? event?.name,
        toolCallId: event?.toolCallId ?? event?.id,
        input: truncateJson(event?.input ?? event?.arguments ?? event?.args, MAX_ARG_CHARS),
      })
    })

    pi.on('tool_result', (event, piCtx) => {
      log('tool_result', [event, piCtx], {
        source: 'pi:tool_result',
        tool: event?.toolName ?? event?.name,
        toolCallId: event?.toolCallId ?? event?.id,
        isError: event?.isError,
        result: truncateJson(event?.result ?? event?.output ?? event?.content, MAX_ARG_CHARS),
      })
    })

    pi.on('session_before_compact', (event, piCtx) => {
      log('context_compaction_start', [event, piCtx], {
        source: 'pi:session_before_compact',
        before: estimateCompactionInput(event, piCtx),
      })
    })

    pi.on('session_compact', (event, piCtx) => {
      log('context_compaction_end', [event, piCtx], {
        source: 'pi:session_compact',
        after: estimateCompactionOutput(event, piCtx),
      })
    })

    pi.on('session_shutdown', (event, piCtx) => {
      log('session_shutdown', [event, piCtx], {
        source: 'pi:session_shutdown',
        event: summarizeObject(event),
      })
      activeRunId = undefined
      activeRunIdSource = undefined
      lastRequest = undefined
    })
  }
}

/** @param {unknown} value */
function isRecord(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value)
}

/** @param {unknown} value */
function findRunId(value) {
  if (!isRecord(value)) return undefined
  const record = /** @type {Record<string, unknown>} */ (value)
  const directKeys = ['runId', 'run_id', 'id']
  for (const key of directKeys) {
    const raw = record[key]
    if (typeof raw === 'string' && looksLikeRunId(raw)) return { runId: raw, source: key }
  }
  const nestedKeys = ['run', 'context', 'ctx', 'metadata', 'meta', 'payload', 'request', 'session']
  for (const key of nestedKeys) {
    const nested = record[key]
    if (isRecord(nested)) {
      const found = findRunId(nested)
      if (found) return { runId: found.runId, source: `${key}.${found.source}` }
    }
  }
  return undefined
}

/** @param {string} value */
function looksLikeRunId(value) {
  if (!value || value === 'undefined' || value === 'null') return false
  return value.length >= 6 && value.length <= 160
}

/** @param {unknown} value */
function safeStringify(value) {
  return JSON.stringify(value, (_key, nested) => {
    if (typeof nested === 'bigint') return nested.toString()
    if (nested instanceof Error) return { name: nested.name, message: nested.message, stack: nested.stack }
    return nested
  })
}

/** @param {unknown} value @param {number} max */
function truncateJson(value, max) {
  if (value == null) return value
  const text = typeof value === 'string' ? value : safeStringify(value)
  if (text.length <= max) return value
  return { truncated: true, chars: text.length, preview: text.slice(0, max) }
}

/** @param {unknown} content */
function summarizeContent(content) {
  if (typeof content === 'string') return truncateText(content, MAX_TEXT_CHARS)
  if (!Array.isArray(content)) return truncateJson(content, MAX_TEXT_CHARS)
  return content
    .filter((block) => !isUpdateMessage(block))
    .map((block) => {
      if (!isRecord(block)) return truncateJson(block, MAX_TEXT_CHARS)
      const b = /** @type {Record<string, unknown>} */ (block)
      const type = b.type
      if (type === 'toolCall' || type === 'tool_use') {
        return {
          type,
          id: b.id,
          name: b.name,
          arguments: truncateJson(b.arguments ?? b.input, MAX_ARG_CHARS),
        }
      }
      if (typeof b.text === 'string') return { ...b, text: truncateText(b.text, MAX_TEXT_CHARS) }
      if (typeof b.content === 'string') return { ...b, content: truncateText(b.content, MAX_TEXT_CHARS) }
      return truncateJson(b, MAX_TEXT_CHARS)
    })
}

/** @param {unknown} message */
function isUpdateMessage(message) {
  if (!isRecord(message)) return false
  const m = /** @type {Record<string, unknown>} */ (message)
  return m.type === 'update' || m.event === 'update' || m.kind === 'update' || m.delta != null
}

/** @param {string} text @param {number} max */
function truncateText(text, max) {
  if (text.length <= max) return text
  return { truncated: true, chars: text.length, preview: text.slice(0, max) }
}

/** @param {unknown} payload @param {unknown} piCtx */
function extractModel(payload, piCtx) {
  const fromPayload = modelFromRecord(payload)
  const fromCtx = modelFromRecord(piCtx)
  return {
    id: fromPayload.id ?? fromCtx.id,
    provider: fromPayload.provider ?? fromCtx.provider,
    contextWindow: fromPayload.contextWindow ?? fromCtx.contextWindow,
  }
}

/** @param {unknown} value */
function modelFromRecord(value) {
  if (!isRecord(value)) return {}
  const data = /** @type {Record<string, unknown>} */ (value)
  const model = data.model
  if (isRecord(model)) {
    const m = /** @type {Record<string, unknown>} */ (model)
    return {
      id: stringValue(m.id) ?? stringValue(m.name) ?? stringValue(data.modelId),
      provider: stringValue(m.provider) ?? stringValue(data.provider),
      contextWindow: numberValue(m.contextWindow) ?? numberValue(m.context_window),
    }
  }
  return {
    id: stringValue(data.modelId) ?? stringValue(data.model),
    provider: stringValue(data.provider),
    contextWindow: numberValue(data.contextWindow) ?? numberValue(data.context_window),
  }
}

/** @param {unknown} value */
function stringValue(value) {
  return typeof value === 'string' ? value : undefined
}

/** @param {unknown} value */
function numberValue(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

/** @param {unknown} payload */
function extractUserMessages(payload) {
  if (!isRecord(payload)) return []
  const messages = /** @type {Record<string, unknown>} */ (payload).messages
  if (!Array.isArray(messages)) return []
  return messages
    .filter((message) => isRecord(message) && message.role === 'user')
    .map((message) => {
      const m = /** @type {Record<string, unknown>} */ (message)
      return {
        role: m.role,
        content: summarizeContent(m.content),
      }
    })
}

/** @param {unknown} payload */
function summarizeProviderPayload(payload) {
  if (!isRecord(payload)) return truncateJson(payload, MAX_TEXT_CHARS)
  const data = /** @type {Record<string, unknown>} */ (payload)
  return {
    model: extractModel(payload),
    messageCount: Array.isArray(data.messages) ? data.messages.length : undefined,
    toolCount: Array.isArray(data.tools) ? data.tools.length : undefined,
    temperature: data.temperature,
    topP: data.top_p ?? data.topP,
    maxTokens: data.max_tokens ?? data.maxTokens,
  }
}

/** @param {unknown} headers */
function summarizeHeaders(headers) {
  if (!isRecord(headers)) return headers
  const allowed = ['content-type', 'x-request-id', 'x-comate-request-id', 'trace-id']
  const out = {}
  for (const [key, value] of Object.entries(headers)) {
    if (allowed.includes(key.toLowerCase())) out[key] = value
  }
  return out
}

/** @param {unknown} payload @param {unknown} piCtx */
function estimateContextFromProviderPayload(payload, piCtx) {
  const sessionUsage = readContextUsage(piCtx)
  if (!isRecord(payload)) return sessionUsage ? { session: sessionUsage } : undefined
  const data = /** @type {Record<string, unknown>} */ (payload)
  const messages = Array.isArray(data.messages) ? data.messages : []
  const tools = Array.isArray(data.tools) ? data.tools : []
  const systemChars = typeof data.system === 'string' ? data.system.length : safeJsonLength(data.system)
  const messagesChars = messages.reduce((sum, item) => sum + contentChars(item), 0)
  const toolsChars = safeJsonLength(tools)
  const totalChars = systemChars + messagesChars + toolsChars
  const tokens = Math.ceil(totalChars / 4)
  const model = extractModel(payload, piCtx)
  const contextWindow = model.contextWindow ?? sessionUsage?.contextWindow ?? DEFAULT_CONTEXT_WINDOW
  return {
    tokens,
    chars: totalChars,
    contextWindow,
    percent: contextWindow > 0 ? Number(((tokens / contextWindow) * 100).toFixed(2)) : undefined,
    systemChars,
    messagesChars,
    toolsChars,
    messagesCount: messages.length,
    toolsCount: tools.length,
    session: sessionUsage,
  }
}

/** @param {unknown} piCtx */
function readContextUsage(piCtx) {
  if (!isRecord(piCtx)) return undefined
  const get = /** @type {{ getContextUsage?: () => unknown }} */ (piCtx).getContextUsage
  if (typeof get !== 'function') return undefined
  try {
    const usage = get.call(piCtx)
    return isRecord(usage) ? usage : undefined
  } catch {
    return undefined
  }
}

/** @param {unknown} value */
function contentChars(value) {
  if (typeof value === 'string') return value.length
  if (Array.isArray(value)) return value.reduce((sum, item) => sum + contentChars(item), 0)
  if (!isRecord(value)) return safeJsonLength(value)
  const data = /** @type {Record<string, unknown>} */ (value)
  let chars = 0
  if (typeof data.content === 'string') chars += data.content.length
  else chars += contentChars(data.content)
  if (typeof data.text === 'string') chars += data.text.length
  if (typeof data.thinking === 'string') chars += data.thinking.length
  if (data.arguments != null) chars += safeJsonLength(data.arguments)
  if (data.input != null) chars += safeJsonLength(data.input)
  return chars || safeJsonLength(value)
}

/** @param {unknown} value */
function safeJsonLength(value) {
  if (value == null) return 0
  try { return safeStringify(value).length } catch { return 0 }
}

/** @param {unknown} event @param {unknown} piCtx */
function estimateCompactionInput(event, piCtx) {
  const usage = readContextUsage(piCtx)
  const preparation = isRecord(event) ? event.preparation : undefined
  const messagesToSummarize = isRecord(preparation) ? preparation.messagesToSummarize : undefined
  return {
    contextUsage: usage,
    messagesToSummarizeCount: Array.isArray(messagesToSummarize) ? messagesToSummarize.length : undefined,
    messagesToSummarizeChars: Array.isArray(messagesToSummarize) ? safeJsonLength(messagesToSummarize) : undefined,
    preparation: summarizeObject(preparation),
  }
}

/** @param {unknown} event @param {unknown} piCtx */
function estimateCompactionOutput(event, piCtx) {
  const usage = readContextUsage(piCtx)
  if (!isRecord(event)) return { contextUsage: usage }
  const data = /** @type {Record<string, unknown>} */ (event)
  const messages = Array.isArray(data.messages) ? data.messages : undefined
  return {
    contextUsage: usage,
    tokensBefore: data.tokensBefore,
    tokensAfter: data.tokensAfter,
    messagesCount: messages?.length,
    messagesChars: messages ? safeJsonLength(messages) : undefined,
    fromExtension: data.fromExtension,
  }
}

/** @param {unknown} event @param {unknown} piCtx */
function summarizeSession(event, piCtx) {
  return {
    event: summarizeObject(event),
    context: summarizeObject(piCtx),
  }
}

/** @param {unknown} value */
function summarizeObject(value) {
  if (!isRecord(value)) return value
  const out = {}
  for (const [key, nested] of Object.entries(value)) {
    if (typeof nested === 'function') continue
    if (key === 'messages' || key === 'payload') continue
    out[key] = truncateJson(nested, MAX_TEXT_CHARS)
  }
  return out
}

import type { GuessHistoryEntry, FeedbackDot, Tone, GameModeRow, MatchRow, ActiveMatchCard, ModeCard } from './types'

const modeTones: Array<ModeCard['tone']> = ['primary', 'secondary', 'tertiary']

const symbolToneMap: Record<string, Tone> = {
  circle: 'primary',
  pentagon: 'secondary',
  square: 'tertiary',
  change_history: 'error',
  star: 'neutral',
  diamond: 'neutral',
}

export function normalizeGuessRow(payload: unknown): string[] {
  if (!payload || typeof payload !== 'object') return []

  const maybeRow = (payload as { row?: unknown }).row
  if (!Array.isArray(maybeRow)) return []

  return maybeRow.map((item) => String(item ?? '?'))
}

export function toneForSymbol(symbol: string): Tone {
  return symbolToneMap[symbol] ?? 'neutral'
}

export function feedbackDots(exactHits: number, partialHits: number): FeedbackDot[] {
  const blacks = Array(Math.max(0, exactHits)).fill('black') as FeedbackDot[]
  const whites = Array(Math.max(0, partialHits)).fill('white') as FeedbackDot[]
  const empties = Array(Math.max(0, 4 - exactHits - partialHits)).fill('empty') as FeedbackDot[]

  return [...blacks, ...whites, ...empties].slice(0, 4)
}

export function buildModeCards(modes: GameModeRow[]): ModeCard[] {
  return (modes ?? [])
    .filter((mode) => mode.code?.includes('async') || mode.code?.includes('classic') || mode.code?.includes('duel'))
    .map((mode, index): ModeCard => ({
      modeId: mode.id,
      code: mode.code,
      icon: 'extension',
      title: mode.title,
      description: mode.short_description ?? '',
      cta: 'Jouer',
      tone: modeTones[index % modeTones.length],
      route: 'async',
      queueType: mode.code?.includes('duel') ? 'duel' : 'solo',
    }))
}

export function buildActiveMatches(matches: Array<MatchRow | MatchRow[]>, modes: GameModeRow[]): ActiveMatchCard[] {
  const modeById = new Map((modes ?? []).map((mode) => [mode.id, mode.title]))

  const normalizedMatches = (matches ?? [])
    .map((match) => (Array.isArray(match) ? match[0] : match))
    .filter((match): match is MatchRow => Boolean(match?.id))

  return normalizedMatches.map((match): ActiveMatchCard => {
    const maxTurns = match.max_turns || 1
    const turnNumber = match.turn_number || 1
    const progress = Math.max(0, Math.min(100, Math.round((turnNumber / maxTurns) * 100)))
    const isDone = match.state === 'completed' || match.state === 'canceled' || match.state === 'expired'
    const isWaiting = match.state === 'waiting_turn' || match.state === 'waiting_opponent'

    return {
      id: match.id,
      name: `Partie ${match.id.slice(0, 8)}`,
      mode: modeById.get(match.mode_id) ?? 'Mode',
      tries: `${turnNumber}/${maxTurns}`,
      progress,
      status: isDone ? 'Terminee' : isWaiting ? 'En attente' : 'A votre tour',
      state: match.state,
      maxTurns,
      turnNumber,
      createdByUserId: match.created_by_user_id,
    }
  })
}

type GuessRow = {
  id: string
  payload: unknown
  exact_hits: number
  partial_hits: number
  is_win: boolean
  created_at: string
}

export function buildGuessHistory(guesses: GuessRow[]): GuessHistoryEntry[] {
  return guesses.map((guess) => ({
    id: guess.id,
    row: normalizeGuessRow(guess.payload),
    exactHits: guess.exact_hits,
    partialHits: guess.partial_hits,
    isWin: guess.is_win,
    createdAt: guess.created_at,
  }))
}

export function getErrorMessage(error: unknown, fallback: string): string {
  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string' && message.trim()) return message
  }

  return fallback
}

export async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, fallback: T): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | null = null

  try {
    return await Promise.race([
      promise,
      new Promise<T>((resolve) => {
        timer = setTimeout(() => resolve(fallback), timeoutMs)
      }),
    ])
  } finally {
    if (timer) clearTimeout(timer)
  }
}

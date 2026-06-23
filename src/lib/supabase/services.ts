import type { Session, User } from '@supabase/supabase-js'
import { supabase } from './client'

export type AuthPayload = {
  user: User | null
  session: Session | null
}

export type UserProfile = {
  id: string
  handle: string | null
  credits: number
  rank_tier: string | null
}

export type GameMode = {
  id: string
  code: string
  title: string
  short_description: string | null
  sort_order: number
}

export type DailyChallenge = {
  id: string
  challenge_date: string
  title: string
  description: string | null
  reward_credits: number
  difficulty: string | null
}

export type MatchSummary = {
  id: string
  state: string
  turn_number: number
  max_turns: number
  mode_id: string
  updated_at: string | null
}

type SignUpParams = {
  email: string
  password: string
  handle: string
}

type SignInParams = {
  email: string
  password: string
}

type UpdateProfileParams = {
  handle: string
}

type CreateMatchParams = {
  modeId: string
  maxTurns?: number
}

type SubmitGuessParams = {
  matchId: string
  payload: Record<string, unknown>
}

function isMissingSessionError(error: unknown): boolean {
  if (!error || typeof error !== 'object' || !('message' in error)) return false
  const message = (error as { message?: unknown }).message
  return typeof message === 'string' && /auth session missing/i.test(message)
}

export async function fetchCurrentUser(): Promise<User | null> {
  if (!supabase) return null

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()

  if (error) {
    if (isMissingSessionError(error)) return null
    throw error
  }

  return user
}

export async function signUpWithEmail({ email, password, handle }: SignUpParams): Promise<AuthPayload> {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        handle,
      },
    },
  })

  if (error) throw error
  return { user: data.user, session: data.session }
}

export async function signInWithEmail({ email, password }: SignInParams): Promise<AuthPayload> {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) throw error
  return { user: data.user, session: data.session }
}

export async function signOutCurrentUser(): Promise<void> {
  if (!supabase) return

  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function fetchActiveGameModes(): Promise<GameMode[]> {
  if (!supabase) return []

  const { data, error } = await supabase
    .from('game_modes')
    .select('id, code, title, short_description, sort_order')
    .eq('is_enabled', true)
    .order('sort_order', { ascending: true })

  if (error) throw error
  return (data ?? []) as GameMode[]
}

export async function fetchDailyChallenge(): Promise<DailyChallenge | null> {
  if (!supabase) return null

  const { data, error } = await supabase
    .from('daily_challenges')
    .select('id, challenge_date, title, description, reward_credits, difficulty')
    .eq('is_active', true)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as DailyChallenge | null
}

export async function fetchMyProfile(): Promise<UserProfile | null> {
  if (!supabase) return null

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) {
    if (isMissingSessionError(authError)) return null
    throw authError
  }
  if (!user) return null

  const { data, error } = await supabase
    .from('user_profiles')
    .select('id, handle, credits, rank_tier')
    .eq('id', user.id)
    .maybeSingle()

  if (error) throw error
  return (data ?? null) as UserProfile | null
}

export async function updateMyProfile({ handle }: UpdateProfileParams): Promise<UserProfile> {
  if (!supabase) throw new Error('Supabase is not configured')

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) throw authError
  if (!user) throw new Error('Authentication required')

  const cleanHandle = (handle ?? '').trim().toLowerCase().replace(/[^a-z0-9_]/g, '')
  if (!cleanHandle) throw new Error('Handle invalide')

  const { data, error } = await supabase
    .from('user_profiles')
    .update({ handle: cleanHandle })
    .eq('id', user.id)
    .select('id, handle, credits, rank_tier')
    .single()

  if (error) throw error
  return data as UserProfile
}

export async function fetchMyMatches(): Promise<MatchSummary[]> {
  if (!supabase) return []

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) {
    if (isMissingSessionError(authError)) return []
    throw authError
  }
  if (!user) return []

  const { data, error } = await supabase
    .from('match_players')
    .select('match_id, matches(id, state, turn_number, max_turns, mode_id, updated_at)')
    .eq('user_id', user.id)

  if (error) throw error

  const rows = (data ?? []) as Array<{ matches: MatchSummary | MatchSummary[] | null }>

  return rows
    .map((row) => (Array.isArray(row.matches) ? row.matches[0] : row.matches))
    .filter((match): match is MatchSummary => Boolean(match?.id))
}

export async function createMatch({ modeId, maxTurns = 10 }: CreateMatchParams): Promise<{ id: string } & Record<string, unknown>> {
  if (!supabase) throw new Error('Supabase is not configured')

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) throw authError
  if (!user) throw new Error('Authentication required')

  const idempotencyKey = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`

  const { data: match, error: matchError } = await supabase.rpc('create_match', {
    p_mode_id: modeId,
    p_max_turns: maxTurns,
    p_idempotency_key: idempotencyKey,
  })

  if (matchError) throw matchError
  return match as { id: string } & Record<string, unknown>
}

export async function submitGuess({ matchId, payload }: SubmitGuessParams): Promise<Record<string, unknown>> {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.rpc('submit_guess', {
    p_match_id: matchId,
    p_payload: payload ?? {},
  })

  if (error) throw error
  return (data ?? {}) as Record<string, unknown>
}

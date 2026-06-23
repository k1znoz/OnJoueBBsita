import { supabase } from './client'

export async function fetchCurrentUser() {
  if (!supabase) return null

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()

  if (error) throw error
  return user
}

export async function signUpWithEmail({ email, password, handle }) {
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
  return data
}

export async function signInWithEmail({ email, password }) {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) throw error
  return data
}

export async function signOutCurrentUser() {
  if (!supabase) return

  const { error } = await supabase.auth.signOut()
  if (error) throw error
}

export async function fetchActiveGameModes() {
  if (!supabase) return []

  const { data, error } = await supabase
    .from('game_modes')
    .select('id, code, title, short_description, sort_order')
    .eq('is_enabled', true)
    .order('sort_order', { ascending: true })

  if (error) throw error
  return data ?? []
}

export async function fetchDailyChallenge() {
  if (!supabase) return null

  const { data, error } = await supabase
    .from('daily_challenges')
    .select('id, challenge_date, title, description, reward_credits, difficulty')
    .eq('is_active', true)
    .maybeSingle()

  if (error) throw error
  return data
}

export async function fetchMyProfile() {
  if (!supabase) return null

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) throw authError
  if (!user) return null

  const { data, error } = await supabase
    .from('user_profiles')
    .select('id, handle, credits, rank_tier')
    .eq('id', user.id)
    .maybeSingle()

  if (error) throw error
  return data
}

export async function updateMyProfile({ handle }) {
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
  return data
}

export async function fetchMyMatches() {
  if (!supabase) return []

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError) throw authError
  if (!user) return []

  const { data, error } = await supabase
    .from('match_players')
    .select('match_id, matches(id, state, turn_number, max_turns, mode_id, updated_at)')
    .eq('user_id', user.id)

  if (error) throw error

  return (data ?? []).map((row) => row.matches).filter(Boolean)
}

export async function createMatch({ modeId, maxTurns = 10 }) {
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
  return match
}

export async function submitGuess({ matchId, payload }) {
  if (!supabase) throw new Error('Supabase is not configured')

  const { data, error } = await supabase.rpc('submit_guess', {
    p_match_id: matchId,
    p_payload: payload ?? {},
  })

  if (error) throw error
  return data
}

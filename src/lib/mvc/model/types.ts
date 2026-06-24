export type View = 'lobby' | 'modes' | 'async' | 'communication' | 'auth' | 'profile'

export type Tone = 'primary' | 'secondary' | 'tertiary' | 'error' | 'neutral'
export type FeedbackDot = 'black' | 'white' | 'empty'

export type PalettePeg = {
  symbol: string
  tone: Tone
}

export type GameModeRow = {
  id: string
  code: string
  title: string
  short_description: string | null
  sort_order: number
}

export type ModeCard = {
  modeId: string
  code: string
  icon: string
  title: string
  description: string
  cta: string
  tone: 'primary' | 'secondary' | 'tertiary'
  route: 'async' | null
  intense?: boolean
  queueType: 'solo' | 'duel'
}

export type MatchRow = {
  id: string
  state: string
  turn_number: number | null
  max_turns: number | null
  mode_id: string
  created_by_user_id: string
  updated_at: string | null
}

export type ActiveMatchCard = {
  id: string
  name: string
  mode: string
  tries: string
  progress: number
  status: 'En attente' | 'A votre tour' | 'Terminee'
  state: string
  maxTurns: number
  turnNumber: number
  createdByUserId: string
}

export type OpponentCandidate = {
  id: string
  handle: string
}

export type DuelInvitation = {
  match_id: string
  mode_id: string
  mode_title: string
  inviter_id: string
  inviter_handle: string
  created_at: string
}

export type PlayerMessage = {
  id: string
  sender_user_id: string
  recipient_user_id: string
  body: string
  created_at: string
}

export type GuessHistoryEntry = {
  id: string
  row: string[]
  exactHits: number
  partialHits: number
  isWin: boolean
  createdAt: string
}

export type DailyChallengeRow = {
  id: string
  challenge_date: string
  title: string
  description: string | null
  reward_credits: number
  difficulty: string | null
}

export type UserProfile = {
  id: string
  handle: string | null
  credits: number
  rank_tier: string | null
}

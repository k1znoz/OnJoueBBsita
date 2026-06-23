<script lang="ts">
  import { onMount } from 'svelte'
  import type { User } from '@supabase/supabase-js'
  import {
    acceptDuelInvite,
    createDuelInvite,
    createMatch,
    fetchCurrentUser,
    fetchActiveGameModes,
    fetchDailyChallenge,
    fetchDuelInvitations,
    fetchMatchGuesses,
    fetchMessagesWithUser,
    fetchOpponentCandidates,
    joinOrCreateDuel,
    fetchMyMatches,
    fetchMyProfile,
    signInWithEmail,
    signOutCurrentUser,
    signUpWithEmail,
    sendPlayerMessage,
    submitGuess,
    updateMyProfile,
  } from './lib/supabase/services'
  import { hasSupabaseConfig, supabase } from './lib/supabase/client'

  type View = 'lobby' | 'modes' | 'async' | 'communication' | 'auth' | 'profile'

  type Tone = 'primary' | 'secondary' | 'tertiary' | 'error' | 'neutral'

  type PalettePeg = {
    symbol: string
    tone: Tone
  }

  type GameModeRow = {
    id: string
    code: string
    title: string
    short_description: string | null
    sort_order: number
  }

  type ModeCard = {
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

  type MatchRow = {
    id: string
    state: string
    turn_number: number | null
    max_turns: number | null
    mode_id: string
    created_by_user_id: string
    updated_at: string | null
  }

  type ActiveMatchCard = {
    id: string
    name: string
    mode: string
    tries: string
    progress: number
    status: 'En attente' | 'A votre tour'
    state: string
    maxTurns: number
    turnNumber: number
    createdByUserId: string
  }

  type OpponentCandidate = {
    id: string
    handle: string
  }

  type DuelInvitation = {
    match_id: string
    mode_id: string
    mode_title: string
    inviter_id: string
    inviter_handle: string
    created_at: string
  }

  type PlayerMessage = {
    id: string
    sender_user_id: string
    recipient_user_id: string
    body: string
    created_at: string
  }

  type GuessHistoryEntry = {
    id: string
    row: string[]
    exactHits: number
    partialHits: number
    isWin: boolean
    createdAt: string
  }

  type DailyChallengeRow = {
    id: string
    challenge_date: string
    title: string
    description: string | null
    reward_credits: number
    difficulty: string | null
  }

  type UserProfile = {
    id: string
    handle: string | null
    credits: number
    rank_tier: string | null
  }

  const modeTones: Array<ModeCard['tone']> = ['primary', 'secondary', 'tertiary']

  function getErrorMessage(error: unknown, fallback: string): string {
    if (error && typeof error === 'object' && 'message' in error) {
      const message = (error as { message?: unknown }).message
      if (typeof message === 'string' && message.trim()) return message
    }

    return fallback
  }

  async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, fallback: T): Promise<T> {
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

  let modeCards: ModeCard[] = []
  let activeMatches: ActiveMatchCard[] = []
  let opponentCandidates: OpponentCandidate[] = []
  let duelInvitations: DuelInvitation[] = []
  let selectedChatUserId = ''
  let chatMessages: PlayerMessage[] = []
  let chatInput = ''
  let communicationLoading = false
  let sendingMessage = false
  let selectedOpponentId = ''
  let duelLoading = false

  const asyncPalette: PalettePeg[] = [
    { symbol: 'circle', tone: 'primary' },
    { symbol: 'pentagon', tone: 'secondary' },
    { symbol: 'square', tone: 'tertiary' },
    { symbol: 'change_history', tone: 'error' },
    { symbol: 'star', tone: 'neutral' },
    { symbol: 'diamond', tone: 'neutral' },
  ]

  let currentView: View = 'lobby'
  let currentMatchId: string | null = null
  let dailyChallenge: DailyChallengeRow | null = null
  let currentUser: User | null = null
  let myProfile: UserProfile | null = null
  let isLoading = true
  let authLoading = false
  let signOutLoading = false
  let profileSaving = false
  let coins = 0
  let toast = ''

  let authEmail = ''
  let authPassword = ''
  let authHandle = ''
  let profileHandle = ''

  let asyncRow: Array<PalettePeg | null> = [null, null, null, null]
  let asyncSlot = 0
  let asyncAttempt = 1
  let guessHistory: GuessHistoryEntry[] = []
  let isSubmittingGuess = false

  const viewTitle: Record<View, string> = {
    lobby: 'Lobby',
    modes: 'Modes',
    async: 'Session',
    communication: 'Communication',
    auth: 'Compte',
    profile: 'Profil',
  }

  onMount(() => {
    hydrateApp()

    if (!supabase) return

    const refreshTimer = setInterval(() => {
      if (currentUser) {
        hydrateApp(currentMatchId)

        if (currentView === 'communication') {
          void loadCommunication()
        }
      }
    }, 12000)

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      currentUser = session?.user ?? null

      if (!session?.user) {
        myProfile = null
        profileHandle = ''
        coins = 0
        activeMatches = []

        if (currentView === 'profile' || currentView === 'async' || currentView === 'communication') {
          currentView = 'auth'
        }

        return
      }

      await hydrateApp()
    })

    return () => {
      clearInterval(refreshTimer)
      subscription.unsubscribe()
    }
  })

  function normalizeGuessRow(payload: unknown): string[] {
    if (!payload || typeof payload !== 'object') return []

    const maybeRow = (payload as { row?: unknown }).row
    if (!Array.isArray(maybeRow)) return []

    return maybeRow.map((item) => String(item ?? '?'))
  }

  async function loadMatchHistory(matchId: string | null) {
    if (!matchId || !currentUser) {
      guessHistory = []
      asyncAttempt = 1
      return
    }

    try {
      const guesses = await withTimeout(fetchMatchGuesses(matchId), 7000, [])

      guessHistory = guesses.map((guess) => ({
        id: guess.id,
        row: normalizeGuessRow(guess.payload),
        exactHits: guess.exact_hits,
        partialHits: guess.partial_hits,
        isWin: guess.is_win,
        createdAt: guess.created_at,
      }))

      asyncAttempt = guessHistory.length + 1
    } catch {
      guessHistory = []
    }
  }

  async function hydrateApp(preferredMatchId: string | null = null) {
    if (!hasSupabaseConfig) {
      isLoading = false
      toast = 'Configuration Supabase manquante.'
      return
    }

    try {
      isLoading = true

      const user = await withTimeout(fetchCurrentUser(), 7000, null)
      currentUser = user

      const [profileRes, modesRes, matchesRes, challengeRes] = await Promise.allSettled([
        withTimeout(fetchMyProfile(), 7000, null),
        withTimeout(fetchActiveGameModes(), 7000, [] as GameModeRow[]),
        withTimeout(fetchMyMatches(), 7000, [] as Array<MatchRow | MatchRow[]>),
        withTimeout(fetchDailyChallenge(), 7000, null),
      ])

      const opponentRes = currentUser
        ? await Promise.allSettled([withTimeout(fetchOpponentCandidates(), 7000, [] as OpponentCandidate[])])
        : [{ status: 'fulfilled', value: [] }] as const

      const profile = (profileRes.status === 'fulfilled' ? profileRes.value : null) as UserProfile | null
      const modes = (modesRes.status === 'fulfilled' ? modesRes.value : []) as GameModeRow[]
      const matches = (matchesRes.status === 'fulfilled' ? matchesRes.value : []) as Array<MatchRow | MatchRow[]>
      const challenge = (challengeRes.status === 'fulfilled' ? challengeRes.value : null) as DailyChallengeRow | null

      myProfile = profile
      coins = profile?.credits ?? 0
      dailyChallenge = challenge
      profileHandle = profile?.handle ?? ''
      opponentCandidates = (opponentRes[0].status === 'fulfilled' ? opponentRes[0].value : []) as OpponentCandidate[]

      if (!selectedOpponentId || !opponentCandidates.some((op) => op.id === selectedOpponentId)) {
        selectedOpponentId = opponentCandidates[0]?.id ?? ''
      }

      if (!selectedChatUserId || !opponentCandidates.some((op) => op.id === selectedChatUserId)) {
        selectedChatUserId = opponentCandidates[0]?.id ?? ''
      }

      modeCards = (modes ?? [])
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

      const modeById = new Map((modes ?? []).map((mode) => [mode.id, mode.title]))

      const normalizedMatches = (matches ?? [])
        .map((match) => (Array.isArray(match) ? match[0] : match))
        .filter((match): match is MatchRow => Boolean(match?.id))

      activeMatches = normalizedMatches.map((match): ActiveMatchCard => {
        const maxTurns = match.max_turns || 1
        const turnNumber = match.turn_number || 1
        const progress = Math.max(0, Math.min(100, Math.round((turnNumber / maxTurns) * 100)))

        return {
          id: match.id,
          name: `Partie ${match.id.slice(0, 8)}`,
          mode: modeById.get(match.mode_id) ?? 'Mode',
          tries: `${turnNumber}/${maxTurns}`,
          progress,
          status: match.state === 'waiting_turn' || match.state === 'waiting_opponent' ? 'En attente' : 'A votre tour',
          state: match.state,
          maxTurns,
          turnNumber,
          createdByUserId: match.created_by_user_id,
        }
      })

      const hasPreferredMatch = preferredMatchId
        ? activeMatches.some((match) => match.id === preferredMatchId)
        : false

      currentMatchId = hasPreferredMatch ? preferredMatchId : (activeMatches[0]?.id ?? preferredMatchId ?? null)
      await loadMatchHistory(currentMatchId)

      if (currentUser && currentView === 'communication') {
        await loadCommunication()
      }

      const loadErrors = []
      if (profileRes.status === 'rejected') loadErrors.push('profil')
      if (modesRes.status === 'rejected') loadErrors.push('modes')
      if (matchesRes.status === 'rejected') loadErrors.push('parties')
      if (challengeRes.status === 'rejected') loadErrors.push('defi')

      if (loadErrors.length > 0) {
        toast = `Chargement partiel (${loadErrors.join(', ')}).`
      } else if (toast.startsWith('Chargement partiel')) {
        toast = ''
      }
    } catch (error) {
      toast = getErrorMessage(error, 'Erreur de chargement des donnees.')
    } finally {
      isLoading = false
    }
  }

  function goTo(view: View) {
    if ((view === 'async' || view === 'profile' || view === 'communication') && !currentUser) {
      toast = 'Connecte-toi pour acceder a cet espace.'
      currentView = 'auth'
      return
    }

    if (view === 'async' && !currentMatchId) {
      toast = 'Aucune session active. Choisis un mode pour lancer une partie.'
      currentView = 'modes'
      return
    }

    currentView = view
    toast = ''

    if (view === 'communication') {
      void loadCommunication()
    }
  }

  async function loadCommunication() {
    if (!currentUser) return

    try {
      communicationLoading = true
      duelInvitations = await withTimeout(fetchDuelInvitations(), 7000, [])

      if (selectedChatUserId) {
        chatMessages = await withTimeout(fetchMessagesWithUser(selectedChatUserId), 7000, [])
      } else {
        chatMessages = []
      }
    } catch (error) {
      toast = getErrorMessage(error, 'Chargement communication impossible.')
    } finally {
      communicationLoading = false
    }
  }

  async function acceptInvitation(invite: DuelInvitation) {
    try {
      await acceptDuelInvite(invite.match_id)
      currentMatchId = invite.match_id
      await hydrateApp(invite.match_id)
      await loadCommunication()
      toast = 'Invitation acceptee.'
      goTo('async')
    } catch (error) {
      toast = getErrorMessage(error, 'Acceptation impossible.')
    }
  }

  async function refreshChatThread() {
    if (!selectedChatUserId || !currentUser) {
      chatMessages = []
      return
    }

    try {
      communicationLoading = true
      chatMessages = await withTimeout(fetchMessagesWithUser(selectedChatUserId), 7000, [])
    } catch (error) {
      toast = getErrorMessage(error, 'Chargement des messages impossible.')
    } finally {
      communicationLoading = false
    }
  }

  async function sendMessageToPlayer() {
    if (sendingMessage) return
    if (!selectedChatUserId) {
      toast = 'Choisis un joueur pour discuter.'
      return
    }

    if (!chatInput.trim()) {
      toast = 'Message vide.'
      return
    }

    try {
      sendingMessage = true
      await sendPlayerMessage(selectedChatUserId, chatInput)
      chatInput = ''
      await refreshChatThread()
    } catch (error) {
      toast = getErrorMessage(error, 'Envoi du message impossible.')
    } finally {
      sendingMessage = false
    }
  }

  async function handleSignUp() {
    if (!authEmail || !authPassword || !authHandle) {
      toast = 'Email, mot de passe et pseudo requis.'
      return
    }

    try {
      authLoading = true
      await signUpWithEmail({
        email: authEmail.trim(),
        password: authPassword,
        handle: authHandle,
      })
      toast = 'Compte cree. Verifie ton email si confirmation activee.'
      await hydrateApp()
      if (currentUser) goTo('lobby')
    } catch (error) {
      toast = getErrorMessage(error, 'Inscription impossible.')
    } finally {
      authLoading = false
    }
  }

  async function handleSignIn() {
    if (!authEmail || !authPassword) {
      toast = 'Email et mot de passe requis.'
      return
    }

    try {
      authLoading = true
      await signInWithEmail({
        email: authEmail.trim(),
        password: authPassword,
      })
      await hydrateApp()
      goTo('lobby')
    } catch (error) {
      toast = getErrorMessage(error, 'Connexion impossible.')
    } finally {
      authLoading = false
    }
  }

  async function handleSignOut() {
    if (signOutLoading) return

    try {
      signOutLoading = true
      toast = 'Deconnexion en cours...'
      await withTimeout(signOutCurrentUser(), 5000, undefined)
      toast = 'Deconnecte.'
    } catch (error) {
      toast = getErrorMessage(error, 'Deconnexion impossible.')
    } finally {
      currentUser = null
      myProfile = null
      coins = 0
      activeMatches = []
      goTo('auth')
      signOutLoading = false
    }
  }

  async function saveProfile() {
    if (!currentUser) {
      goTo('auth')
      return
    }

    const nextHandle = (profileHandle ?? '').trim().toLowerCase().replace(/[^a-z0-9_]/g, '')
    if (!nextHandle) {
      toast = 'Pseudo invalide (a-z, 0-9, underscore).'
      return
    }

    if (nextHandle === (myProfile?.handle ?? '')) {
      toast = 'Aucune modification a enregistrer.'
      return
    }

    try {
      profileSaving = true
      toast = 'Enregistrement du pseudo...'
      const updated = await updateMyProfile({ handle: nextHandle })
      myProfile = updated
      profileHandle = updated?.handle ?? nextHandle
      toast = 'Profil mis a jour.'
      await hydrateApp()
    } catch (error) {
      toast = getErrorMessage(error, 'Mise a jour impossible.')
    } finally {
      profileSaving = false
    }
  }

  async function chooseMode(card: ModeCard) {
    if (!currentUser) {
      toast = 'Connecte-toi pour creer une partie.'
      goTo('auth')
      return
    }

    if (!card?.modeId) return

    try {
      const isDuel = card.code?.includes('duel')
      const match = isDuel
        ? await joinOrCreateDuel({ modeId: card.modeId })
        : await createMatch({ modeId: card.modeId })

      currentMatchId = match.id
      await hydrateApp(match.id)

      const matchState = (match.state as string | undefined) ?? ''
      if (isDuel && matchState === 'waiting_opponent') {
        toast = 'Duel cree. En attente d\'un adversaire...'
      }

      goTo(card.route ?? 'async')
    } catch (error) {
      toast = getErrorMessage(error, 'Impossible de creer la partie.')
    }
  }

  async function createDuelChallenge(card: ModeCard) {
    if (duelLoading) return

    if (!currentUser) {
      toast = 'Connecte-toi pour creer une partie.'
      goTo('auth')
      return
    }

    if (!selectedOpponentId) {
      toast = 'Choisis un joueur a defier.'
      return
    }

    try {
      duelLoading = true
      const match = await createDuelInvite({
        modeId: card.modeId,
        opponentId: selectedOpponentId,
      })

      currentMatchId = match.id
      await hydrateApp(match.id)
      toast = 'Invitation envoyee.'
      goTo('async')
    } catch (error) {
      toast = getErrorMessage(error, 'Invitation impossible.')
    } finally {
      duelLoading = false
    }
  }

  async function openOrAcceptMatch(match: ActiveMatchCard) {
    currentMatchId = match.id

    try {
      if (match.state === 'waiting_opponent' && currentUser && currentUser.id !== match.createdByUserId) {
        await acceptDuelInvite(match.id)
      }

      await hydrateApp(match.id)
      goTo('async')
    } catch (error) {
      toast = getErrorMessage(error, 'Impossible d\'ouvrir la partie.')
    }
  }

  function placeAsyncPeg(peg: PalettePeg) {
    asyncRow[asyncSlot] = peg
    asyncRow = [...asyncRow]
    asyncSlot = Math.min(asyncSlot + 1, asyncRow.length - 1)
  }

  function setAsyncSlot(index: number) {
    asyncSlot = index
  }

  async function submitAsyncRow() {
    if (isSubmittingGuess) return

    if (!currentUser) {
      toast = 'Connecte-toi pour jouer.'
      goTo('auth')
      return
    }

    if (!currentMatchId) {
      toast = 'Aucune session active.'
      return
    }

    if (asyncRow.some((peg) => !peg)) {
      toast = 'Complete les 4 slots avant de soumettre.'
      return
    }

    const currentMatch = activeMatches.find((match) => match.id === currentMatchId)
    if (currentMatch && currentMatch.state === 'waiting_opponent') {
      toast = 'En attente d\'un adversaire pour commencer le duel.'
      return
    }

    if (currentMatch && currentMatch.state === 'completed') {
      toast = 'Cette partie est terminee.'
      return
    }

    if (currentMatch && guessHistory.length >= currentMatch.maxTurns) {
      toast = 'Nombre maximum de tours atteint.'
      return
    }

    try {
      isSubmittingGuess = true
      await submitGuess({
        matchId: currentMatchId,
        payload: { row: asyncRow.map((peg) => peg?.symbol ?? null) },
      })

      asyncRow = [null, null, null, null]
      asyncSlot = 0
      toast = ''
      await hydrateApp(currentMatchId)
    } catch (error) {
      toast = getErrorMessage(error, 'Soumission impossible.')
    } finally {
      isSubmittingGuess = false
    }
  }

</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link
    href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;700;800&family=JetBrains+Mono:wght@400;500&family=Material+Symbols+Outlined:wght,FILL@200..700,0..1&display=swap"
    rel="stylesheet"
  />
</svelte:head>

<div class="hud-app">
  <div class="scanner-line"></div>
  <header class="topbar glass-panel">
    <div class="brand">
      <span class="material-symbols-outlined brand-icon">terminal</span>
      <div>
        <p class="caption">SYSTEM</p>
        <h1>{viewTitle[currentView]}</h1>
      </div>
    </div>
    <div class="wallet-panel">
      <span class="material-symbols-outlined">account_balance_wallet</span>
      <strong>{coins.toLocaleString('fr-FR')} CR</strong>
    </div>
    <div class="topbar-actions">
      {#if currentUser}
        <span class="caption">Connecte: {myProfile?.handle ?? currentUser.email}</span>
        <button type="button" class="btn btn-ghost" on:click={() => goTo('profile')}>Mon compte</button>
        <button type="button" class="btn btn-ghost" disabled={signOutLoading} on:click={handleSignOut}>
          {signOutLoading ? 'Deconnexion...' : 'Deconnexion'}
        </button>
      {:else}
        <button type="button" class="btn btn-ghost" on:click={() => goTo('auth')}>Connexion</button>
      {/if}
    </div>
  </header>

  <main class="screen grid-layer">
    {#if currentView === 'lobby'}
      <section class="hero-panel glass-panel">
        <div class="panel-tag">
          <span class="dot"></span>
          DEFI QUOTIDIEN
        </div>
        <h2>{dailyChallenge?.title ?? 'Defi indisponible'}</h2>
        <p>{dailyChallenge?.description ?? 'Les donnees du defi quotidien seront affichees ici.'}</p>
        <div class="hero-row">
          <button type="button" class="btn btn-primary" on:click={() => goTo('modes')}>
            OUVRIR SESSION
            <span class="material-symbols-outlined">arrow_forward</span>
          </button>
          <div class="countdown glass-panel">
            <small>DATE</small>
            <strong>{dailyChallenge?.challenge_date ?? '--/--/----'}</strong>
          </div>
        </div>
      </section>

      <section class="section-head">
        <h3>Parties actives</h3>
        <button type="button" class="btn btn-ghost" on:click={() => goTo('modes')}>Voir les modes</button>
      </section>

      <section class="stack">
        {#if isLoading}
          <article class="empty-state glass-panel">Chargement...</article>
        {:else if activeMatches.length === 0}
          <article class="empty-state glass-panel">Aucune partie active.</article>
        {:else}
          {#each activeMatches as match}
            <article class="match-card glass-panel">
              <div class="match-head">
                <div>
                  <h4>{match.name}</h4>
                  <p>{match.mode}</p>
                </div>
                <span class={`status-chip ${match.status === 'En attente' ? 'status-wait' : 'status-turn'}`}>{match.status}</span>
              </div>
              <div class="progress-top">
                <small>Progression</small>
                <small>Essai {match.tries}</small>
              </div>
              <div class="progress"><span style={`width:${match.progress}%`}></span></div>
              <button
                type="button"
                class="btn {match.status === 'En attente' ? 'btn-ghost' : 'btn-primary'}"
                on:click={() => openOrAcceptMatch(match)}
              >
                {match.state === 'waiting_opponent' && currentUser && currentUser.id !== match.createdByUserId
                  ? 'ACCEPTER'
                  : match.status === 'En attente'
                    ? 'WAITING'
                    : 'RESUME'}
              </button>
            </article>
          {/each}
        {/if}
      </section>
    {/if}

    {#if currentView === 'modes'}
      <section class="section-head intro">
        <h3>Selection des modes</h3>
        <p>Les modes disponibles seront affiches ici.</p>
      </section>
      <section class="modes-grid">
        {#if isLoading}
          <article class="empty-state glass-panel">Chargement...</article>
        {:else if modeCards.length === 0}
          <article class="empty-state glass-panel">Aucun mode publie.</article>
        {:else}
          {#each modeCards as card}
            <article class={`mode-card glass-panel ${card.intense ? 'mode-card-intense' : ''}`}>
              <div class="mode-head">
                <span class={`mode-badge ${card.queueType === 'duel' ? 'mode-badge-duel' : 'mode-badge-solo'}`}>
                  {card.queueType === 'duel' ? '1V1' : 'SOLO'}
                </span>
              </div>
              <span class={`mode-icon tone-${card.tone}`}>
                <span class="material-symbols-outlined">{card.icon}</span>
              </span>
              <h4>{card.title}</h4>
              <p>{card.description}</p>

              {#if card.queueType === 'duel'}
                <div class="duel-controls">
                  <label class="field-label" for="duel-opponent">Adversaire</label>
                  <select id="duel-opponent" class="input-field" bind:value={selectedOpponentId}>
                    {#if opponentCandidates.length === 0}
                      <option value="">Aucun joueur disponible</option>
                    {:else}
                      {#each opponentCandidates as opponent}
                        <option value={opponent.id}>{opponent.handle}</option>
                      {/each}
                    {/if}
                  </select>
                  <button
                    type="button"
                    class="btn btn-primary"
                    disabled={duelLoading || opponentCandidates.length === 0}
                    on:click={() => createDuelChallenge(card)}
                  >
                    {duelLoading ? 'Invitation...' : 'Defier'}
                  </button>
                </div>
              {:else}
                <button type="button" class="btn btn-primary" on:click={() => chooseMode(card)}>
                  {card.cta} ->
                </button>
              {/if}
            </article>
          {/each}
        {/if}
      </section>
    {/if}

    {#if currentView === 'async'}
      <section class="hud-row">
        <article class="turn-panel glass-panel">
          <small>TOUR</small>
          <h3>{asyncAttempt}/--</h3>
        </article>
        <article class="turn-panel glass-panel">
          <small>TEMPS</small>
          <h3 class="cyan">--:--:--</h3>
        </article>
      </section>

      <section class="guess-history glass-panel">
        {#if guessHistory.length > 0}
          {#each guessHistory as guess, index}
            <article class="guess-row board-item">
              <small>{index + 1}</small>
              <div class="guess-pegs">
                {#each guess.row as value}
                  <span class="slot"><span class="food">{value}</span></span>
                {/each}
              </div>
              <div class="mini-grid">
                <span>{guess.exactHits}</span>
                <span>{guess.partialHits}</span>
                <span>{guess.isWin ? 'WIN' : ''}</span>
                <span></span>
              </div>
            </article>
          {/each}
        {/if}

        <article class="guess-row current board-item">
          <small>{asyncAttempt}</small>
          <div class="guess-pegs">
            {#each asyncRow as peg, index}
              <button
                type="button"
                class={`slot ${index === asyncSlot ? 'slot-active' : ''}`}
                on:click={() => setAsyncSlot(index)}
              >
                {#if peg}
                  <span class={`peg peg-${peg.tone}`}>
                    <span class="material-symbols-outlined">{peg.symbol}</span>
                  </span>
                {:else}
                  <span class="material-symbols-outlined slot-add">fiber_manual_record</span>
                {/if}
              </button>
            {/each}
          </div>
          <div class="mini-grid"><span></span><span></span><span></span><span></span></div>
        </article>
      </section>

      <button type="button" class="btn btn-primary wide" disabled={isSubmittingGuess} on:click={submitAsyncRow}>
        SOUMETTRE
        <span class="material-symbols-outlined">arrow_forward</span>
      </button>

      <section class="picker glass-panel">
        <div class="picker-head">
          <h4>PALETTE</h4>
        </div>
        <div class="picker-grid">
          {#each asyncPalette as peg}
            <button type="button" class="picker-peg" on:click={() => placeAsyncPeg(peg)}>
              <span class={`peg peg-${peg.tone}`}>
                <span class="material-symbols-outlined">{peg.symbol}</span>
              </span>
            </button>
          {/each}
        </div>
      </section>
    {/if}

    {#if currentView === 'communication'}
      <section class="section-head intro">
        <h3>Communication</h3>
        <p>Invitations duel et messages entre joueurs.</p>
      </section>

      <section class="account-panel glass-panel">
        <h4>Invitations recues</h4>
        {#if communicationLoading}
          <article class="empty-state">Chargement...</article>
        {:else if duelInvitations.length === 0}
          <article class="empty-state">Aucune invitation en attente.</article>
        {:else}
          <div class="stack">
            {#each duelInvitations as invite}
              <article class="match-card glass-panel">
                <div class="match-head">
                  <div>
                    <h4>{invite.mode_title}</h4>
                    <p>Invite par {invite.inviter_handle}</p>
                  </div>
                  <span class="status-chip status-wait">Invitation</span>
                </div>
                <button type="button" class="btn btn-primary" on:click={() => acceptInvitation(invite)}>
                  Accepter
                </button>
              </article>
            {/each}
          </div>
        {/if}
      </section>

      <section class="account-panel glass-panel">
        <h4>Messages prives</h4>
        <div class="duel-controls">
          <label class="field-label" for="chat-user">Joueur</label>
          <select id="chat-user" class="input-field" bind:value={selectedChatUserId} on:change={refreshChatThread}>
            {#if opponentCandidates.length === 0}
              <option value="">Aucun joueur disponible</option>
            {:else}
              {#each opponentCandidates as opponent}
                <option value={opponent.id}>{opponent.handle}</option>
              {/each}
            {/if}
          </select>
        </div>

        <div class="chat-thread glass-panel">
          {#if chatMessages.length === 0}
            <article class="empty-state">Aucun message.</article>
          {:else}
            {#each chatMessages as message}
              <article class={`chat-message ${currentUser && message.sender_user_id === currentUser.id ? 'chat-own' : 'chat-peer'}`}>
                <p>{message.body}</p>
                <small>{new Date(message.created_at).toLocaleString('fr-FR')}</small>
              </article>
            {/each}
          {/if}
        </div>

        <div class="duel-controls">
          <label class="field-label" for="chat-input">Message</label>
          <textarea
            id="chat-input"
            class="input-field chat-input"
            rows="3"
            bind:value={chatInput}
            placeholder="Ecris ton message..."
          ></textarea>
          <button type="button" class="btn btn-primary" disabled={sendingMessage} on:click={sendMessageToPlayer}>
            {sendingMessage ? 'Envoi...' : 'Envoyer'}
          </button>
        </div>
      </section>
    {/if}

    {#if currentView === 'auth'}
      <section class="account-panel glass-panel">
        <h3>Acces utilisateur</h3>
        <p class="account-subtitle">Creer un compte ou se connecter pour acceder aux parties.</p>

        <div class="form-grid">
          <label class="field-label" for="auth-email">Email</label>
          <input id="auth-email" class="input-field" type="email" bind:value={authEmail} placeholder="email@domaine.com" />

          <label class="field-label" for="auth-password">Mot de passe</label>
          <input id="auth-password" class="input-field" type="password" bind:value={authPassword} placeholder="Minimum 6 caracteres" />

          <label class="field-label" for="auth-handle">Pseudo</label>
          <input id="auth-handle" class="input-field" type="text" bind:value={authHandle} placeholder="Pseudo joueur" />
        </div>

        <div class="account-actions">
          <button type="button" class="btn btn-primary" disabled={authLoading} on:click={handleSignIn}>Connexion</button>
          <button type="button" class="btn btn-ghost" disabled={authLoading} on:click={handleSignUp}>Creer un compte</button>
        </div>
      </section>
    {/if}

    {#if currentView === 'profile'}
      <section class="account-panel glass-panel">
        <h3>Mon profil</h3>
        <p class="account-subtitle">Consulter et modifier les informations de compte.</p>

        {#if !currentUser}
          <article class="empty-state">Aucune session utilisateur.</article>
          <div class="account-actions">
            <button type="button" class="btn btn-primary" on:click={() => goTo('auth')}>Se connecter</button>
          </div>
        {:else}
          <div class="profile-grid">
            <div>
              <div class="field-label">User ID</div>
              <div class="readonly-value">{currentUser.id}</div>
            </div>
            <div>
              <div class="field-label">Email</div>
              <div class="readonly-value">{currentUser.email ?? 'N/A'}</div>
            </div>
          </div>

          <div class="form-grid">
            <label class="field-label" for="profile-handle">Pseudo</label>
            <input id="profile-handle" class="input-field" type="text" bind:value={profileHandle} placeholder="Pseudo joueur" />
          </div>

          <div class="account-actions">
            <button type="button" class="btn btn-primary" disabled={profileSaving} on:click={saveProfile}>
              {profileSaving ? 'Enregistrement...' : 'Enregistrer'}
            </button>
            <button type="button" class="btn btn-ghost" on:click={() => goTo('lobby')}>Retour lobby</button>
          </div>
        {/if}
      </section>
    {/if}

    {#if toast}
      <p class="toast">{toast}</p>
    {/if}
  </main>

  <nav class="bottom-nav">
    <button type="button" class={currentView === 'lobby' ? 'active' : ''} on:click={() => goTo('lobby')}>
      <span class="material-symbols-outlined">videogame_asset</span>
      <span>Lobby</span>
    </button>
    <button type="button" class={currentView === 'modes' ? 'active' : ''} on:click={() => goTo('modes')}>
      <span class="material-symbols-outlined">extension</span>
      <span>Modes</span>
    </button>
    <button type="button" class={currentView === 'async' ? 'active' : ''} on:click={() => goTo('async')}>
      <span class="material-symbols-outlined">history</span>
      <span>Logs</span>
    </button>
    <button type="button" class={currentView === 'communication' ? 'active' : ''} on:click={() => goTo('communication')}>
      <span class="material-symbols-outlined">forum</span>
      <span>Comms</span>
    </button>
    <button type="button" class={currentView === 'profile' || currentView === 'auth' ? 'active' : ''} on:click={() => goTo(currentUser ? 'profile' : 'auth')}>
      <span class="material-symbols-outlined">person</span>
      <span>Compte</span>
    </button>
  </nav>
</div>

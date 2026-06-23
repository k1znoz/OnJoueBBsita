<script lang="ts">
  import { onMount } from 'svelte'
  import type { User } from '@supabase/supabase-js'
  import {
    createMatch,
    fetchCurrentUser,
    fetchActiveGameModes,
    fetchDailyChallenge,
    fetchMyMatches,
    fetchMyProfile,
    signInWithEmail,
    signOutCurrentUser,
    signUpWithEmail,
    submitGuess,
    updateMyProfile,
  } from './lib/supabase/services'
  import { hasSupabaseConfig, supabase } from './lib/supabase/client'

  type View = 'lobby' | 'modes' | 'async' | 'theme' | 'auth' | 'profile'

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
    route: 'async' | 'theme' | null
    intense?: boolean
  }

  type MatchRow = {
    id: string
    state: string
    turn_number: number | null
    max_turns: number | null
    mode_id: string
    updated_at: string | null
  }

  type ActiveMatchCard = {
    id: string
    name: string
    mode: string
    tries: string
    progress: number
    status: 'En attente' | 'A votre tour'
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

  let modeCards: ModeCard[] = []
  let activeMatches: ActiveMatchCard[] = []

  const asyncPalette: PalettePeg[] = [
    { symbol: 'circle', tone: 'primary' },
    { symbol: 'pentagon', tone: 'secondary' },
    { symbol: 'square', tone: 'tertiary' },
    { symbol: 'change_history', tone: 'error' },
    { symbol: 'star', tone: 'neutral' },
    { symbol: 'diamond', tone: 'neutral' },
  ]

  const ingredients: string[] = []

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

  let themeRow: Array<string | null> = [null, null, null, null]
  let themeSlot = 0

  const viewTitle: Record<View, string> = {
    lobby: 'Lobby',
    modes: 'Modes',
    async: 'Session',
    theme: 'Thematique',
    auth: 'Compte',
    profile: 'Profil',
  }

  onMount(() => {
    hydrateApp()

    if (!supabase) return

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      currentUser = session?.user ?? null

      if (!session?.user) {
        myProfile = null
        profileHandle = ''
        coins = 0
        activeMatches = []

        if (currentView === 'profile' || currentView === 'async' || currentView === 'theme') {
          currentView = 'auth'
        }

        return
      }

      await hydrateApp()
    })

    return () => {
      subscription.unsubscribe()
    }
  })

  async function hydrateApp(preferredMatchId: string | null = null) {
    if (!hasSupabaseConfig) {
      isLoading = false
      toast = 'Configuration Supabase manquante.'
      return
    }

    try {
      isLoading = true

      const user = await fetchCurrentUser()
      currentUser = user

      const [profileRes, modesRes, matchesRes, challengeRes] = await Promise.allSettled([
        fetchMyProfile(),
        fetchActiveGameModes(),
        fetchMyMatches(),
        fetchDailyChallenge(),
      ])

      const profile = (profileRes.status === 'fulfilled' ? profileRes.value : null) as UserProfile | null
      const modes = (modesRes.status === 'fulfilled' ? modesRes.value : []) as GameModeRow[]
      const matches = (matchesRes.status === 'fulfilled' ? matchesRes.value : []) as Array<MatchRow | MatchRow[]>
      const challenge = (challengeRes.status === 'fulfilled' ? challengeRes.value : null) as DailyChallengeRow | null

      myProfile = profile
      coins = profile?.credits ?? 0
      dailyChallenge = challenge
      profileHandle = profile?.handle ?? ''

      modeCards = (modes ?? []).map((mode, index): ModeCard => ({
        modeId: mode.id,
        code: mode.code,
        icon: 'extension',
        title: mode.title,
        description: mode.short_description ?? '',
        cta: 'Jouer',
        tone: modeTones[index % modeTones.length],
        route:
          mode.code?.includes('async') || mode.code?.includes('classic')
            ? 'async'
            : mode.code?.includes('theme')
              ? 'theme'
              : null,
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
          status: match.state === 'waiting_turn' ? 'En attente' : 'A votre tour',
        }
      })

      const hasPreferredMatch = preferredMatchId
        ? activeMatches.some((match) => match.id === preferredMatchId)
        : false

      currentMatchId = hasPreferredMatch ? preferredMatchId : (activeMatches[0]?.id ?? preferredMatchId ?? null)

      const loadErrors = []
      if (profileRes.status === 'rejected') loadErrors.push('profil')
      if (modesRes.status === 'rejected') loadErrors.push('modes')
      if (matchesRes.status === 'rejected') loadErrors.push('parties')
      if (challengeRes.status === 'rejected') loadErrors.push('defi')

      if (loadErrors.length > 0) {
        toast = `Chargement partiel (${loadErrors.join(', ')}).`
      }
    } catch (error) {
      toast = getErrorMessage(error, 'Erreur de chargement des donnees.')
    } finally {
      isLoading = false
    }
  }

  function goTo(view: View) {
    if ((view === 'async' || view === 'theme' || view === 'profile') && !currentUser) {
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
      await signOutCurrentUser()
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
      const match = await createMatch({ modeId: card.modeId })
      currentMatchId = match.id
      await hydrateApp(match.id)
      goTo(card.route ?? 'async')
    } catch (error) {
      toast = getErrorMessage(error, 'Impossible de creer la partie.')
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

    try {
      await submitGuess({
        matchId: currentMatchId,
        payload: { row: asyncRow.map((peg) => peg?.symbol ?? null) },
      })

      asyncAttempt += 1
      asyncRow = [null, null, null, null]
      asyncSlot = 0
      toast = ''
    } catch (error) {
      toast = getErrorMessage(error, 'Soumission impossible.')
    }
  }

  function placeIngredient(item: string) {
    themeRow[themeSlot] = item
    themeRow = [...themeRow]
    themeSlot = Math.min(themeSlot + 1, themeRow.length - 1)
  }

  function setThemeSlot(index: number) {
    themeSlot = index
  }

  function validateRecipe() {
    toast = ''
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
                on:click={() => {
                  currentMatchId = match.id
                  goTo('async')
                }}
              >
                {match.status === 'En attente' ? 'WAITING' : 'RESUME'}
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
            <button
              type="button"
              class={`mode-card glass-panel ${card.intense ? 'mode-card-intense' : ''}`}
              on:click={() => chooseMode(card)}
            >
              <span class={`mode-icon tone-${card.tone}`}>
                <span class="material-symbols-outlined">{card.icon}</span>
              </span>
              <h4>{card.title}</h4>
              <p>{card.description}</p>
              <strong>{card.cta} -></strong>
            </button>
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

      <button type="button" class="btn btn-primary wide" on:click={submitAsyncRow}>
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

    {#if currentView === 'theme'}
      <section class="section-head intro">
        <h3>Mode thematique</h3>
        <p>Les donnees de partie thematique seront affichees ici.</p>
      </section>

      <section class="stats-grid">
        <article class="stat-card glass-panel">
          <small>TENTATIVES</small>
          <strong>--/--</strong>
        </article>
        <article class="stat-card glass-panel">
          <small>TEMPS</small>
          <strong>--:--</strong>
        </article>
      </section>

      <section class="guess-history glass-panel">
        <article class="guess-row current board-item">
          <div class="guess-pegs emoji-row">
            {#each themeRow as item, index}
              <button type="button" class={`slot ${index === themeSlot ? 'slot-active' : ''}`} on:click={() => setThemeSlot(index)}>
                <span class="food">{item ?? '[Slot vide]'}</span>
              </button>
            {/each}
          </div>
          <button type="button" class="btn btn-primary" on:click={validateRecipe}>VALIDATE</button>
        </article>
      </section>

      <section class="picker glass-panel">
        <div class="picker-head">
          <h4>INGREDIENTS</h4>
        </div>
        <div class="ingredient-grid">
          {#if ingredients.length === 0}
            <article class="empty-state">Aucun ingredient disponible.</article>
          {:else}
            {#each ingredients as item}
              <button type="button" class="ingredient" on:click={() => placeIngredient(item)}>{item}</button>
            {/each}
          {/if}
        </div>
      </section>

      <section class="legend glass-panel">
        <p><span>◉</span> Bon element, bonne position</p>
        <p><span>★</span> Bon element, mauvaise position</p>
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
    <button type="button" class={currentView === 'theme' ? 'active' : ''} on:click={() => goTo('theme')}>
      <span class="material-symbols-outlined">settings</span>
      <span>Core</span>
    </button>
    <button type="button" class={currentView === 'profile' || currentView === 'auth' ? 'active' : ''} on:click={() => goTo(currentUser ? 'profile' : 'auth')}>
      <span class="material-symbols-outlined">person</span>
      <span>Compte</span>
    </button>
  </nav>
</div>

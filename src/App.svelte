<script>
  import { onMount } from 'svelte'
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
  import { hasSupabaseConfig } from './lib/supabase/client'

  let modeCards = []
  let activeMatches = []

  const asyncPalette = [
    { symbol: 'circle', tone: 'primary' },
    { symbol: 'pentagon', tone: 'secondary' },
    { symbol: 'square', tone: 'tertiary' },
    { symbol: 'change_history', tone: 'error' },
    { symbol: 'star', tone: 'neutral' },
    { symbol: 'diamond', tone: 'neutral' },
  ]

  const ingredients = []

  let currentView = 'lobby'
  let currentMatchId = null
  let dailyChallenge = null
  let currentUser = null
  let myProfile = null
  let isLoading = true
  let authLoading = false
  let coins = 0
  let toast = ''

  let authEmail = ''
  let authPassword = ''
  let authHandle = ''
  let profileHandle = ''

  let asyncRow = [null, null, null, null]
  let asyncSlot = 0
  let asyncAttempt = 1

  let themeRow = [null, null, null, null]
  let themeSlot = 0

  const viewTitle = {
    lobby: 'Lobby',
    modes: 'Modes',
    async: 'Session',
    theme: 'Thematique',
    auth: 'Compte',
    profile: 'Profil',
  }

  onMount(() => {
    hydrateApp()
  })

  async function hydrateApp() {
    if (!hasSupabaseConfig) {
      isLoading = false
      toast = 'Configuration Supabase manquante.'
      return
    }

    try {
      isLoading = true

      const [user, profile, modes, matches, challenge] = await Promise.all([
        fetchCurrentUser(),
        fetchMyProfile(),
        fetchActiveGameModes(),
        fetchMyMatches(),
        fetchDailyChallenge(),
      ])

      currentUser = user
      myProfile = profile
      coins = profile?.credits ?? 0
      dailyChallenge = challenge
      profileHandle = profile?.handle ?? ''

      modeCards = (modes ?? []).map((mode, index) => ({
        modeId: mode.id,
        code: mode.code,
        icon: 'extension',
        title: mode.title,
        description: mode.short_description ?? '',
        cta: 'Jouer',
        tone: ['primary', 'secondary', 'tertiary'][index % 3],
        route:
          mode.code?.includes('async') || mode.code?.includes('classic')
            ? 'async'
            : mode.code?.includes('theme')
              ? 'theme'
              : null,
      }))

      const modeById = new Map((modes ?? []).map((mode) => [mode.id, mode.title]))

      activeMatches = (matches ?? []).map((match) => {
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

      currentMatchId = activeMatches[0]?.id ?? null
    } catch (error) {
      toast = error?.message ?? 'Erreur de chargement des donnees.'
    } finally {
      isLoading = false
    }
  }

  function goTo(view) {
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
      toast = error?.message ?? 'Inscription impossible.'
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
      toast = error?.message ?? 'Connexion impossible.'
    } finally {
      authLoading = false
    }
  }

  async function handleSignOut() {
    try {
      authLoading = true
      await signOutCurrentUser()
      currentUser = null
      myProfile = null
      coins = 0
      activeMatches = []
      goTo('auth')
    } catch (error) {
      toast = error?.message ?? 'Deconnexion impossible.'
    } finally {
      authLoading = false
    }
  }

  async function saveProfile() {
    if (!currentUser) {
      goTo('auth')
      return
    }

    try {
      authLoading = true
      const updated = await updateMyProfile({ handle: profileHandle })
      myProfile = updated
      toast = 'Profil mis a jour.'
      await hydrateApp()
    } catch (error) {
      toast = error?.message ?? 'Mise a jour impossible.'
    } finally {
      authLoading = false
    }
  }

  async function chooseMode(card) {
    if (!currentUser) {
      toast = 'Connecte-toi pour creer une partie.'
      goTo('auth')
      return
    }

    if (!card?.modeId) return

    try {
      const match = await createMatch({ modeId: card.modeId })
      currentMatchId = match.id
      await hydrateApp()
      goTo(card.route ?? 'async')
    } catch (error) {
      toast = error?.message ?? 'Impossible de creer la partie.'
    }
  }

  function placeAsyncPeg(peg) {
    asyncRow[asyncSlot] = peg
    asyncRow = [...asyncRow]
    asyncSlot = Math.min(asyncSlot + 1, asyncRow.length - 1)
  }

  function setAsyncSlot(index) {
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
      toast = error?.message ?? 'Soumission impossible.'
    }
  }

  function placeIngredient(item) {
    themeRow[themeSlot] = item
    themeRow = [...themeRow]
    themeSlot = Math.min(themeSlot + 1, themeRow.length - 1)
  }

  function setThemeSlot(index) {
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
        <button class="btn btn-ghost" on:click={() => goTo('profile')}>Mon compte</button>
        <button class="btn btn-ghost" disabled={authLoading} on:click={handleSignOut}>Deconnexion</button>
      {:else}
        <button class="btn btn-ghost" on:click={() => goTo('auth')}>Connexion</button>
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
          <button class="btn btn-primary" on:click={() => goTo('async')}>
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
        <button class="btn btn-ghost" on:click={() => goTo('modes')}>Voir les modes</button>
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

      <button class="btn btn-primary wide" on:click={submitAsyncRow}>
        SOUMETTRE
        <span class="material-symbols-outlined">arrow_forward</span>
      </button>

      <section class="picker glass-panel">
        <div class="picker-head">
          <h4>PALETTE</h4>
        </div>
        <div class="picker-grid">
          {#each asyncPalette as peg}
            <button class="picker-peg" on:click={() => placeAsyncPeg(peg)}>
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
              <button class={`slot ${index === themeSlot ? 'slot-active' : ''}`} on:click={() => setThemeSlot(index)}>
                <span class="food">{item ?? '[Slot vide]'}</span>
              </button>
            {/each}
          </div>
          <button class="btn btn-primary" on:click={validateRecipe}>VALIDATE</button>
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
              <button class="ingredient" on:click={() => placeIngredient(item)}>{item}</button>
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
          <button class="btn btn-primary" disabled={authLoading} on:click={handleSignIn}>Connexion</button>
          <button class="btn btn-ghost" disabled={authLoading} on:click={handleSignUp}>Creer un compte</button>
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
            <button class="btn btn-primary" on:click={() => goTo('auth')}>Se connecter</button>
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
            <button class="btn btn-primary" disabled={authLoading} on:click={saveProfile}>Enregistrer</button>
            <button class="btn btn-ghost" on:click={() => goTo('lobby')}>Retour lobby</button>
          </div>
        {/if}
      </section>
    {/if}

    {#if toast}
      <p class="toast">{toast}</p>
    {/if}
  </main>

  <nav class="bottom-nav">
    <button class={currentView === 'lobby' ? 'active' : ''} on:click={() => goTo('lobby')}>
      <span class="material-symbols-outlined">videogame_asset</span>
      <span>Lobby</span>
    </button>
    <button class={currentView === 'modes' ? 'active' : ''} on:click={() => goTo('modes')}>
      <span class="material-symbols-outlined">extension</span>
      <span>Modes</span>
    </button>
    <button class={currentView === 'async' ? 'active' : ''} on:click={() => goTo('async')}>
      <span class="material-symbols-outlined">history</span>
      <span>Logs</span>
    </button>
    <button class={currentView === 'theme' ? 'active' : ''} on:click={() => goTo('theme')}>
      <span class="material-symbols-outlined">settings</span>
      <span>Core</span>
    </button>
    <button class={currentView === 'profile' || currentView === 'auth' ? 'active' : ''} on:click={() => goTo(currentUser ? 'profile' : 'auth')}>
      <span class="material-symbols-outlined">person</span>
      <span>Compte</span>
    </button>
  </nav>
</div>

<script lang="ts">
  import type { User } from '@supabase/supabase-js'
  import type { ActiveMatchCard, DailyChallengeRow } from '../../model/types'

  export let isLoading = false
  export let activeMatches: ActiveMatchCard[] = []
  export let dailyChallenge: DailyChallengeRow | null = null
  export let currentUser: User | null = null
  export let managingMatchId: string | null = null
  export let canCancelMatch: (match: ActiveMatchCard) => boolean
  export let canDeleteMatch: (match: ActiveMatchCard) => boolean
  export let onOpenMatch: (match: ActiveMatchCard) => void
  export let onManageMatch: (match: ActiveMatchCard, action: 'cancel' | 'delete') => void
  export let onGoToModes: () => void
</script>

<section class="hero-panel glass-panel">
  <div class="panel-tag">
    <span class="dot"></span>
    DEFI QUOTIDIEN
  </div>
  <h2>{dailyChallenge?.title ?? 'Defi indisponible'}</h2>
  <p>{dailyChallenge?.description ?? 'Les donnees du defi quotidien seront affichees ici.'}</p>
  <div class="hero-row">
    <button type="button" class="btn btn-primary" on:click={onGoToModes}>
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
  <h3>Mes parties</h3>
  <button type="button" class="btn btn-ghost" on:click={onGoToModes}>Voir les modes</button>
</section>

<section class="stack">
  {#if isLoading}
    <article class="empty-state glass-panel">Chargement...</article>
  {:else if activeMatches.length === 0}
    <article class="empty-state glass-panel">Aucune partie.</article>
  {:else}
    {#each activeMatches as match}
      <article class="match-card glass-panel">
        <div class="match-head">
          <div>
            <h4>{match.name}</h4>
            <p>{match.mode}</p>
          </div>
          <span class={`status-chip ${match.status === 'En attente' ? 'status-wait' : match.status === 'Terminee' ? 'status-done' : 'status-turn'}`}>{match.status}</span>
        </div>
        <div class="progress-top">
          <small>Progression</small>
          <small>Essai {match.tries}</small>
        </div>
        <div class="progress"><span style={`width:${match.progress}%`}></span></div>
        <div class="match-actions">
          <button
            type="button"
            class="btn {match.status === 'En attente' ? 'btn-ghost' : 'btn-primary'}"
            on:click={() => onOpenMatch(match)}
          >
            {match.state === 'waiting_opponent' && currentUser && currentUser.id !== match.createdByUserId
              ? 'ACCEPTER'
              : match.status === 'En attente'
                ? 'WAITING'
                : match.status === 'Terminee'
                  ? 'VOIR'
                  : 'RESUME'}
          </button>

          {#if canCancelMatch(match)}
            <button
              type="button"
              class="btn btn-ghost"
              disabled={managingMatchId === match.id}
              on:click={() => onManageMatch(match, 'cancel')}
            >
              {managingMatchId === match.id ? '...' : 'ANNULER'}
            </button>
          {/if}

          {#if canDeleteMatch(match)}
            <button
              type="button"
              class="btn btn-ghost"
              disabled={managingMatchId === match.id}
              on:click={() => onManageMatch(match, 'delete')}
            >
              {managingMatchId === match.id ? '...' : 'SUPPRIMER'}
            </button>
          {/if}
        </div>
      </article>
    {/each}
  {/if}
</section>

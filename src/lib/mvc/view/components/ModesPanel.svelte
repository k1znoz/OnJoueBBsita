<script lang="ts">
  import type { ModeCard, OpponentCandidate } from '../../model/types'

  export let isLoading = false
  export let modeCards: ModeCard[] = []
  export let opponentCandidates: OpponentCandidate[] = []
  export let selectedOpponentId = ''
  export let duelLoading = false
  export let onSelectOpponent: (opponentId: string) => void
  export let onCreateDuelChallenge: (card: ModeCard) => void
  export let onChooseMode: (card: ModeCard) => void
</script>

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
            <select
              id="duel-opponent"
              class="input-field"
              value={selectedOpponentId}
              on:change={(event) => onSelectOpponent((event.currentTarget as HTMLSelectElement).value)}
            >
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
              on:click={() => onCreateDuelChallenge(card)}
            >
              {duelLoading ? 'Invitation...' : 'Defier'}
            </button>
          </div>
        {:else}
          <button type="button" class="btn btn-primary" on:click={() => onChooseMode(card)}>
            {card.cta} ->
          </button>
        {/if}
      </article>
    {/each}
  {/if}
</section>

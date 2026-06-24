<script lang="ts">
  import { feedbackDots, toneForSymbol } from '../../model/mappers'
  import type { DuelGuessEntry, GuessHistoryEntry, PalettePeg } from '../../model/types'

  export let asyncAttempt = 1
  export let guessHistory: GuessHistoryEntry[] = []
  export let asyncRow: Array<PalettePeg | null> = []
  export let asyncSlot = 0
  export let asyncPalette: PalettePeg[] = []
  export let mySecretReady = false
  export let opponentSecretReady = false
  export let secretRow: Array<PalettePeg | null> = []
  export let secretSlot = 0
  export let isSubmittingSecret = false
  export let myDuelGuesses: DuelGuessEntry[] = []
  export let opponentDuelGuesses: DuelGuessEntry[] = []
  export let isSubmittingGuess = false
  export let onSetSlot: (index: number) => void
  export let onPlacePeg: (peg: PalettePeg) => void
  export let onSetSecretSlot: (index: number) => void
  export let onPlaceSecretPeg: (peg: PalettePeg) => void
  export let onSubmitSecret: () => void
  export let onSubmitRow: () => void
</script>

<section class="legend glass-panel">
  <h4>Code Secret</h4>
  <p>{mySecretReady ? 'Ton code est verrouille.' : 'Definis ton code secret (4 symboles).'} Opposant: {opponentSecretReady ? 'pret' : 'en attente'}.</p>
  <div class="guess-row current board-item">
    <small>CODE</small>
    <div class="guess-pegs">
      {#each secretRow as peg, index}
        <button
          type="button"
          class={`slot ${index === secretSlot ? 'slot-active' : ''}`}
          on:click={() => onSetSecretSlot(index)}
          disabled={mySecretReady || isSubmittingSecret}
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
  </div>
  <button
    type="button"
    class="btn btn-ghost"
    disabled={mySecretReady || isSubmittingSecret}
    on:click={onSubmitSecret}
  >
    {isSubmittingSecret ? 'Verrouillage...' : mySecretReady ? 'Code verrouille' : 'Verrouiller mon code'}
  </button>
</section>

<section class="picker glass-panel picker-secret">
  <div class="picker-head">
    <h4>PALETTE</h4>
  </div>
  <div class="picker-grid">
    {#each asyncPalette as peg}
      <button
        type="button"
        class="picker-peg"
        on:click={() => {
          onPlacePeg(peg)
          if (!mySecretReady) onPlaceSecretPeg(peg)
        }}
      >
        <span class={`peg peg-${peg.tone}`}>
          <span class="material-symbols-outlined">{peg.symbol}</span>
        </span>
      </button>
    {/each}
  </div>
</section>

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
            <span class="slot history-slot">
              <span class={`peg peg-${toneForSymbol(value)}`}>
                <span class="material-symbols-outlined">{value}</span>
              </span>
            </span>
          {/each}
        </div>
        <div class="mini-grid">
          {#each feedbackDots(guess.exactHits, guess.partialHits) as dot}
            <span class={`feedback-dot feedback-${dot}`}></span>
          {/each}
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
          on:click={() => onSetSlot(index)}
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
    <div class="mini-grid">
      <span class="feedback-dot feedback-empty"></span>
      <span class="feedback-dot feedback-empty"></span>
      <span class="feedback-dot feedback-empty"></span>
      <span class="feedback-dot feedback-empty"></span>
    </div>
  </article>
</section>

<section class="legend glass-panel">
  <h4>Lecture des petits carres</h4>
  <p><span class="feedback-dot feedback-black"></span> noir: symbole bien place.</p>
  <p><span class="feedback-dot feedback-white"></span> blanc: symbole present mais mal place.</p>
  <p><span class="feedback-dot feedback-empty"></span> vide: symbole absent du code secret.</p>
</section>

<button type="button" class="btn btn-primary wide" disabled={isSubmittingGuess} on:click={onSubmitRow}>
  SOUMETTRE
  <span class="material-symbols-outlined">arrow_forward</span>
</button>

<section class="guess-history glass-panel">
  <h4>Mes essais sur le code adverse</h4>
  {#if myDuelGuesses.length === 0}
    <article class="empty-state">Aucun essai duel.</article>
  {:else}
    {#each myDuelGuesses as guess}
      <article class="guess-row board-item">
        <small>{guess.turn}</small>
        <div class="guess-pegs">
          {#each guess.row as value}
            <span class="slot history-slot">
              <span class={`peg peg-${toneForSymbol(value)}`}>
                <span class="material-symbols-outlined">{value}</span>
              </span>
            </span>
          {/each}
        </div>
        <div class="mini-grid">
          {#each feedbackDots(guess.exactHits, guess.partialHits) as dot}
            <span class={`feedback-dot feedback-${dot}`}></span>
          {/each}
        </div>
      </article>
    {/each}
  {/if}
</section>

<section class="guess-history glass-panel">
  <h4>Essais adverses sur mon code</h4>
  {#if opponentDuelGuesses.length === 0}
    <article class="empty-state">Aucun essai adverse.</article>
  {:else}
    {#each opponentDuelGuesses as guess}
      <article class="guess-row board-item">
        <small>{guess.turn}</small>
        <div class="guess-pegs">
          {#each guess.row as value}
            <span class="slot history-slot">
              <span class={`peg peg-${toneForSymbol(value)}`}>
                <span class="material-symbols-outlined">{value}</span>
              </span>
            </span>
          {/each}
        </div>
        <div class="mini-grid">
          {#each feedbackDots(guess.exactHits, guess.partialHits) as dot}
            <span class={`feedback-dot feedback-${dot}`}></span>
          {/each}
        </div>
      </article>
    {/each}
  {/if}
</section>


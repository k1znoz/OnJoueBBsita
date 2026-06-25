<script lang="ts">
  import { feedbackDots, toneForSymbol } from '../../model/mappers'
  import type { DuelGuessEntry, GuessHistoryEntry, PalettePeg } from '../../model/types'

  export let isDuelMatch = false
  export let matchState: string | null = null
  export let matchOutcome: 'win' | 'loss' | 'draw' | null = null
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
  export let onReplay: () => void

  type DisplayGuessRow = {
    id: string
    turn: number
    row: string[]
    exactHits: number
    partialHits: number
  }

  let decoderHistory: DisplayGuessRow[] = []
  let canSubmitGuess = true
  let canPlayCurrentMatch = true
  let decoderStatus = ''
  let endgameTitle = ''
  let endgameText = ''

  $: decoderHistory =
    myDuelGuesses.length > 0
      ? myDuelGuesses.map((guess) => ({
          id: guess.id,
          turn: guess.turn,
          row: guess.row,
          exactHits: guess.exactHits,
          partialHits: guess.partialHits,
        }))
      : guessHistory.map((guess, index) => ({
          id: guess.id,
          turn: index + 1,
          row: guess.row,
          exactHits: guess.exactHits,
          partialHits: guess.partialHits,
        }))

  $: canSubmitGuess = !isDuelMatch || (mySecretReady && opponentSecretReady)
  $: canPlayCurrentMatch = !matchState || !['completed', 'canceled', 'expired'].includes(matchState)
  $: decoderStatus = !isDuelMatch
    ? 'Mode solo: code IA actif'
    : canSubmitGuess
      ? `Tentative ${asyncAttempt}/10`
      : 'Verrouillez les deux codes pour demarrer'

  $: endgameTitle =
    matchOutcome === 'win' ? 'Victoire' : matchOutcome === 'loss' ? 'Defaite' : matchOutcome === 'draw' ? 'Partie terminee' : ''
  $: endgameText =
    matchOutcome === 'win'
      ? 'Code perce. Belle execution.'
      : matchOutcome === 'loss'
        ? 'Le code adverse a tenu. Revanche ?'
        : matchOutcome === 'draw'
          ? 'Fin de session. Relancer une partie ?'
          : ''
</script>

<section class="duel-screen">
  {#if isDuelMatch}
    <section class="role-block role-coder glass-panel">
      <header class="role-head">
        <div class="role-title">
          <span class="role-dot role-dot-coder"></span>
          <h3>Codeur</h3>
        </div>
        <small>Opposant: {opponentSecretReady ? 'pret' : 'en attente'}</small>
      </header>

      <article class="stack-card secret-card">
        <div class="row-between">
          <p class="card-label">Votre code secret</p>
          <button
            type="button"
            class="btn-lock"
            disabled={mySecretReady || isSubmittingSecret}
            on:click={onSubmitSecret}
          >
            {isSubmittingSecret ? 'Verrouillage...' : mySecretReady ? 'Code verrouille' : 'Verrouiller le code'}
          </button>
        </div>

        <div class="slots-row">
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
                <span class="material-symbols-outlined slot-add">add</span>
              {/if}
            </button>
          {/each}
        </div>

        <div class="palette-inline">
          {#each asyncPalette as peg}
            <button
              type="button"
              class="palette-key"
              disabled={mySecretReady || isSubmittingSecret}
              on:click={() => onPlaceSecretPeg(peg)}
            >
              <span class={`peg peg-${peg.tone}`}>
                <span class="material-symbols-outlined">{peg.symbol}</span>
              </span>
            </button>
          {/each}
        </div>
      </article>

      <article class="stack-card history-card">
        <div class="row-between">
          <p class="card-label">Essais adverses</p>
        </div>

        {#if opponentDuelGuesses.length === 0}
          <p class="history-empty">Aucun essai adverse.</p>
        {:else}
          <div class="history-list">
            {#each opponentDuelGuesses as guess}
              <article class="history-row">
                <div class="mini-pegs">
                  {#each guess.row as value}
                    <span class="mini-peg-wrap">
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
          </div>
        {/if}
      </article>
    </section>
  {/if}

  <section class="role-block role-decoder glass-panel">
    <header class="role-head">
      <div class="role-title">
        <span class="role-dot role-dot-decoder"></span>
        <h3>Decodeur</h3>
      </div>
      <small>{decoderStatus}</small>
    </header>

    {#if matchOutcome}
      <article class={`stack-card endgame-banner endgame-${matchOutcome}`}>
        <div class="endgame-copy">
          <p class="endgame-title">{endgameTitle}</p>
          <p class="endgame-text">{endgameText}</p>
        </div>
        <button type="button" class="btn-replay" on:click={onReplay}>Relancer</button>
      </article>
    {/if}

    <article class="stack-card history-card decoder-history">
      <div class="row-between">
        <p class="card-label">Mes tentatives</p>
        <div class="feedback-legend" aria-label="Legende correction">
          <span class="legend-item"><span class="feedback-dot feedback-black"></span> Noir</span>
          <span class="legend-item"><span class="feedback-dot feedback-white"></span> Blanc</span>
          <span class="legend-item"><span class="feedback-dot feedback-empty"></span> Grise</span>
        </div>
      </div>

      {#if decoderHistory.length === 0}
        <p class="history-empty">Aucune tentative.</p>
      {:else}
        <div class="history-list">
          {#each decoderHistory as guess}
            <article class="history-row">
              <div class="history-turn">{guess.turn}</div>
              <div class="mini-pegs">
                {#each guess.row as value}
                  <span class="mini-peg-wrap">
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
        </div>
      {/if}
    </article>

    <article class="stack-card active-guess-card">
      <div class="slots-row">
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
              <span class="material-symbols-outlined slot-add">add</span>
            {/if}
          </button>
        {/each}
      </div>

      <button
        type="button"
        class="btn-submit"
        disabled={isSubmittingGuess || !canSubmitGuess || !canPlayCurrentMatch}
        on:click={onSubmitRow}
      >
        {#if !canPlayCurrentMatch}
          Partie terminee
        {:else if isSubmittingGuess}
          Envoi...
        {:else}
          Soumettre
        {/if}
      </button>
    </article>

    <article class="stack-card palette-decoder-card">
      <p class="card-label card-label-cyan">Saisie decodeur</p>
      <div class="palette-inline">
        {#each asyncPalette as peg}
          <button
            type="button"
            class="palette-key"
            on:click={() => onPlacePeg(peg)}
          >
            <span class={`peg peg-${peg.tone}`}>
              <span class="material-symbols-outlined">{peg.symbol}</span>
            </span>
          </button>
        {/each}
      </div>
    </article>
  </section>
</section>

<style>
  .duel-screen {
    display: grid;
    gap: 12px;
  }

  .role-block {
    padding: 14px;
    display: grid;
    gap: 12px;
    border: 1px solid rgba(255, 191, 0, 0.12);
    background: rgba(12, 12, 15, 0.46);
  }

  .role-coder {
    border-top: 1px solid rgba(255, 127, 80, 0.3);
  }

  .role-decoder {
    border-top: 1px solid rgba(0, 240, 255, 0.3);
  }

  .role-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .role-title {
    display: inline-flex;
    align-items: center;
    gap: 10px;
  }

  .role-title h3 {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.09em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.98rem;
  }

  .role-head small {
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.66rem;
  }

  .role-dot {
    width: 11px;
    height: 11px;
    border-radius: 999px;
    box-shadow: 0 0 12px currentColor;
  }

  .role-dot-coder {
    background: #ffb59c;
    color: #ffb59c;
  }

  .role-dot-decoder {
    background: #00f0ff;
    color: #00f0ff;
  }

  .stack-card {
    border: 1px solid rgba(255, 191, 0, 0.2);
    background: rgba(13, 13, 18, 0.72);
    padding: 12px;
    display: grid;
    gap: 10px;
  }

  .row-between {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .card-label {
    margin: 0;
    text-transform: uppercase;
    color: var(--amber-soft);
    letter-spacing: 0.07em;
    font-size: 0.7rem;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
  }

  .card-label-cyan {
    color: var(--cyan);
  }

  .btn-lock {
    border: 1px solid rgba(255, 191, 0, 0.46);
    background: rgba(255, 191, 0, 0.18);
    color: var(--amber-soft);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.7rem;
    padding: 8px 12px;
    cursor: pointer;
    transition: 160ms ease;
  }

  .btn-lock:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 0 16px rgba(255, 191, 0, 0.2);
  }

  .btn-lock:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .slots-row {
    display: flex;
    gap: 8px;
    justify-content: flex-start;
    flex-wrap: wrap;
  }

  .slot {
    width: 54px;
    height: 54px;
    border: 1px solid rgba(255, 191, 0, 0.24);
    background: rgba(6, 6, 9, 0.86);
    display: grid;
    place-items: center;
    cursor: pointer;
    transition: 140ms ease;
  }

  .slot .peg {
    width: 42px;
    height: 42px;
    display: grid;
    place-items: center;
  }

  .slot .peg .material-symbols-outlined {
    font-size: 1.2rem;
    line-height: 1;
  }

  .slot:hover {
    border-color: rgba(255, 191, 0, 0.52);
  }

  .slot-active {
    border-color: rgba(255, 191, 0, 0.95);
    box-shadow: 0 0 18px rgba(255, 191, 0, 0.25);
  }

  .slot-add {
    opacity: 0.4;
    font-size: 1.15rem;
  }

  .palette-inline {
    border-top: 1px solid rgba(255, 191, 0, 0.18);
    padding-top: 10px;
    display: grid;
    grid-template-columns: repeat(8, minmax(0, 1fr));
    gap: 7px;
  }

  .palette-key {
    border: 1px solid transparent;
    background: rgba(255, 255, 255, 0.02);
    min-height: 48px;
    cursor: pointer;
    display: grid;
    place-items: center;
    transition: 140ms ease;
  }

  .palette-key:hover:not(:disabled) {
    border-color: rgba(255, 191, 0, 0.35);
    background: rgba(255, 191, 0, 0.08);
  }

  .palette-key:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .history-card {
    min-height: 92px;
  }

  .history-list {
    display: grid;
    gap: 8px;
    max-height: 170px;
    overflow: auto;
    padding-right: 3px;
  }

  .history-row {
    display: flex;
    align-items: center;
    gap: 8px;
    border: 1px solid rgba(255, 191, 0, 0.12);
    background: rgba(255, 255, 255, 0.02);
    padding: 7px 8px;
  }

  .history-turn {
    min-width: 22px;
    color: var(--text-dim);
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.68rem;
    text-align: center;
  }

  .history-empty {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.07em;
    color: var(--text-dim);
    font-size: 0.66rem;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    padding: 10px 0;
  }

  .mini-pegs {
    display: flex;
    gap: 6px;
    flex: 1;
  }

  .mini-peg-wrap {
    width: 34px;
    height: 34px;
    display: grid;
    place-items: center;
    border: 1px solid rgba(255, 191, 0, 0.15);
    background: rgba(0, 0, 0, 0.4);
  }

  .mini-peg-wrap .peg {
    width: 28px;
    height: 28px;
    display: grid;
    place-items: center;
  }

  .mini-peg-wrap .peg .material-symbols-outlined {
    font-size: 0.95rem;
    line-height: 1;
  }

  .mini-grid {
    width: 34px;
    min-width: 34px;
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 4px;
    place-items: center;
  }

  .feedback-dot {
    width: 12px;
    height: 12px;
    border-radius: 999px;
    border: 1px solid rgba(255, 191, 0, 0.34);
    background: transparent;
  }

  .feedback-black {
    background: #050505;
    border-color: rgba(255, 255, 255, 0.9);
    box-shadow:
      inset 0 0 0 1px rgba(255, 255, 255, 0.12),
      0 0 0 1px rgba(0, 0, 0, 0.4);
  }

  .feedback-white {
    background: #f5f1e8;
    border-color: rgba(245, 241, 232, 0.85);
  }

  .feedback-empty {
    background:
      repeating-linear-gradient(
        45deg,
        rgba(255, 191, 0, 0.08) 0,
        rgba(255, 191, 0, 0.08) 2px,
        transparent 2px,
        transparent 4px
      ),
      rgba(0, 0, 0, 0.28);
    border-style: solid;
    border-color: rgba(255, 191, 0, 0.48);
  }

  .feedback-legend {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    color: var(--text-dim);
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.64rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .legend-item {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    white-space: nowrap;
  }

  .legend-item .feedback-dot {
    width: 12px;
    height: 12px;
  }

  .endgame-banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    border-width: 1px;
    box-shadow: 0 0 24px rgba(255, 191, 0, 0.14);
  }

  .endgame-win {
    border-color: rgba(102, 240, 200, 0.55);
    background: linear-gradient(90deg, rgba(102, 240, 200, 0.16), rgba(15, 18, 24, 0.82));
  }

  .endgame-loss {
    border-color: rgba(255, 107, 107, 0.55);
    background: linear-gradient(90deg, rgba(255, 107, 107, 0.18), rgba(20, 15, 18, 0.84));
  }

  .endgame-draw {
    border-color: rgba(255, 191, 0, 0.48);
    background: linear-gradient(90deg, rgba(255, 191, 0, 0.15), rgba(16, 14, 10, 0.82));
  }

  .endgame-copy {
    display: grid;
    gap: 4px;
  }

  .endgame-title {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.11em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.95rem;
    color: #fff4dc;
  }

  .endgame-text {
    margin: 0;
    color: var(--text-dim);
    font-size: 0.75rem;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
  }

  .btn-replay {
    border: 1px solid rgba(255, 226, 171, 0.75);
    background: rgba(255, 226, 171, 0.95);
    color: #2f2200;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.72rem;
    padding: 10px 14px;
    min-width: 124px;
    cursor: pointer;
    transition: 140ms ease;
  }

  .btn-replay:hover {
    transform: translateY(-1px);
    box-shadow: 0 0 20px rgba(255, 226, 171, 0.2);
  }

  .decoder-history .history-list {
    max-height: 184px;
  }

  .active-guess-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    border-color: rgba(255, 191, 0, 0.35);
    box-shadow: 0 0 20px rgba(255, 191, 0, 0.1);
  }

  .btn-submit {
    border: 1px solid rgba(255, 226, 171, 0.7);
    background: var(--amber-soft);
    color: #2f2200;
    text-transform: uppercase;
    letter-spacing: 0.07em;
    font-family: 'JetBrains Mono', 'Consolas', monospace;
    font-size: 0.78rem;
    padding: 14px 16px;
    min-width: 138px;
    cursor: pointer;
    transition: 160ms ease;
  }

  .btn-submit:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 0 20px rgba(255, 226, 171, 0.24);
  }

  .btn-submit:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .palette-decoder-card {
    gap: 8px;
  }

  @media (max-width: 740px) {
    .feedback-legend {
      width: 100%;
      justify-content: flex-start;
      flex-wrap: wrap;
      gap: 10px;
    }

    .palette-inline {
      grid-template-columns: repeat(4, minmax(0, 1fr));
    }

    .active-guess-card {
      flex-direction: column;
      align-items: stretch;
    }

    .endgame-banner {
      flex-direction: column;
      align-items: stretch;
    }

    .btn-replay {
      width: 100%;
      min-width: 0;
    }

    .btn-submit {
      width: 100%;
      min-width: 0;
    }
  }
</style>


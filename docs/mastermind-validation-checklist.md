# Validation checklist - Mastermind gameplay

Ce document permet de verifier que:
- le calcul Noir/Blanc/Grise est correct
- la partie se termine bien
- les stats sont comptabilisees une seule fois

## 1) Verification calcul Noir/Blanc/Grise

La logique centrale est dans la fonction SQL `public.calculate_mastermind_feedback`.

Exemples a executer dans Supabase SQL Editor:

```sql
select *
from public.calculate_mastermind_feedback(
  '["circle","pentagon","square","star"]'::jsonb,
  '["circle","pentagon","square","star"]'::jsonb,
  array['circle','pentagon','square','change_history','star','diamond','hexagon','bolt']
);
-- attendu: exact_hits=4, partial_hits=0, empty_hits=0, is_win=true

select *
from public.calculate_mastermind_feedback(
  '["circle","pentagon","square","star"]'::jsonb,
  '["pentagon","circle","star","square"]'::jsonb,
  array['circle','pentagon','square','change_history','star','diamond','hexagon','bolt']
);
-- attendu: exact_hits=0, partial_hits=4, empty_hits=0, is_win=false

select *
from public.calculate_mastermind_feedback(
  '["circle","circle","diamond","bolt"]'::jsonb,
  '["circle","square","hexagon","bolt"]'::jsonb,
  array['circle','pentagon','square','change_history','star','diamond','hexagon','bolt']
);
-- attendu: exact_hits=2 (circle index 0, bolt index 3), partial_hits=0, empty_hits=2
```

Note UI:
- Noir = `exact_hits`
- Blanc = `partial_hits`
- Grise = `empty_hits` (ou `4 - exact_hits - partial_hits`)

## 2) Verification arret de partie

L'arret est applique dans:
- `submit_guess` (mode classique)
- `submit_duel_guess` (duel simultane)

Checks a executer:

```sql
-- parties terminees
select id, state, winner_user_id, ended_at, stats_applied
from public.matches
where state = 'completed'
order by ended_at desc nulls last
limit 20;

-- aucune soumission supplementaire ne doit etre acceptee sur completed
-- (a tester via client: RPC submit_guess/submit_duel_guess doit lever une erreur)
```

## 3) Verification comptabilisation des stats

La comptabilisation est centralisee dans `public.apply_match_outcome_stats`.
Elle est idempotente via `matches.stats_applied`.

Checks:

```sql
-- resultat par joueur/match
select *
from public.match_player_results
order by completed_at desc
limit 50;

-- agregats par joueur
select *
from public.user_game_stats
order by matches_played desc, matches_won desc
limit 50;

-- coherence idempotence: un match complete doit avoir stats_applied=true
select id, state, stats_applied
from public.matches
where state in ('completed','canceled','expired')
order by updated_at desc
limit 50;
```

## 4) Verification mode 8 symboles

Les 8 symboles autorises sont:
- circle
- pentagon
- square
- change_history
- star
- diamond
- hexagon
- bolt

Checks:

```sql
-- exemple invalid symbol (doit echouer)
select *
from public.calculate_mastermind_feedback(
  '["circle","triangle","square","star"]'::jsonb,
  '["circle","pentagon","square","star"]'::jsonb,
  array['circle','pentagon','square','change_history','star','diamond','hexagon','bolt']
);
```

## 5) Diagnostic rapide d'un match

```sql
-- remplacer <MATCH_ID>
select m.id, m.state, m.turn_number, m.max_turns, m.winner_user_id, m.ended_at, m.stats_applied
from public.matches m
where m.id = '<MATCH_ID>'::uuid;

select *
from public.match_player_results r
where r.match_id = '<MATCH_ID>'::uuid
order by r.user_id;

select dg.*
from public.duel_guesses dg
where dg.match_id = '<MATCH_ID>'::uuid
order by dg.created_at;

select g.*
from public.guesses g
where g.match_id = '<MATCH_ID>'::uuid
order by g.created_at;
```

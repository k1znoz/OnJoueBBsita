-- Mastermind OS - Supabase bootstrap schema
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

-- Profiles linked to auth.users
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text unique,
  credits integer not null default 0,
  rank_tier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Public game modes synced from Sanity/back-office
create table if not exists public.game_modes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  short_description text,
  is_enabled boolean not null default true,
  sort_order integer not null default 0,
  sanity_doc_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Daily challenge content
create table if not exists public.daily_challenges (
  id uuid primary key default gen_random_uuid(),
  challenge_date date not null unique,
  title text not null,
  description text,
  reward_credits integer not null default 0,
  difficulty text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Match lifecycle
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  mode_id uuid not null references public.game_modes(id),
  state text not null check (state in ('draft','waiting_opponent','active','waiting_turn','completed','canceled','expired')),
  created_by_user_id uuid not null references public.user_profiles(id),
  current_turn_user_id uuid references public.user_profiles(id),
  secret_code_hash text,
  create_request_key text,
  max_turns integer not null default 10,
  turn_number integer not null default 1,
  winner_user_id uuid references public.user_profiles(id),
  started_at timestamptz,
  ended_at timestamptz,
  stats_applied boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  seat smallint not null,
  is_ready boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (match_id, user_id),
  unique (match_id, seat)
);

create table if not exists public.match_turns (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  turn_index integer not null,
  actor_user_id uuid not null references public.user_profiles(id),
  status text not null default 'open' check (status in ('open','submitted','closed')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  unique (match_id, turn_index)
);

create table if not exists public.guesses (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  turn_id uuid not null references public.match_turns(id) on delete cascade,
  actor_user_id uuid not null references public.user_profiles(id),
  payload jsonb not null,
  exact_hits integer not null default 0,
  partial_hits integer not null default 0,
  is_win boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.duel_secret_codes (
  match_id uuid not null references public.matches(id) on delete cascade,
  owner_user_id uuid not null references public.user_profiles(id) on delete cascade,
  secret_payload jsonb,
  is_locked boolean not null default false,
  solved_at timestamptz,
  solved_by_user_id uuid references public.user_profiles(id),
  solved_in_turn integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, owner_user_id)
);

create table if not exists public.duel_guesses (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  attacker_user_id uuid not null references public.user_profiles(id),
  target_user_id uuid not null references public.user_profiles(id),
  turn_index integer not null,
  payload jsonb not null,
  exact_hits integer not null default 0,
  partial_hits integer not null default 0,
  is_win boolean not null default false,
  created_at timestamptz not null default now(),
  unique (match_id, attacker_user_id, turn_index)
);

create table if not exists public.match_player_results (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  result text not null check (result in ('win', 'loss', 'draw', 'abandoned')),
  guesses_submitted integer not null default 0,
  exact_hits_total integer not null default 0,
  partial_hits_total integer not null default 0,
  turns_used integer not null default 0,
  completed_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create table if not exists public.user_game_stats (
  user_id uuid primary key references public.user_profiles(id) on delete cascade,
  matches_played integer not null default 0,
  matches_won integer not null default 0,
  matches_lost integer not null default 0,
  matches_drawn integer not null default 0,
  matches_abandoned integer not null default 0,
  guesses_submitted integer not null default 0,
  exact_hits_total integer not null default 0,
  partial_hits_total integer not null default 0,
  last_match_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.matches add column if not exists secret_code_hash text;
alter table public.matches add column if not exists create_request_key text;
alter table public.matches add column if not exists stats_applied boolean not null default false;

create table if not exists public.economy_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id),
  match_id uuid references public.matches(id) on delete set null,
  entry_type text not null check (entry_type in ('debit','credit','reward','refund')),
  amount integer not null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.player_messages (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references public.user_profiles(id) on delete cascade,
  recipient_user_id uuid not null references public.user_profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists idx_matches_creator on public.matches(created_by_user_id);
create index if not exists idx_matches_state on public.matches(state);
create index if not exists idx_match_players_user on public.match_players(user_id);
create index if not exists idx_turns_match on public.match_turns(match_id);
create index if not exists idx_guesses_match on public.guesses(match_id);
create index if not exists idx_duel_secrets_match on public.duel_secret_codes(match_id);
create index if not exists idx_duel_guesses_match on public.duel_guesses(match_id);
create index if not exists idx_duel_guesses_attacker on public.duel_guesses(attacker_user_id, match_id);
create index if not exists idx_match_player_results_user on public.match_player_results(user_id);
create index if not exists idx_ledger_user on public.economy_ledger(user_id);
create index if not exists idx_messages_sender on public.player_messages(sender_user_id, created_at desc);
create index if not exists idx_messages_recipient on public.player_messages(recipient_user_id, created_at desc);
create unique index if not exists uq_matches_creator_request_key
on public.matches(created_by_user_id, create_request_key);
create unique index if not exists uq_guesses_turn_actor
on public.guesses(turn_id, actor_user_id);

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at before update on public.user_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_game_modes_updated_at on public.game_modes;
create trigger trg_game_modes_updated_at before update on public.game_modes
for each row execute function public.touch_updated_at();

drop trigger if exists trg_daily_challenges_updated_at on public.daily_challenges;
create trigger trg_daily_challenges_updated_at before update on public.daily_challenges
for each row execute function public.touch_updated_at();

drop trigger if exists trg_matches_updated_at on public.matches;
create trigger trg_matches_updated_at before update on public.matches
for each row execute function public.touch_updated_at();

drop trigger if exists trg_duel_secret_codes_updated_at on public.duel_secret_codes;
create trigger trg_duel_secret_codes_updated_at before update on public.duel_secret_codes
for each row execute function public.touch_updated_at();

drop trigger if exists trg_user_game_stats_updated_at on public.user_game_stats;
create trigger trg_user_game_stats_updated_at before update on public.user_game_stats
for each row execute function public.touch_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_handle_base text;
  v_candidate text;
  v_suffix integer := 0;
begin
  v_handle_base := nullif(trim(coalesce(new.raw_user_meta_data ->> 'handle', '')), '');
  if v_handle_base is null then
    v_handle_base := 'u_' || substr(replace(new.id::text, '-', ''), 1, 10);
  else
    v_handle_base := regexp_replace(lower(v_handle_base), '[^a-z0-9_]', '', 'g');
    if v_handle_base = '' then
      v_handle_base := 'u_' || substr(replace(new.id::text, '-', ''), 1, 10);
    end if;
  end if;

  loop
    v_candidate := case
      when v_suffix = 0 then v_handle_base
      else v_handle_base || '_' || v_suffix::text
    end;

    exit when not exists (
      select 1
      from public.user_profiles up
      where up.handle = v_candidate
        and up.id <> new.id
    );

    v_suffix := v_suffix + 1;
  end loop;

  insert into public.user_profiles (id, handle)
  values (new.id, v_candidate)
  on conflict (id) do update
  set handle = excluded.handle;

  return new;
end;
$$;

drop trigger if exists trg_auth_user_created on auth.users;
create trigger trg_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.calculate_mastermind_feedback(
  p_guess_row jsonb,
  p_secret_row jsonb,
  p_allowed_symbols text[]
)
returns table(
  exact_hits integer,
  partial_hits integer,
  empty_hits integer,
  is_win boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exact integer := 0;
  v_partial integer := 0;
  v_guess_count integer;
  v_secret_count integer;
  v_i integer;
begin
  if jsonb_typeof(p_guess_row) is distinct from 'array' or jsonb_array_length(p_guess_row) <> 4 then
    raise exception 'Guess row must contain exactly 4 symbols';
  end if;

  if jsonb_typeof(p_secret_row) is distinct from 'array' or jsonb_array_length(p_secret_row) <> 4 then
    raise exception 'Secret row must contain exactly 4 symbols';
  end if;

  for v_i in 0..3 loop
    if p_guess_row ->> v_i = p_secret_row ->> v_i then
      v_exact := v_exact + 1;
    end if;
  end loop;

  for v_i in array_lower(p_allowed_symbols, 1)..array_upper(p_allowed_symbols, 1) loop
    select count(*) into v_guess_count
    from jsonb_array_elements_text(p_guess_row) as g(value)
    where g.value = p_allowed_symbols[v_i];

    select count(*) into v_secret_count
    from jsonb_array_elements_text(p_secret_row) as s(value)
    where s.value = p_allowed_symbols[v_i];

    v_partial := v_partial + least(v_guess_count, v_secret_count);
  end loop;

  v_partial := greatest(0, v_partial - v_exact);

  return query
  select
    v_exact,
    v_partial,
    greatest(0, 4 - v_exact - v_partial) as empty_hits,
    (v_exact = 4) as is_win;
end;
$$;

create or replace function public.apply_match_outcome_stats(
  p_match_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_user_id uuid;
  v_result text;
  v_guesses_submitted integer;
  v_exact_hits_total integer;
  v_partial_hits_total integer;
  v_turns_used integer;
begin
  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state not in ('completed', 'canceled', 'expired') then
    return;
  end if;

  if coalesce(v_match.stats_applied, false) then
    return;
  end if;

  for v_user_id in
    select mp.user_id
    from public.match_players mp
    where mp.match_id = p_match_id
  loop
    if v_match.state = 'completed' and v_match.winner_user_id is not null then
      v_result := case when v_user_id = v_match.winner_user_id then 'win' else 'loss' end;
    elsif v_match.state = 'completed' then
      v_result := 'draw';
    else
      v_result := 'abandoned';
    end if;

    select
      count(*)::integer,
      coalesce(sum(x.exact_hits), 0)::integer,
      coalesce(sum(x.partial_hits), 0)::integer,
      coalesce(max(x.turn_index), 0)::integer
    into
      v_guesses_submitted,
      v_exact_hits_total,
      v_partial_hits_total,
      v_turns_used
    from (
      select
        g.exact_hits,
        g.partial_hits,
        mt.turn_index
      from public.guesses g
      left join public.match_turns mt on mt.id = g.turn_id
      where g.match_id = p_match_id
        and g.actor_user_id = v_user_id

      union all

      select
        dg.exact_hits,
        dg.partial_hits,
        dg.turn_index
      from public.duel_guesses dg
      where dg.match_id = p_match_id
        and dg.attacker_user_id = v_user_id
    ) as x;

    insert into public.match_player_results (
      match_id,
      user_id,
      result,
      guesses_submitted,
      exact_hits_total,
      partial_hits_total,
      turns_used,
      completed_at
    )
    values (
      p_match_id,
      v_user_id,
      v_result,
      v_guesses_submitted,
      v_exact_hits_total,
      v_partial_hits_total,
      v_turns_used,
      now()
    )
    on conflict (match_id, user_id)
    do update set
      result = excluded.result,
      guesses_submitted = excluded.guesses_submitted,
      exact_hits_total = excluded.exact_hits_total,
      partial_hits_total = excluded.partial_hits_total,
      turns_used = excluded.turns_used,
      completed_at = excluded.completed_at;

    insert into public.user_game_stats (
      user_id,
      matches_played,
      matches_won,
      matches_lost,
      matches_drawn,
      matches_abandoned,
      guesses_submitted,
      exact_hits_total,
      partial_hits_total,
      last_match_at
    )
    values (
      v_user_id,
      1,
      case when v_result = 'win' then 1 else 0 end,
      case when v_result = 'loss' then 1 else 0 end,
      case when v_result = 'draw' then 1 else 0 end,
      case when v_result = 'abandoned' then 1 else 0 end,
      v_guesses_submitted,
      v_exact_hits_total,
      v_partial_hits_total,
      now()
    )
    on conflict (user_id)
    do update set
      matches_played = public.user_game_stats.matches_played + 1,
      matches_won = public.user_game_stats.matches_won + case when v_result = 'win' then 1 else 0 end,
      matches_lost = public.user_game_stats.matches_lost + case when v_result = 'loss' then 1 else 0 end,
      matches_drawn = public.user_game_stats.matches_drawn + case when v_result = 'draw' then 1 else 0 end,
      matches_abandoned = public.user_game_stats.matches_abandoned + case when v_result = 'abandoned' then 1 else 0 end,
      guesses_submitted = public.user_game_stats.guesses_submitted + v_guesses_submitted,
      exact_hits_total = public.user_game_stats.exact_hits_total + v_exact_hits_total,
      partial_hits_total = public.user_game_stats.partial_hits_total + v_partial_hits_total,
      last_match_at = now(),
      updated_at = now();
  end loop;

  update public.matches
  set
    stats_applied = true,
    updated_at = now()
  where id = p_match_id;
end;
$$;

-- Atomic gameplay functions
create or replace function public.create_match(
  p_mode_id uuid,
  p_max_turns integer default 10,
  p_idempotency_key text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
  v_secret_symbols text[] := array[]::text[];
  v_i integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'Idempotency key is required';
  end if;

  if not exists (
    select 1 from public.game_modes gm
    where gm.id = p_mode_id and gm.is_enabled = true
  ) then
    raise exception 'Mode unavailable';
  end if;

  for v_i in 1..4 loop
    v_secret_symbols := v_secret_symbols || v_allowed_symbols[
      1 + floor(random() * array_length(v_allowed_symbols, 1))::integer
    ];
  end loop;

  insert into public.matches (
    mode_id,
    state,
    created_by_user_id,
    current_turn_user_id,
    secret_code_hash,
    create_request_key,
    max_turns
  )
  values (
    p_mode_id,
    'active',
    v_uid,
    v_uid,
    to_jsonb(v_secret_symbols)::text,
    p_idempotency_key,
    greatest(1, coalesce(p_max_turns, 10))
  )
  on conflict (created_by_user_id, create_request_key)
  do update set updated_at = now()
  returning * into v_match;

  insert into public.match_players (match_id, user_id, seat, is_ready)
  values (v_match.id, v_uid, 1, true)
  on conflict (match_id, user_id) do nothing;

  return v_match;
end;
$$;

create or replace function public.submit_guess(
  p_match_id uuid,
  p_payload jsonb
)
returns public.guesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_turn public.match_turns;
  v_guess public.guesses;
  v_next_user_id uuid;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
  v_secret_symbols text[] := array[]::text[];
  v_guess_row jsonb;
  v_secret_row jsonb;
  v_exact_hits integer := 0;
  v_partial_hits integer := 0;
  v_guess_count integer;
  v_secret_count integer;
  v_is_win boolean := false;
  v_empty_hits integer := 0;
  v_i integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state not in ('draft', 'active', 'waiting_turn') then
    raise exception 'Match not writable in current state';
  end if;

  if v_match.current_turn_user_id is distinct from v_uid then
    raise exception 'Not your turn';
  end if;

  v_guess_row := coalesce(p_payload -> 'row', '[]'::jsonb);

  if jsonb_typeof(v_guess_row) is distinct from 'array' then
    raise exception 'Payload row must be an array';
  end if;

  if jsonb_array_length(v_guess_row) <> 4 then
    raise exception 'Payload row must contain exactly 4 symbols';
  end if;

  if exists (
    select 1
    from jsonb_array_elements_text(v_guess_row) as g(value)
    where not (g.value = any (v_allowed_symbols))
  ) then
    raise exception 'Payload row contains invalid symbols';
  end if;

  begin
    v_secret_row := coalesce(v_match.secret_code_hash, '[]')::jsonb;
  exception when others then
    v_secret_row := '[]'::jsonb;
  end;

  if jsonb_typeof(v_secret_row) is distinct from 'array' or jsonb_array_length(v_secret_row) <> 4 then
    v_secret_symbols := array[]::text[];

    for v_i in 1..4 loop
      v_secret_symbols := v_secret_symbols || v_allowed_symbols[
        1 + floor(random() * array_length(v_allowed_symbols, 1))::integer
      ];
    end loop;

    v_secret_row := to_jsonb(v_secret_symbols);

    update public.matches
    set
      secret_code_hash = v_secret_row::text,
      updated_at = now()
    where id = p_match_id;
  end if;

  select
    f.exact_hits,
    f.partial_hits,
    f.empty_hits,
    f.is_win
  into
    v_exact_hits,
    v_partial_hits,
    v_empty_hits,
    v_is_win
  from public.calculate_mastermind_feedback(v_guess_row, v_secret_row, v_allowed_symbols) f;

  select * into v_turn
  from public.match_turns t
  where t.match_id = p_match_id and t.turn_index = v_match.turn_number;

  if v_turn.id is null then
    insert into public.match_turns (match_id, turn_index, actor_user_id, status)
    values (p_match_id, v_match.turn_number, v_uid, 'open')
    returning * into v_turn;
  end if;

  if exists (
    select 1
    from public.guesses g
    where g.turn_id = v_turn.id and g.actor_user_id = v_uid
  ) then
    raise exception 'Guess already submitted for this turn';
  end if;

  insert into public.guesses (
    match_id,
    turn_id,
    actor_user_id,
    payload,
    exact_hits,
    partial_hits,
    is_win
  )
  values (
    p_match_id,
    v_turn.id,
    v_uid,
    coalesce(p_payload, '{}'::jsonb),
    v_exact_hits,
    v_partial_hits,
    v_is_win
  )
  returning * into v_guess;

  update public.match_turns
  set status = 'submitted', submitted_at = now()
  where id = v_turn.id;

  select mp.user_id into v_next_user_id
  from public.match_players mp
  where mp.match_id = p_match_id
    and mp.user_id <> v_uid
  order by mp.seat
  limit 1;

  if v_is_win then
    update public.matches
    set
      state = 'completed',
      ended_at = now(),
      winner_user_id = v_uid,
      current_turn_user_id = null,
      updated_at = now()
    where id = p_match_id;
  elsif v_match.turn_number >= v_match.max_turns then
    update public.matches
    set
      state = 'completed',
      ended_at = now(),
      current_turn_user_id = null,
      updated_at = now()
    where id = p_match_id;
  else
    update public.matches
    set
      state = 'active',
      turn_number = v_match.turn_number + 1,
      current_turn_user_id = coalesce(v_next_user_id, v_uid),
      updated_at = now()
    where id = p_match_id;
  end if;

  if exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.state in ('completed', 'canceled', 'expired')
      and coalesce(m.stats_applied, false) = false
  ) then
    perform public.apply_match_outcome_stats(p_match_id);
  end if;

  return v_guess;
end;
$$;

create or replace function public.join_or_create_duel(
  p_mode_id uuid,
  p_max_turns integer default 10,
  p_idempotency_key text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
  v_secret_symbols text[] := array[]::text[];
  v_i integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.game_modes gm
    where gm.id = p_mode_id and gm.is_enabled = true
  ) then
    raise exception 'Mode unavailable';
  end if;

  -- Try joining oldest waiting duel first.
  select m.* into v_match
  from public.matches m
  where m.mode_id = p_mode_id
    and m.state = 'waiting_opponent'
    and m.created_by_user_id <> v_uid
    and not exists (
      select 1 from public.match_players me
      where me.match_id = m.id and me.user_id = v_uid
    )
    and (
      select count(*)
      from public.match_players mp
      where mp.match_id = m.id
    ) < 2
  order by m.created_at asc
  for update skip locked
  limit 1;

  if v_match.id is not null then
    insert into public.match_players (match_id, user_id, seat, is_ready)
    values (v_match.id, v_uid, 2, true)
    on conflict (match_id, user_id) do nothing;

    update public.matches
    set
      state = 'active',
      started_at = coalesce(started_at, now()),
      updated_at = now()
    where id = v_match.id
    returning * into v_match;

    return v_match;
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    p_idempotency_key := 'duel_' || replace(v_uid::text, '-', '') || '_' || floor(extract(epoch from clock_timestamp()))::text;
  end if;

  for v_i in 1..4 loop
    v_secret_symbols := v_secret_symbols || v_allowed_symbols[
      1 + floor(random() * array_length(v_allowed_symbols, 1))::integer
    ];
  end loop;

  insert into public.matches (
    mode_id,
    state,
    created_by_user_id,
    current_turn_user_id,
    secret_code_hash,
    create_request_key,
    max_turns
  )
  values (
    p_mode_id,
    'waiting_opponent',
    v_uid,
    v_uid,
    to_jsonb(v_secret_symbols)::text,
    p_idempotency_key,
    greatest(1, coalesce(p_max_turns, 10))
  )
  on conflict (created_by_user_id, create_request_key)
  do update set updated_at = now()
  returning * into v_match;

  insert into public.match_players (match_id, user_id, seat, is_ready)
  values (v_match.id, v_uid, 1, true)
  on conflict (match_id, user_id) do nothing;

  insert into public.duel_secret_codes (match_id, owner_user_id)
  values (v_match.id, v_uid)
  on conflict (match_id, owner_user_id) do update set updated_at = now();

  return v_match;
end;
$$;

create or replace function public.list_duel_opponents()
returns table(id uuid, handle text)
language sql
security definer
set search_path = public
as $$
  select up.id, coalesce(up.handle, 'u_' || substr(replace(up.id::text, '-', ''), 1, 8)) as handle
  from public.user_profiles up
  where up.id <> auth.uid()
  order by up.handle nulls last, up.created_at desc
  limit 100;
$$;

create or replace function public.create_duel_invite(
  p_mode_id uuid,
  p_opponent_id uuid,
  p_max_turns integer default 10,
  p_idempotency_key text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
  v_secret_symbols text[] := array[]::text[];
  v_i integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if p_opponent_id is null or p_opponent_id = v_uid then
    raise exception 'Invalid opponent';
  end if;

  if not exists (select 1 from public.user_profiles up where up.id = p_opponent_id) then
    raise exception 'Opponent not found';
  end if;

  if not exists (
    select 1 from public.game_modes gm
    where gm.id = p_mode_id and gm.is_enabled = true
  ) then
    raise exception 'Mode unavailable';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    p_idempotency_key := 'duel_invite_' || replace(v_uid::text, '-', '') || '_' || replace(p_opponent_id::text, '-', '');
  end if;

  for v_i in 1..4 loop
    v_secret_symbols := v_secret_symbols || v_allowed_symbols[
      1 + floor(random() * array_length(v_allowed_symbols, 1))::integer
    ];
  end loop;

  insert into public.matches (
    mode_id,
    state,
    created_by_user_id,
    current_turn_user_id,
    secret_code_hash,
    create_request_key,
    max_turns
  )
  values (
    p_mode_id,
    'waiting_opponent',
    v_uid,
    v_uid,
    to_jsonb(v_secret_symbols)::text,
    p_idempotency_key,
    greatest(1, coalesce(p_max_turns, 10))
  )
  on conflict (created_by_user_id, create_request_key)
  do update set updated_at = now()
  returning * into v_match;

  insert into public.match_players (match_id, user_id, seat, is_ready)
  values
    (v_match.id, v_uid, 1, true),
    (v_match.id, p_opponent_id, 2, false)
  on conflict (match_id, user_id) do update
  set seat = excluded.seat;

  insert into public.duel_secret_codes (match_id, owner_user_id)
  values
    (v_match.id, v_uid),
    (v_match.id, p_opponent_id)
  on conflict (match_id, owner_user_id) do update set updated_at = now();

  return v_match;
end;
$$;

create or replace function public.set_duel_secret_code(
  p_match_id uuid,
  p_payload jsonb
)
returns public.duel_secret_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_row public.duel_secret_codes;
  v_symbols jsonb;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state in ('completed', 'canceled', 'expired') then
    raise exception 'Match already closed';
  end if;

  v_symbols := coalesce(p_payload -> 'row', '[]'::jsonb);

  if jsonb_typeof(v_symbols) is distinct from 'array' or jsonb_array_length(v_symbols) <> 4 then
    raise exception 'Secret row must contain exactly 4 symbols';
  end if;

  if exists (
    select 1
    from jsonb_array_elements_text(v_symbols) as s(value)
    where not (s.value = any (v_allowed_symbols))
  ) then
    raise exception 'Secret row contains invalid symbols';
  end if;

  insert into public.duel_secret_codes (match_id, owner_user_id, secret_payload, is_locked, updated_at)
  values (p_match_id, v_uid, v_symbols, true, now())
  on conflict (match_id, owner_user_id)
  do update set
    secret_payload = excluded.secret_payload,
    is_locked = true,
    updated_at = now()
  returning * into v_row;

  if (
    select count(*)
    from public.duel_secret_codes dsc
    where dsc.match_id = p_match_id
      and dsc.is_locked = true
      and dsc.secret_payload is not null
  ) >= 2 and v_match.state = 'waiting_opponent' then
    update public.matches
    set
      state = 'active',
      started_at = coalesce(started_at, now()),
      updated_at = now()
    where id = p_match_id;
  end if;

  return v_row;
end;
$$;

create or replace function public.submit_duel_guess(
  p_match_id uuid,
  p_payload jsonb
)
returns public.duel_guesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_target_user_id uuid;
  v_target_secret jsonb;
  v_guess_row jsonb;
  v_guess public.duel_guesses;
  v_turn_index integer;
  v_exact_hits integer := 0;
  v_partial_hits integer := 0;
  v_guess_count integer;
  v_secret_count integer;
  v_is_win boolean := false;
  v_empty_hits integer := 0;
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond', 'hexagon', 'bolt'];
  v_i integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state <> 'active' then
    raise exception 'Match is not active';
  end if;

  select mp.user_id into v_target_user_id
  from public.match_players mp
  where mp.match_id = p_match_id
    and mp.user_id <> v_uid
  order by mp.seat
  limit 1;

  if v_target_user_id is null then
    raise exception 'No opponent found';
  end if;

  select dsc.secret_payload into v_target_secret
  from public.duel_secret_codes dsc
  where dsc.match_id = p_match_id
    and dsc.owner_user_id = v_target_user_id
    and dsc.is_locked = true;

  if v_target_secret is null then
    raise exception 'Opponent secret not ready';
  end if;

  v_guess_row := coalesce(p_payload -> 'row', '[]'::jsonb);

  if jsonb_typeof(v_guess_row) is distinct from 'array' or jsonb_array_length(v_guess_row) <> 4 then
    raise exception 'Payload row must contain exactly 4 symbols';
  end if;

  if exists (
    select 1
    from jsonb_array_elements_text(v_guess_row) as g(value)
    where not (g.value = any (v_allowed_symbols))
  ) then
    raise exception 'Payload row contains invalid symbols';
  end if;

  select coalesce(max(dg.turn_index), 0) + 1 into v_turn_index
  from public.duel_guesses dg
  where dg.match_id = p_match_id and dg.attacker_user_id = v_uid;

  if v_turn_index > v_match.max_turns then
    raise exception 'Maximum turns reached';
  end if;

  select
    f.exact_hits,
    f.partial_hits,
    f.empty_hits,
    f.is_win
  into
    v_exact_hits,
    v_partial_hits,
    v_empty_hits,
    v_is_win
  from public.calculate_mastermind_feedback(v_guess_row, v_target_secret, v_allowed_symbols) f;

  insert into public.duel_guesses (
    match_id,
    attacker_user_id,
    target_user_id,
    turn_index,
    payload,
    exact_hits,
    partial_hits,
    is_win
  )
  values (
    p_match_id,
    v_uid,
    v_target_user_id,
    v_turn_index,
    p_payload,
    v_exact_hits,
    v_partial_hits,
    v_is_win
  )
  returning * into v_guess;

  if v_is_win then
    update public.duel_secret_codes
    set
      solved_at = now(),
      solved_by_user_id = v_uid,
      solved_in_turn = v_turn_index,
      updated_at = now()
    where match_id = p_match_id
      and owner_user_id = v_target_user_id
      and solved_at is null;

    update public.matches
    set
      state = 'completed',
      ended_at = now(),
      winner_user_id = v_uid,
      current_turn_user_id = null,
      updated_at = now()
    where id = p_match_id
      and state = 'active';
  elsif (
    select count(*)
    from public.duel_guesses dg
    where dg.match_id = p_match_id
      and dg.attacker_user_id = v_uid
  ) >= v_match.max_turns and (
    select count(*)
    from public.duel_guesses dg
    where dg.match_id = p_match_id
      and dg.attacker_user_id = v_target_user_id
  ) >= v_match.max_turns then
    update public.matches
    set
      state = 'completed',
      ended_at = now(),
      current_turn_user_id = null,
      updated_at = now()
    where id = p_match_id
      and state = 'active';
  end if;

  if exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and m.state in ('completed', 'canceled', 'expired')
      and coalesce(m.stats_applied, false) = false
  ) then
    perform public.apply_match_outcome_stats(p_match_id);
  end if;

  return v_guess;
end;
$$;

create or replace function public.get_duel_board(
  p_match_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_opponent_id uuid;
  v_my_secret_ready boolean := false;
  v_opponent_secret_ready boolean := false;
  v_result jsonb;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  select mp.user_id into v_opponent_id
  from public.match_players mp
  where mp.match_id = p_match_id and mp.user_id <> v_uid
  order by mp.seat
  limit 1;

  select exists (
    select 1
    from public.duel_secret_codes dsc
    where dsc.match_id = p_match_id
      and dsc.owner_user_id = v_uid
      and dsc.is_locked = true
      and dsc.secret_payload is not null
  ) into v_my_secret_ready;

  select exists (
    select 1
    from public.duel_secret_codes dsc
    where dsc.match_id = p_match_id
      and dsc.owner_user_id = v_opponent_id
      and dsc.is_locked = true
      and dsc.secret_payload is not null
  ) into v_opponent_secret_ready;

  select jsonb_build_object(
    'mySecretReady', v_my_secret_ready,
    'opponentSecretReady', v_opponent_secret_ready,
    'myGuesses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dg.id,
        'turn', dg.turn_index,
        'row', coalesce(dg.payload -> 'row', '[]'::jsonb),
        'exactHits', dg.exact_hits,
        'partialHits', dg.partial_hits,
        'isWin', dg.is_win,
        'createdAt', dg.created_at
      ) order by dg.turn_index asc)
      from public.duel_guesses dg
      where dg.match_id = p_match_id
        and dg.attacker_user_id = v_uid
    ), '[]'::jsonb),
    'opponentGuesses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dg.id,
        'turn', dg.turn_index,
        'row', coalesce(dg.payload -> 'row', '[]'::jsonb),
        'exactHits', dg.exact_hits,
        'partialHits', dg.partial_hits,
        'isWin', dg.is_win,
        'createdAt', dg.created_at
      ) order by dg.turn_index asc)
      from public.duel_guesses dg
      where dg.match_id = p_match_id
        and dg.attacker_user_id = v_opponent_id
    ), '[]'::jsonb)
  ) into v_result;

  return coalesce(v_result, '{}'::jsonb);
end;
$$;

create or replace function public.accept_duel_invite(
  p_match_id uuid
)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state <> 'waiting_opponent' then
    return v_match;
  end if;

  if not exists (
    select 1
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  update public.match_players
  set is_ready = true
  where match_id = p_match_id and user_id = v_uid;

  if (
    select count(*)
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.is_ready = true
  ) >= 2 then
    update public.matches
    set
      state = 'active',
      started_at = coalesce(started_at, now()),
      updated_at = now()
    where id = p_match_id
    returning * into v_match;
  end if;

  return v_match;
end;
$$;

create or replace function public.list_duel_invites()
returns table(
  match_id uuid,
  mode_id uuid,
  mode_title text,
  inviter_id uuid,
  inviter_handle text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    m.id as match_id,
    m.mode_id,
    gm.title as mode_title,
    m.created_by_user_id as inviter_id,
    coalesce(up.handle, 'u_' || substr(replace(up.id::text, '-', ''), 1, 8)) as inviter_handle,
    m.created_at
  from public.matches m
  join public.match_players invited on invited.match_id = m.id
  join public.game_modes gm on gm.id = m.mode_id
  join public.user_profiles up on up.id = m.created_by_user_id
  where invited.user_id = auth.uid()
    and invited.seat = 2
    and invited.is_ready = false
    and m.state = 'waiting_opponent'
  order by m.created_at desc;
$$;

create or replace function public.cancel_match(
  p_match_id uuid
)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.created_by_user_id <> v_uid then
    raise exception 'Only creator can cancel this match';
  end if;

  if v_match.state in ('completed', 'canceled', 'expired') then
    return v_match;
  end if;

  update public.matches
  set
    state = 'canceled',
    ended_at = coalesce(ended_at, now()),
    current_turn_user_id = null,
    updated_at = now()
  where id = p_match_id
  returning * into v_match;

  return v_match;
end;
$$;

create or replace function public.delete_match(
  p_match_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_deleted integer;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  delete from public.matches m
  where m.id = p_match_id
    and m.created_by_user_id = v_uid
    and m.state in ('completed', 'canceled', 'expired');

  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke execute on function public.create_match(uuid, integer, text) from public;
revoke execute on function public.submit_guess(uuid, jsonb) from public;
revoke execute on function public.join_or_create_duel(uuid, integer, text) from public;
revoke execute on function public.list_duel_opponents() from public;
revoke execute on function public.create_duel_invite(uuid, uuid, integer, text) from public;
revoke execute on function public.accept_duel_invite(uuid) from public;
revoke execute on function public.list_duel_invites() from public;
revoke execute on function public.cancel_match(uuid) from public;
revoke execute on function public.delete_match(uuid) from public;
grant execute on function public.create_match(uuid, integer, text) to authenticated;
grant execute on function public.submit_guess(uuid, jsonb) to authenticated;
grant execute on function public.join_or_create_duel(uuid, integer, text) to authenticated;
grant execute on function public.list_duel_opponents() to authenticated;
grant execute on function public.create_duel_invite(uuid, uuid, integer, text) to authenticated;
grant execute on function public.accept_duel_invite(uuid) to authenticated;
grant execute on function public.list_duel_invites() to authenticated;
grant execute on function public.cancel_match(uuid) to authenticated;
grant execute on function public.delete_match(uuid) to authenticated;

-- Explicit privileges for PostgREST roles.
grant usage on schema public to anon, authenticated;
grant select on public.game_modes to anon, authenticated;
grant select on public.daily_challenges to anon, authenticated;
grant select on public.user_profiles to authenticated;
grant select on public.matches to authenticated;
grant select on public.match_players to authenticated;
grant select on public.match_turns to authenticated;
grant select on public.guesses to authenticated;
grant select on public.economy_ledger to authenticated;
grant select, insert on public.player_messages to authenticated;
grant insert, update on public.user_profiles to authenticated;

-- RLS
alter table public.user_profiles enable row level security;
alter table public.game_modes enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.match_turns enable row level security;
alter table public.guesses enable row level security;
alter table public.duel_secret_codes enable row level security;
alter table public.duel_guesses enable row level security;
alter table public.match_player_results enable row level security;
alter table public.user_game_stats enable row level security;
alter table public.economy_ledger enable row level security;
alter table public.player_messages enable row level security;

-- Public read for catalog data
drop policy if exists "public read game modes" on public.game_modes;
create policy "public read game modes"
on public.game_modes for select
using (is_enabled = true);

drop policy if exists "public read active daily challenge" on public.daily_challenges;
create policy "public read active daily challenge"
on public.daily_challenges for select
using (is_active = true);

-- Profile access
drop policy if exists "user read own profile" on public.user_profiles;
create policy "user read own profile"
on public.user_profiles for select
using (auth.uid() = id);

drop policy if exists "user insert own profile" on public.user_profiles;
create policy "user insert own profile"
on public.user_profiles for insert
with check (auth.uid() = id);

drop policy if exists "user update own profile" on public.user_profiles;
create policy "user update own profile"
on public.user_profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Match access: user must be in match_players
create or replace function public.is_match_participant(p_match_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.match_players mp
    where mp.match_id = p_match_id
      and mp.user_id = auth.uid()
  );
$$;

drop policy if exists "participants read matches" on public.matches;
create policy "participants read matches"
on public.matches for select
using (public.is_match_participant(matches.id));

drop policy if exists "creator insert matches" on public.matches;
create policy "creator insert matches"
on public.matches for insert
with check (false);

drop policy if exists "participants read players" on public.match_players;
create policy "participants read players"
on public.match_players for select
using (public.is_match_participant(match_players.match_id));

drop policy if exists "user join self" on public.match_players;
create policy "user join self"
on public.match_players for insert
with check (false);

drop policy if exists "participants read turns" on public.match_turns;
create policy "participants read turns"
on public.match_turns for select
using (public.is_match_participant(match_turns.match_id));

drop policy if exists "participants read guesses" on public.guesses;
create policy "participants read guesses"
on public.guesses for select
using (public.is_match_participant(guesses.match_id));

drop policy if exists "actor insert guess" on public.guesses;
create policy "actor insert guess"
on public.guesses for insert
with check (false);

drop policy if exists "user read own ledger" on public.economy_ledger;
create policy "user read own ledger"
on public.economy_ledger for select
using (user_id = auth.uid());

drop policy if exists "participants read own messages" on public.player_messages;
create policy "participants read own messages"
on public.player_messages for select
using (sender_user_id = auth.uid() or recipient_user_id = auth.uid());

drop policy if exists "sender insert message" on public.player_messages;
create policy "sender insert message"
on public.player_messages for insert
with check (
  sender_user_id = auth.uid()
  and recipient_user_id <> auth.uid()
);

-- Bootstrap data: ensure at least one playable mode exists.
insert into public.game_modes (code, title, short_description, is_enabled, sort_order)
values (
  'classic_async',
  'Classic Solo',
  'Code secret random (style IA), 4 slots, palette standard.',
  true,
  10
)
on conflict (code) do update
set
  title = excluded.title,
  short_description = excluded.short_description,
  is_enabled = true,
  sort_order = excluded.sort_order,
  updated_at = now();

insert into public.game_modes (code, title, short_description, is_enabled, sort_order)
values (
  'duel_async',
  'Duel 1v1',
  'Rejoint automatiquement un adversaire en attente, sinon cree un duel.',
  true,
  20
)
on conflict (code) do update
set
  title = excluded.title,
  short_description = excluded.short_description,
  is_enabled = true,
  sort_order = excluded.sort_order,
  updated_at = now();

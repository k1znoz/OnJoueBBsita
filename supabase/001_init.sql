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

alter table public.matches add column if not exists secret_code_hash text;
alter table public.matches add column if not exists create_request_key text;

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
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond'];
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
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond'];
  v_guess_row jsonb;
  v_secret_row jsonb;
  v_exact_hits integer := 0;
  v_partial_hits integer := 0;
  v_guess_count integer;
  v_secret_count integer;
  v_is_win boolean := false;
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
    raise exception 'Match secret code unavailable';
  end;

  if jsonb_typeof(v_secret_row) is distinct from 'array' or jsonb_array_length(v_secret_row) <> 4 then
    raise exception 'Match secret code unavailable';
  end if;

  for v_i in 0..3 loop
    if v_guess_row ->> v_i = v_secret_row ->> v_i then
      v_exact_hits := v_exact_hits + 1;
    end if;
  end loop;

  for v_i in array_lower(v_allowed_symbols, 1)..array_upper(v_allowed_symbols, 1) loop
    select count(*) into v_guess_count
    from jsonb_array_elements_text(v_guess_row) as g(value)
    where g.value = v_allowed_symbols[v_i];

    select count(*) into v_secret_count
    from jsonb_array_elements_text(v_secret_row) as s(value)
    where s.value = v_allowed_symbols[v_i];

    v_partial_hits := v_partial_hits + least(v_guess_count, v_secret_count);
  end loop;

  v_partial_hits := greatest(0, v_partial_hits - v_exact_hits);
  v_is_win := v_exact_hits = 4;

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
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond'];
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
  v_allowed_symbols text[] := array['circle', 'pentagon', 'square', 'change_history', 'star', 'diamond'];
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

  return v_match;
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

revoke execute on function public.create_match(uuid, integer, text) from public;
revoke execute on function public.submit_guess(uuid, jsonb) from public;
revoke execute on function public.join_or_create_duel(uuid, integer, text) from public;
revoke execute on function public.list_duel_opponents() from public;
revoke execute on function public.create_duel_invite(uuid, uuid, integer, text) from public;
revoke execute on function public.accept_duel_invite(uuid) from public;
revoke execute on function public.list_duel_invites() from public;
grant execute on function public.create_match(uuid, integer, text) to authenticated;
grant execute on function public.submit_guess(uuid, jsonb) to authenticated;
grant execute on function public.join_or_create_duel(uuid, integer, text) to authenticated;
grant execute on function public.list_duel_opponents() to authenticated;
grant execute on function public.create_duel_invite(uuid, uuid, integer, text) to authenticated;
grant execute on function public.accept_duel_invite(uuid) to authenticated;
grant execute on function public.list_duel_invites() to authenticated;

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
drop policy if exists "participants read matches" on public.matches;
create policy "participants read matches"
on public.matches for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = matches.id and mp.user_id = auth.uid()
  )
);

drop policy if exists "creator insert matches" on public.matches;
create policy "creator insert matches"
on public.matches for insert
with check (false);

drop policy if exists "participants read players" on public.match_players;
create policy "participants read players"
on public.match_players for select
using (
  exists (
    select 1 from public.match_players me
    where me.match_id = match_players.match_id and me.user_id = auth.uid()
  )
);

drop policy if exists "user join self" on public.match_players;
create policy "user join self"
on public.match_players for insert
with check (false);

drop policy if exists "participants read turns" on public.match_turns;
create policy "participants read turns"
on public.match_turns for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = match_turns.match_id and mp.user_id = auth.uid()
  )
);

drop policy if exists "participants read guesses" on public.guesses;
create policy "participants read guesses"
on public.guesses for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = guesses.match_id and mp.user_id = auth.uid()
  )
);

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

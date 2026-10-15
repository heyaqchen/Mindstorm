-- Mindstorm Bunch cloud storage, links and membership.
-- Apply after 001-account.sql in the existing project's SQL Editor.
begin;

create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.mindstorm_bunches (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 8388608),
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.mindstorm_bunch_members (
  bunch_id uuid not null references public.mindstorm_bunches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','editor','viewer')),
  joined_at timestamptz not null default now(),
  primary key (bunch_id,user_id)
);
create index if not exists mindstorm_bunch_members_user on public.mindstorm_bunch_members(user_id);
create table if not exists public.mindstorm_bunch_invites (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  bunch_id uuid not null references public.mindstorm_bunches(id) on delete cascade,
  role text not null check (role in ('editor','viewer')),
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at > created_at and expires_at <= created_at + interval '30 days')
);
create index if not exists mindstorm_bunch_invites_bunch on public.mindstorm_bunch_invites(bunch_id);

alter table public.mindstorm_bunches enable row level security;
alter table public.mindstorm_bunch_members enable row level security;
alter table public.mindstorm_bunch_invites enable row level security;
revoke all on public.mindstorm_bunches,public.mindstorm_bunch_members,public.mindstorm_bunch_invites from anon,authenticated;
grant select,insert on public.mindstorm_bunches to authenticated;
grant update(title,payload,version,updated_at) on public.mindstorm_bunches to authenticated;
grant select,delete on public.mindstorm_bunch_members to authenticated;
grant update(role) on public.mindstorm_bunch_members to authenticated;
grant select,insert,delete on public.mindstorm_bunch_invites to authenticated;

create or replace function private.mindstorm_role(p_bunch uuid)
returns text language sql stable security definer set search_path = '' as $$
  select m.role from public.mindstorm_bunch_members m
  where m.bunch_id = p_bunch and m.user_id = (select auth.uid())
$$;
revoke all on function private.mindstorm_role(uuid) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.mindstorm_role(uuid) to authenticated;

create or replace function private.mindstorm_owner(p_bunch uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.mindstorm_bunches b
    where b.id = p_bunch and b.owner_id = (select auth.uid()))
$$;
revoke all on function private.mindstorm_owner(uuid) from public,anon;
grant execute on function private.mindstorm_owner(uuid) to authenticated;

create or replace function private.mindstorm_shared_profile(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.mindstorm_bunch_members mine
    join public.mindstorm_bunch_members theirs on theirs.bunch_id=mine.bunch_id
    where mine.user_id=(select auth.uid()) and theirs.user_id=p_user)
$$;
revoke all on function private.mindstorm_shared_profile(uuid) from public,anon;
grant execute on function private.mindstorm_shared_profile(uuid) to authenticated;

create or replace function private.mindstorm_add_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.mindstorm_bunch_members(bunch_id,user_id,role)
  values(new.id,new.owner_id,'owner');
  return new;
end;
$$;
revoke all on function private.mindstorm_add_owner() from public,anon,authenticated;
drop trigger if exists mindstorm_bunch_owner on public.mindstorm_bunches;
create trigger mindstorm_bunch_owner after insert on public.mindstorm_bunches
  for each row execute function private.mindstorm_add_owner();

drop policy if exists mindstorm_bunch_read on public.mindstorm_bunches;
create policy mindstorm_bunch_read on public.mindstorm_bunches for select to authenticated
  using (owner_id=(select auth.uid()) or private.mindstorm_role(id) is not null);
drop policy if exists mindstorm_bunch_create on public.mindstorm_bunches;
create policy mindstorm_bunch_create on public.mindstorm_bunches for insert to authenticated
  with check (owner_id=(select auth.uid()) and version=1);
drop policy if exists mindstorm_bunch_write on public.mindstorm_bunches;
create policy mindstorm_bunch_write on public.mindstorm_bunches for update to authenticated
  using (private.mindstorm_role(id) in ('owner','editor'))
  with check (private.mindstorm_role(id) in ('owner','editor'));

drop policy if exists mindstorm_member_read on public.mindstorm_bunch_members;
create policy mindstorm_member_read on public.mindstorm_bunch_members for select to authenticated
  using (private.mindstorm_role(bunch_id) is not null);
drop policy if exists mindstorm_member_update on public.mindstorm_bunch_members;
create policy mindstorm_member_update on public.mindstorm_bunch_members for update to authenticated
  using (private.mindstorm_owner(bunch_id) and role <> 'owner')
  with check (private.mindstorm_owner(bunch_id) and role in ('editor','viewer'));
drop policy if exists mindstorm_member_delete on public.mindstorm_bunch_members;
create policy mindstorm_member_delete on public.mindstorm_bunch_members for delete to authenticated
  using (private.mindstorm_owner(bunch_id) and role <> 'owner');

drop policy if exists mindstorm_invite_owner on public.mindstorm_bunch_invites;
create policy mindstorm_invite_owner on public.mindstorm_bunch_invites for all to authenticated
  using (private.mindstorm_owner(bunch_id))
  with check (private.mindstorm_owner(bunch_id) and created_by=(select auth.uid()));

drop policy if exists mindstorm_read_bunch_profile on public.mindstorm_profiles;
create policy mindstorm_read_bunch_profile on public.mindstorm_profiles for select to authenticated
  using (private.mindstorm_shared_profile(id));

create or replace function public.mindstorm_join_bunch(p_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_invite public.mindstorm_bunch_invites%rowtype;
begin
  if v_user is null then raise exception '请先登录'; end if;
  if p_token is null or char_length(p_token) <> 64 or p_token !~ '^[0-9a-f]{64}$'
    then raise exception '分享链接无效'; end if;
  select * into v_invite from public.mindstorm_bunch_invites
    where token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
    and expires_at>now() for update;
  if not found then raise exception '分享链接已失效'; end if;
  if not exists(select 1 from public.mindstorm_bunches where id=v_invite.bunch_id)
    then raise exception 'Bunch 不存在'; end if;
  insert into public.mindstorm_bunch_members(bunch_id,user_id,role)
    values(v_invite.bunch_id,v_user,v_invite.role)
    on conflict (bunch_id,user_id) do nothing;
  return v_invite.bunch_id;
end;
$$;
revoke all on function public.mindstorm_join_bunch(text) from public,anon;
grant execute on function public.mindstorm_join_bunch(text) to authenticated;

commit;

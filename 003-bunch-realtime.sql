-- Lightweight Realtime notifications for shared Bunch updates.
-- Apply after 002-bunch-cloud.sql. Clients receive only the Bunch id/version,
-- then fetch the payload through the existing RLS-protected Bunch table.
begin;

create table if not exists public.mindstorm_bunch_signals (
  bunch_id uuid primary key references public.mindstorm_bunches(id) on delete cascade,
  version bigint not null check (version > 0),
  updated_at timestamptz not null default now()
);
alter table public.mindstorm_bunch_signals enable row level security;
revoke all on public.mindstorm_bunch_signals from anon,authenticated;
grant select on public.mindstorm_bunch_signals to authenticated;
drop policy if exists mindstorm_bunch_signal_read on public.mindstorm_bunch_signals;
create policy mindstorm_bunch_signal_read on public.mindstorm_bunch_signals for select to authenticated
  using (private.mindstorm_role(bunch_id) is not null);

create or replace function private.mindstorm_bump_bunch_signal()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.mindstorm_bunch_signals(bunch_id,version,updated_at)
    values(new.id,new.version,now())
  on conflict (bunch_id) do update
    set version=excluded.version,updated_at=excluded.updated_at;
  return new;
end;
$$;
revoke all on function private.mindstorm_bump_bunch_signal() from public,anon,authenticated;
drop trigger if exists mindstorm_bunch_signal_update on public.mindstorm_bunches;
create trigger mindstorm_bunch_signal_update after update of payload,version,title on public.mindstorm_bunches
  for each row when (new.version > old.version)
  execute function private.mindstorm_bump_bunch_signal();

do $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='mindstorm_bunch_signals') then
    alter publication supabase_realtime add table public.mindstorm_bunch_signals;
  end if;
end $$;

commit;

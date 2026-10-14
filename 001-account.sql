-- Run once in the existing Supabase project's SQL Editor.
-- Account profiles are private in phase 1. Bunch-member access is a later migration.
begin;
create table if not exists public.mindstorm_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '新朋友' check (char_length(display_name) between 1 and 40),
  avatar_path text,
  updated_at timestamptz not null default now()
);
alter table public.mindstorm_profiles enable row level security;
revoke all on public.mindstorm_profiles from anon, authenticated;
grant select on public.mindstorm_profiles to authenticated;
drop policy if exists mindstorm_read_own_profile on public.mindstorm_profiles;
create policy mindstorm_read_own_profile on public.mindstorm_profiles
  for select to authenticated using (id = (select auth.uid()));

create or replace function public.mindstorm_sync_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.mindstorm_profiles(id, display_name, avatar_path, updated_at)
  values (new.id, left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''), '新朋友'), 40),
    case when (new.raw_user_meta_data->>'avatar_path') like new.id::text || '/%'
      then new.raw_user_meta_data->>'avatar_path' else null end, now())
  on conflict (id) do update set display_name=excluded.display_name, avatar_path=excluded.avatar_path, updated_at=excluded.updated_at;
  return new;
end;
$$;
revoke all on function public.mindstorm_sync_profile() from public, anon, authenticated;
drop trigger if exists mindstorm_account_profile on auth.users;
create trigger mindstorm_account_profile after insert or update of raw_user_meta_data
  on auth.users for each row execute function public.mindstorm_sync_profile();
insert into public.mindstorm_profiles(id,display_name,avatar_path)
select id,left(coalesce(nullif(trim(raw_user_meta_data->>'display_name'),''),'新朋友'),40),
case when (raw_user_meta_data->>'avatar_path') like id::text || '/%' then raw_user_meta_data->>'avatar_path' else null end
from auth.users on conflict (id) do nothing;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('mindstorm-avatars','mindstorm-avatars',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
drop policy if exists mindstorm_avatar_read on storage.objects;
create policy mindstorm_avatar_read on storage.objects for select to authenticated
using (bucket_id='mindstorm-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists mindstorm_avatar_insert on storage.objects;
create policy mindstorm_avatar_insert on storage.objects for insert to authenticated
with check (bucket_id='mindstorm-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists mindstorm_avatar_update on storage.objects;
create policy mindstorm_avatar_update on storage.objects for update to authenticated
using (bucket_id='mindstorm-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='mindstorm-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists mindstorm_avatar_delete on storage.objects;
create policy mindstorm_avatar_delete on storage.objects for delete to authenticated
using (bucket_id='mindstorm-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
commit;

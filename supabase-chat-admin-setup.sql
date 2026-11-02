create or replace function public.get_party_user_count()
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
    signed_in_user_count bigint;
begin
    if auth.uid() is null or not exists (
        select 1
        from public.party_admins as admins
        where admins.user_id = auth.uid()
    ) then
        raise exception 'Not authorized to view the Auth user count'
            using errcode = '42501';
    end if;

    select count(*)
    into signed_in_user_count
    from auth.users as users
    where users.last_sign_in_at is not null;

    return signed_in_user_count;
end;
$function$;

revoke all on function public.get_party_user_count() from public, anon;
grant execute on function public.get_party_user_count() to authenticated;

do $function$
begin
    if exists (
        select 1
        from pg_publication
        where pubname = 'supabase_realtime'
    ) and not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'messages'
    ) then
        alter publication supabase_realtime add table public.messages;
    end if;
end;
$function$;

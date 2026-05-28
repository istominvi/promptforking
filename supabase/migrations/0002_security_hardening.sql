-- 0002_security_hardening.sql
-- Closes Supabase advisor warnings raised by 0001_init:
--   - function_search_path_mutable (generations_set_root_id)
--   - anon/authenticated_security_definer_function_executable (handle_new_user)
--
-- Both functions are trigger-only. Triggers fire regardless of EXECUTE grants,
-- so revoking PostgREST/RPC access does not affect inserts. service_role and the
-- table owner retain access through ownership/superuser, so the triggers keep working.

-- Pin search_path (handle_new_user already pins it in its body).
alter function public.generations_set_root_id() set search_path = public;

-- Trigger functions must not be callable via /rest/v1/rpc/*.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.generations_set_root_id() from public, anon, authenticated;

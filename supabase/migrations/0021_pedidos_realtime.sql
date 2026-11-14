-- La app filtra los INSERT de pedidos por negocio_id.
-- Replica identity full deja esa columna en el registro que ve Realtime.

alter table public.pedidos replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pedidos'
  ) then
    alter publication supabase_realtime add table public.pedidos;
  end if;
end $$;

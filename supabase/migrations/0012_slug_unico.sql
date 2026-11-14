-- Dice si otro negocio ya usa esa dirección, sin mostrar de quién es.

create or replace function public.slug_de_otro(p_slug text, p_negocio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.negocios
    where lower(slug) = lower(trim(coalesce(p_slug, '')))
      and coalesce(slug, '') <> ''
      and id is distinct from p_negocio_id
  );
$$;

revoke all on function public.slug_de_otro(text, uuid) from public, anon;
grant execute on function public.slug_de_otro(text, uuid) to authenticated;

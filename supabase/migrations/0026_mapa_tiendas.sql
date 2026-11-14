-- Punto del local, elegido en el buscador de la página.
-- El mapa del panel solo lo lee el desarrollador.

alter table public.negocios
  add column if not exists latitud double precision,
  add column if not exists longitud double precision;

create or replace function public.mapa_desarrollador()
returns table (
  nombre text,
  slug text,
  logo_url text,
  latitud double precision,
  longitud double precision,
  tienda_activa boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
begin
  if correo = '' or correo not in (
    'jesus.cajal.work@gmail.com',
    'jesuscajal49@gmail.com',
    'piloto@novaceltec.local',
    'leocajald@gmail.com'
  ) then
    return;
  end if;
  return query
  select n.nombre, n.slug, n.logo_url, n.latitud, n.longitud, n.tienda_activa
  from public.negocios as n
  order by n.nombre
  limit 200;
end;
$$;

revoke all on function public.mapa_desarrollador() from public, anon;
grant execute on function public.mapa_desarrollador() to authenticated;

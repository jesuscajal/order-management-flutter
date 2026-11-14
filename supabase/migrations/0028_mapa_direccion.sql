-- El mapa también recibe la dirección escrita, para ubicar
-- locales que todavía no tienen latitud y longitud.

drop function if exists public.mapa_desarrollador();

create function public.mapa_desarrollador()
returns table (
  nombre text,
  slug text,
  logo_url text,
  maps_url text,
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
  select
    n.nombre,
    n.slug,
    n.logo_url,
    n.maps_url,
    n.latitud,
    n.longitud,
    n.tienda_activa
  from public.negocios as n
  order by n.nombre
  limit 200;
end;
$$;

revoke all on function public.mapa_desarrollador() from public, anon;
grant execute on function public.mapa_desarrollador() to authenticated;

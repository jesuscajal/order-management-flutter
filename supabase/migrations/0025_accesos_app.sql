-- Ciudad desde la que se abrió la app. Una fila por correo.
-- No guarda coordenadas ni la dirección IP.

create table if not exists public.accesos_app (
  email text primary key,
  ciudad text not null default '',
  region text not null default '',
  pais text not null default '',
  visto_en timestamptz not null default now()
);

alter table public.accesos_app enable row level security;

revoke all on table public.accesos_app from public, anon, authenticated;

create or replace function public.registrar_acceso(
  p_ciudad text,
  p_region text,
  p_pais text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  ciudad text := left(regexp_replace(coalesce(p_ciudad, ''), '[[:cntrl:]]', '', 'g'), 80);
  region text := left(regexp_replace(coalesce(p_region, ''), '[[:cntrl:]]', '', 'g'), 80);
  pais text := left(regexp_replace(coalesce(p_pais, ''), '[[:cntrl:]]', '', 'g'), 80);
begin
  if correo = '' or correo like '%@equipo.gexi' then
    return;
  end if;
  ciudad := trim(ciudad);
  region := trim(region);
  pais := trim(pais);
  if ciudad = '' and pais = '' then
    return;
  end if;
  insert into public.accesos_app (email, ciudad, region, pais, visto_en)
  values (correo, ciudad, region, pais, now())
  on conflict (email) do update
    set ciudad = excluded.ciudad,
        region = excluded.region,
        pais = excluded.pais,
        visto_en = excluded.visto_en;
end;
$$;

revoke all on function public.registrar_acceso(text, text, text) from public, anon;
grant execute on function public.registrar_acceso(text, text, text) to authenticated;

create or replace function public.accesos_desarrollador()
returns table (
  email text,
  ciudad text,
  region text,
  pais text,
  visto_en timestamptz
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
  select a.email, a.ciudad, a.region, a.pais, a.visto_en
  from public.accesos_app as a
  order by a.visto_en desc
  limit 40;
end;
$$;

revoke all on function public.accesos_desarrollador() from public, anon;
grant execute on function public.accesos_desarrollador() to authenticated;

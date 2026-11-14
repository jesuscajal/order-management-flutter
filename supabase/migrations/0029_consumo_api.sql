-- Cada envío de la app a OpenAI: origen, modelo y tokens.
-- No guarda la frase ni la respuesta.

alter table public.asistente_uso
  add column if not exists origen text not null default 'asistente',
  add column if not exists modelo text not null default '';

alter table public.asistente_uso
  drop constraint if exists asistente_uso_origen_check;

alter table public.asistente_uso
  add constraint asistente_uso_origen_check
  check (origen in ('asistente', 'foto', 'pagina'));

create or replace function public.consumo_desarrollador(p_limite integer default 40)
returns table (
  negocio text,
  origen text,
  modelo text,
  tokens_entrada integer,
  tokens_salida integer,
  tokens_cache integer,
  creado_en timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  limite integer := least(greatest(coalesce(p_limite, 40), 1), 80);
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
    coalesce(nullif(btrim(n.nombre), ''), 'Sin nombre'),
    u.origen,
    u.modelo,
    u.tokens_entrada,
    u.tokens_salida,
    u.tokens_cache,
    u.creado_en
  from public.asistente_uso as u
  left join public.negocios as n on n.id = u.negocio_id
  order by u.creado_en desc
  limit limite;
end;
$$;

revoke all on function public.consumo_desarrollador(integer) from public, anon;
grant execute on function public.consumo_desarrollador(integer) to authenticated;

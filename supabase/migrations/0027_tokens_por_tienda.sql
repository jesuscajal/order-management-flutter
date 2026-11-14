-- Consumo del asistente, una fila por microemprendimiento.
-- Solo lo lee el desarrollador. No expone correos ni el texto de los chats.

create or replace function public.tokens_desarrollador()
returns table (
  nombre text,
  slug text,
  logo_url text,
  consultas bigint,
  tokens_entrada bigint,
  tokens_salida bigint,
  tokens_cache bigint,
  chats_disponibles integer
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
    coalesce(nullif(btrim(n.nombre), ''), 'Sin nombre'),
    coalesce(n.slug, ''),
    n.logo_url,
    count(u.id),
    coalesce(sum(u.tokens_entrada), 0)::bigint,
    coalesce(sum(u.tokens_salida), 0)::bigint,
    coalesce(sum(u.tokens_cache), 0)::bigint,
    coalesce(c.chats_disponibles, 30)
  from public.negocios as n
  left join public.asistente_uso as u on u.negocio_id = n.id
  left join public.asistente_cupo as c on c.negocio_id = n.id
  group by n.id, n.nombre, n.slug, n.logo_url, c.chats_disponibles
  order by
    (coalesce(sum(u.tokens_entrada), 0) + coalesce(sum(u.tokens_salida), 0)) desc,
    n.nombre
  limit 200;
end;
$$;

revoke all on function public.tokens_desarrollador() from public, anon;
grant execute on function public.tokens_desarrollador() to authenticated;

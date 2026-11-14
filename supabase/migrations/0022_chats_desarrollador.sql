-- Últimas conversaciones del asistente, solo lectura, para el desarrollador.
-- anon no tiene permiso. Si el email del JWT no está en la lista de
-- resumen_desarrollador (0018), la función no devuelve filas.

create index if not exists asistente_mensajes_negocio_usuario_fecha_idx
  on public.asistente_mensajes (negocio_id, usuario_email, creado_en desc);

create index if not exists asistente_mensajes_usuario_fecha_idx
  on public.asistente_mensajes (creado_en desc)
  where rol = 'user';

create or replace function public.chats_desarrollador(p_limite integer default 40)
returns table (
  negocio text,
  usuario_email text,
  creado_en timestamptz,
  frase text,
  respuesta text
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
    coalesce(nullif(btrim(n.nombre), ''), m.negocio_id::text),
    m.usuario_email,
    m.creado_en,
    btrim(regexp_replace(
      regexp_replace(
        coalesce(m.contenido, ''),
        'sk-[A-Za-z0-9][A-Za-z0-9_-]{7,}',
        '',
        'g'
      ),
      'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+',
      '',
      'g'
    )),
    coalesce(btrim(regexp_replace(
      regexp_replace(
        coalesce((
          select a.contenido
          from public.asistente_mensajes a
          where a.negocio_id = m.negocio_id
            and lower(a.usuario_email) = lower(m.usuario_email)
            and a.rol = 'assistant'
            and a.creado_en >= m.creado_en
            and not exists (
              select 1
              from public.asistente_mensajes medio
              where medio.negocio_id = m.negocio_id
                and lower(medio.usuario_email) = lower(m.usuario_email)
                and medio.rol = 'user'
                and medio.creado_en > m.creado_en
                and medio.creado_en <= a.creado_en
            )
          order by a.creado_en asc
          limit 1
        ), ''),
        'sk-[A-Za-z0-9][A-Za-z0-9_-]{7,}',
        '',
        'g'
      ),
      'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+',
      '',
      'g'
    )), '')
  from public.asistente_mensajes m
  left join public.negocios n on n.id = m.negocio_id
  where m.rol = 'user'
  order by m.creado_en desc
  limit limite;
end;
$$;

revoke all on function public.chats_desarrollador(integer) from public, anon;
grant execute on function public.chats_desarrollador(integer) to authenticated;

comment on function public.chats_desarrollador(integer) is
  'Frases y respuestas del asistente. Vacío si el email del JWT no es el del desarrollador.';

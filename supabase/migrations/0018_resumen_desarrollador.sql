-- Resumen de solo lectura para el desarrollador.
-- No crea asistente_uso ni asistente_cupo (eso es 0016).
-- Si esas tablas, o la columna chats_disponibles, todavía no existen,
-- devuelve 0 y asistente_sin_datos = true.
-- No aplica este archivo en remoto mientras 0016 pueda no estar: la función
-- se crea igual, pero el conteo del asistente queda en cero hasta entonces.

create or replace function public.resumen_desarrollador()
returns table (
  tiendas_activas bigint,
  usuarios bigint,
  tokens bigint,
  chats_disponibles bigint,
  asistente_sin_datos boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  tiene_uso boolean;
  tiene_chats boolean;
begin
  -- Misma lista que lib/services/desarrollador.dart.
  if correo = '' or correo not in (
    'jesus.cajal.work@gmail.com',
    'jesuscajal49@gmail.com',
    'piloto@novaceltec.local',
    'leocajald@gmail.com'
  ) then
    return;
  end if;

  tiendas_activas := 0;
  usuarios := 0;
  tokens := 0;
  chats_disponibles := 0;
  asistente_sin_datos := false;

  select count(*)
    into tiendas_activas
  from public.negocios
  where tienda_activa is true;

  -- Dueños distintos y miembros reales. Los códigos sin cuenta (@equipo.gexi)
  -- no son usuarios. No se lee auth.users.
  select count(distinct persona)
    into usuarios
  from (
    select lower(trim(dueno_email)) as persona
    from public.negocios
    union
    select lower(trim(email))
    from public.miembros
  ) as personas
  where persona <> ''
    and persona not like '%@equipo.gexi';

  tiene_uso := to_regclass('public.asistente_uso') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'asistente_uso'
        and column_name = 'tokens_entrada'
    )
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'asistente_uso'
        and column_name = 'tokens_salida'
    );

  tiene_chats := to_regclass('public.asistente_cupo') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'asistente_cupo'
        and column_name = 'chats_disponibles'
    );

  if not tiene_uso or not tiene_chats then
    asistente_sin_datos := true;
  end if;

  if tiene_uso then
    execute
      'select coalesce(sum(tokens_entrada), 0) + coalesce(sum(tokens_salida), 0) from public.asistente_uso'
      into tokens;
  end if;

  if tiene_chats then
    execute
      'select coalesce(sum(chats_disponibles), 0) from public.asistente_cupo'
      into chats_disponibles;
  end if;

  return next;
end;
$$;

revoke all on function public.resumen_desarrollador() from public, anon;
grant execute on function public.resumen_desarrollador() to authenticated;

comment on function public.resumen_desarrollador() is
  'Conteos globales de solo lectura. Vacío si el email del JWT no es el del desarrollador.';

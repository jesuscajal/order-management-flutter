-- Configuración de IA del panel del desarrollador.
-- Las claves no las puede leer anon ni un comerciante autenticado.
-- El panel usa las RPC ia_panel_*. La app solo puede leer el modelo local
-- cuando esa es la fuente activa. La clave de OpenAI la leen las funciones
-- de borde con service_role.

create table public.ia_claves (
  id uuid primary key default gen_random_uuid(),
  etiqueta text not null,
  valor text not null,
  creado_en timestamptz not null default now(),
  constraint ia_claves_etiqueta_largo check (length(etiqueta) between 1 and 40),
  constraint ia_claves_valor_largo check (length(valor) between 8 and 400)
);

create table public.ia_config (
  id smallint primary key default 1,
  fuente text not null default 'ninguna',
  clave_activa_id uuid references public.ia_claves (id) on delete set null,
  local_base_url text not null default '',
  local_modelo text not null default '',
  local_clave text not null default '',
  constraint ia_config_una_fila check (id = 1),
  constraint ia_config_fuente_check check (fuente in ('ninguna', 'clave', 'local')),
  constraint ia_config_local_url_largo check (length(local_base_url) <= 300),
  constraint ia_config_local_modelo_largo check (length(local_modelo) <= 120),
  constraint ia_config_local_clave_largo check (
    length(local_clave) = 0 or length(local_clave) between 8 and 400
  )
);

insert into public.ia_config (id) values (1);

alter table public.ia_claves enable row level security;
alter table public.ia_config enable row level security;

revoke all on table public.ia_claves from public, anon, authenticated, service_role;
revoke all on table public.ia_config from public, anon, authenticated, service_role;

comment on table public.ia_claves is
  'Claves de API del panel. Sin políticas: anon y authenticated no pueden leerlas.';

comment on table public.ia_config is
  'Fuente activa de la IA. Sin políticas: no se lee con select desde la app.';

create or replace function public.ia_es_desarrollador()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select lower(trim(coalesce(auth.jwt() ->> 'email', ''))) in (
    'jesus.cajal.work@gmail.com',
    'jesuscajal49@gmail.com',
    'piloto@novaceltec.local',
    'leocajald@gmail.com'
  );
$$;

create or replace function public.ia_sufijo(p_valor text)
returns text
language sql
immutable
as $$
  select case
    when length(trim(coalesce(p_valor, ''))) <= 4 then ''
    else right(trim(p_valor), 4)
  end;
$$;

create or replace function public.ia_etiqueta(p_pedido text, p_cantidad integer)
returns text
language plpgsql
immutable
as $$
declare
  limpia text := regexp_replace(trim(coalesce(p_pedido, '')), '\s+', ' ', 'g');
begin
  if limpia = '' then
    return 'Clave ' || (coalesce(p_cantidad, 0) + 1)::text;
  end if;
  if length(limpia) > 40 then
    return left(limpia, 40);
  end if;
  return limpia;
end;
$$;

create or replace function public.ia_normalizar_base(p_cruda text)
returns text
language plpgsql
immutable
as $$
declare
  base text := trim(coalesce(p_cruda, ''));
  host text;
begin
  while right(base, 1) = '/' loop
    base := left(base, length(base) - 1);
  end loop;
  if right(lower(base), length('/chat/completions')) = '/chat/completions' then
    base := left(base, length(base) - length('/chat/completions'));
  elsif right(lower(base), length('/images/generations')) = '/images/generations' then
    base := left(base, length(base) - length('/images/generations'));
  end if;
  while right(base, 1) = '/' loop
    base := left(base, length(base) - 1);
  end loop;
  if base = '' or length(base) > 300 then
    return null;
  end if;
  if base !~* '^https?://' then
    return null;
  end if;
  host := split_part(base, '/', 3);
  if host is null or host = '' or position('@' in host) > 0 then
    return null;
  end if;
  if split_part(host, ':', 1) = '' then
    return null;
  end if;
  return base;
end;
$$;

create or replace function public.ia_vista()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  fuente_actual text := 'ninguna';
  clave_id uuid;
  base text := '';
  nombre text := '';
  clave_local text := '';
  claves jsonb := '[]'::jsonb;
  local jsonb;
begin
  select fuente, clave_activa_id, local_base_url, local_modelo, local_clave
    into fuente_actual, clave_id, base, nombre, clave_local
  from public.ia_config
  where id = 1;

  if fuente_actual is null then
    fuente_actual := 'ninguna';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'etiqueta', c.etiqueta,
      'sufijo', public.ia_sufijo(c.valor),
      'activa', fuente_actual = 'clave' and clave_id = c.id
    )
    order by c.creado_en
  ), '[]'::jsonb)
    into claves
  from public.ia_claves as c;

  if length(trim(coalesce(base, ''))) = 0 or length(trim(coalesce(nombre, ''))) = 0 then
    local := null;
  else
    local := jsonb_build_object(
      'base_url', base,
      'modelo', nombre,
      'sufijo', public.ia_sufijo(clave_local),
      'tiene_clave', length(trim(coalesce(clave_local, ''))) > 0,
      'activo', fuente_actual = 'local'
    );
  end if;

  return jsonb_build_object(
    'fuente', fuente_actual,
    'claves', claves,
    'local', local
  );
end;
$$;

create or replace function public.ia_panel_ver()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.ia_es_desarrollador() then
    return null;
  end if;
  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_agregar_clave(
  p_etiqueta text,
  p_valor text,
  p_activar boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  limpio text := trim(coalesce(p_valor, ''));
  existente uuid;
  cantidad integer;
  nueva uuid;
  activar boolean := coalesce(p_activar, false);
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;

  if limpio = '' then
    raise exception 'La clave está vacía.' using errcode = '22023';
  end if;
  if length(limpio) < 8 then
    raise exception 'La clave es demasiado corta.' using errcode = '22023';
  end if;
  if length(limpio) > 400 then
    raise exception 'Esa clave es demasiado larga.' using errcode = '22023';
  end if;

  insert into public.ia_config (id) values (1) on conflict (id) do nothing;

  select id into existente
  from public.ia_claves
  where valor = limpio
  limit 1;

  if existente is not null then
    if activar then
      update public.ia_config
      set fuente = 'clave', clave_activa_id = existente
      where id = 1;
    end if;
    return public.ia_vista() || jsonb_build_object('repetida', true);
  end if;

  select count(*) into cantidad from public.ia_claves;
  if cantidad >= 8 then
    raise exception 'Podés guardar hasta 8 claves. Eliminá una para agregar otra.'
      using errcode = '22023';
  end if;

  insert into public.ia_claves (etiqueta, valor)
  values (public.ia_etiqueta(p_etiqueta, cantidad), limpio)
  returning id into nueva;

  if activar then
    update public.ia_config
    set fuente = 'clave', clave_activa_id = nueva
    where id = 1;
  end if;

  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_activar_clave(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;
  if p_id is null or not exists (select 1 from public.ia_claves where id = p_id) then
    raise exception 'Esa clave ya no está guardada.' using errcode = '22023';
  end if;

  insert into public.ia_config (id) values (1) on conflict (id) do nothing;
  update public.ia_config
  set fuente = 'clave', clave_activa_id = p_id
  where id = 1;

  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_borrar_clave(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  era_activa boolean;
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;

  select fuente = 'clave' and clave_activa_id = p_id
    into era_activa
  from public.ia_config
  where id = 1;

  delete from public.ia_claves where id = p_id;

  if coalesce(era_activa, false) then
    update public.ia_config
    set fuente = 'ninguna', clave_activa_id = null
    where id = 1;
  end if;

  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_guardar_local(
  p_base_url text,
  p_modelo text,
  p_clave text,
  p_cambiar_clave boolean,
  p_activar boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  base text;
  nombre text;
  clave text;
  habia boolean;
  activar boolean := coalesce(p_activar, false);
  fuente_actual text;
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;

  if position('@' in coalesce(split_part(trim(coalesce(p_base_url, '')), '/', 3), '')) > 0 then
    raise exception 'No pongas la clave en la dirección. Usá el campo de clave.'
      using errcode = '22023';
  end if;

  base := public.ia_normalizar_base(p_base_url);
  if base is null then
    raise exception 'La dirección tiene que empezar con http:// o https:// e incluir el servidor. Ejemplo: http://127.0.0.1:11434/v1'
      using errcode = '22023';
  end if;

  nombre := regexp_replace(trim(coalesce(p_modelo, '')), '\s+', ' ', 'g');
  if nombre = '' or length(nombre) > 120 then
    raise exception 'Falta el nombre del modelo, o es demasiado largo.'
      using errcode = '22023';
  end if;

  insert into public.ia_config (id) values (1) on conflict (id) do nothing;

  select
    length(trim(local_base_url)) > 0 and length(trim(local_modelo)) > 0,
    local_clave,
    fuente
    into habia, clave, fuente_actual
  from public.ia_config
  where id = 1;

  if coalesce(p_cambiar_clave, false) or not coalesce(habia, false) then
    clave := trim(coalesce(p_clave, ''));
    if clave <> '' and length(clave) < 8 then
      raise exception 'La clave del modelo es demasiado corta.' using errcode = '22023';
    end if;
    if length(clave) > 400 then
      raise exception 'Esa clave es demasiado larga.' using errcode = '22023';
    end if;
  end if;

  if activar then
    fuente_actual := 'local';
  elsif fuente_actual = 'local' then
    fuente_actual := 'ninguna';
  end if;

  update public.ia_config
  set
    local_base_url = base,
    local_modelo = nombre,
    local_clave = coalesce(clave, ''),
    fuente = fuente_actual
  where id = 1;

  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_quitar_local()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;

  update public.ia_config
  set
    local_base_url = '',
    local_modelo = '',
    local_clave = '',
    fuente = case when fuente = 'local' then 'ninguna' else fuente end
  where id = 1;

  return public.ia_vista();
end;
$$;

create or replace function public.ia_panel_usar_secreto()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.ia_es_desarrollador() then
    raise exception 'Sin acceso.' using errcode = '42501';
  end if;

  update public.ia_config
  set fuente = 'ninguna'
  where id = 1;

  return public.ia_vista();
end;
$$;

-- Solo el modelo local, y solo si es la fuente activa.
-- Nunca devuelve claves de OpenAI.
create or replace function public.modelo_local_activo()
returns table (
  base_url text,
  modelo text,
  clave text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  fuente_actual text;
  base text;
  nombre text;
  clave_local text;
begin
  if correo = '' then
    return;
  end if;

  if not exists (
    select 1
    from public.negocios as n
    where lower(trim(n.dueno_email)) = correo
  ) and not exists (
    select 1
    from public.miembros as m
    where lower(trim(m.email)) = correo
  ) then
    return;
  end if;

  select fuente, local_base_url, local_modelo, local_clave
    into fuente_actual, base, nombre, clave_local
  from public.ia_config
  where id = 1;

  if fuente_actual is distinct from 'local' then
    return;
  end if;
  if length(trim(coalesce(base, ''))) = 0 or length(trim(coalesce(nombre, ''))) = 0 then
    return;
  end if;

  base_url := base;
  modelo := nombre;
  clave := trim(coalesce(clave_local, ''));
  return next;
end;
$$;

-- La leen las funciones de borde. No está concedida a anon ni authenticated.
create or replace function public.ia_clave_openai_activa()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  resultado text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    return null;
  end if;

  select c.valor
    into resultado
  from public.ia_config as cfg
  join public.ia_claves as c on c.id = cfg.clave_activa_id
  where cfg.id = 1
    and cfg.fuente = 'clave'
    and length(trim(c.valor)) > 0;

  return resultado;
end;
$$;

revoke all on function public.ia_es_desarrollador() from public, anon, authenticated;
revoke all on function public.ia_sufijo(text) from public, anon, authenticated;
revoke all on function public.ia_etiqueta(text, integer) from public, anon, authenticated;
revoke all on function public.ia_normalizar_base(text) from public, anon, authenticated;
revoke all on function public.ia_vista() from public, anon, authenticated;

revoke all on function public.ia_panel_ver() from public, anon;
grant execute on function public.ia_panel_ver() to authenticated;

revoke all on function public.ia_panel_agregar_clave(text, text, boolean) from public, anon;
grant execute on function public.ia_panel_agregar_clave(text, text, boolean) to authenticated;

revoke all on function public.ia_panel_activar_clave(uuid) from public, anon;
grant execute on function public.ia_panel_activar_clave(uuid) to authenticated;

revoke all on function public.ia_panel_borrar_clave(uuid) from public, anon;
grant execute on function public.ia_panel_borrar_clave(uuid) to authenticated;

revoke all on function public.ia_panel_guardar_local(text, text, text, boolean, boolean) from public, anon;
grant execute on function public.ia_panel_guardar_local(text, text, text, boolean, boolean) to authenticated;

revoke all on function public.ia_panel_quitar_local() from public, anon;
grant execute on function public.ia_panel_quitar_local() to authenticated;

revoke all on function public.ia_panel_usar_secreto() from public, anon;
grant execute on function public.ia_panel_usar_secreto() to authenticated;

revoke all on function public.modelo_local_activo() from public, anon;
grant execute on function public.modelo_local_activo() to authenticated;

revoke all on function public.ia_clave_openai_activa() from public, anon, authenticated;
grant execute on function public.ia_clave_openai_activa() to service_role;

comment on function public.modelo_local_activo() is
  'URL, modelo y clave opcional del modelo local, solo si es la fuente activa y la sesión es de un negocio. No devuelve claves de OpenAI.';

comment on function public.ia_clave_openai_activa() is
  'Clave de OpenAI activa del panel. Solo service_role. Vacío si la fuente no es una clave.';

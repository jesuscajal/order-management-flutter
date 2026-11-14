-- El diseño de la vidriera viaja dentro de negocios.apariencia (jsonb),
-- en la clave layout. La columna ya existe desde 0010 y la vista
-- tienda_publica ya devuelve n.apariencia completo desde 0020, así que
-- no se recrea la vista ni se agrega una columna.
--
-- Cada guardado que cambia layout deja una fila. El dueño puede volver
-- a la versión anterior del mismo negocio.

create table if not exists public.negocio_diseno_versiones (
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  version integer not null check (version > 0),
  diseno jsonb not null check (jsonb_typeof(diseno) = 'object'),
  origen text not null default 'guardado' check (length(trim(origen)) > 0),
  activa boolean not null default false,
  creado_en timestamptz not null default now(),
  primary key (negocio_id, version)
);

create unique index if not exists negocio_diseno_versiones_activa_uidx
  on public.negocio_diseno_versiones (negocio_id)
  where activa;

alter table public.negocio_diseno_versiones enable row level security;

drop policy if exists negocio_diseno_versiones_lectura
  on public.negocio_diseno_versiones;
create policy negocio_diseno_versiones_lectura
  on public.negocio_diseno_versiones
  for select
  to authenticated
  using (public.es_dueno(negocio_id));

create or replace function public.registrar_diseno_tienda()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  layout_nuevo jsonb;
  siguiente integer;
begin
  if coalesce(current_setting('gexi.omitir_version_diseno', true), '') = '1' then
    return new;
  end if;

  layout_nuevo := new.apariencia -> 'layout';
  if layout_nuevo is null or jsonb_typeof(layout_nuevo) <> 'object' then
    return new;
  end if;
  if layout_nuevo = '{}'::jsonb then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and layout_nuevo is not distinct from (old.apariencia -> 'layout') then
    return new;
  end if;

  update public.negocio_diseno_versiones
     set activa = false
   where negocio_id = new.id
     and activa;

  select coalesce(max(v.version), 0) + 1
    into siguiente
  from public.negocio_diseno_versiones as v
  where v.negocio_id = new.id;

  insert into public.negocio_diseno_versiones (
    negocio_id, version, diseno, origen, activa
  ) values (
    new.id,
    siguiente,
    layout_nuevo,
    case when tg_op = 'INSERT' then 'alta' else 'guardado' end,
    true
  );

  return new;
end;
$$;

drop trigger if exists negocios_registrar_diseno on public.negocios;
create trigger negocios_registrar_diseno
  after insert or update of apariencia on public.negocios
  for each row
  execute function public.registrar_diseno_tienda();

create or replace function public.activar_diseno_anterior(p_negocio_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actual_version integer;
  previa_version integer;
  previa_diseno jsonb;
  base jsonb;
begin
  if p_negocio_id is null or not public.es_dueno(p_negocio_id) then
    raise exception 'Solo quien es dueño del negocio puede volver al diseño anterior.';
  end if;

  select v.version
    into actual_version
  from public.negocio_diseno_versiones as v
  where v.negocio_id = p_negocio_id
    and v.activa
  order by v.version desc
  limit 1;

  if actual_version is null then
    select v.version
      into actual_version
    from public.negocio_diseno_versiones as v
    where v.negocio_id = p_negocio_id
    order by v.version desc
    limit 1;
  end if;

  if actual_version is null then
    raise exception 'No hay un diseño anterior para este negocio.';
  end if;

  select v.version, v.diseno
    into previa_version, previa_diseno
  from public.negocio_diseno_versiones as v
  where v.negocio_id = p_negocio_id
    and v.version < actual_version
  order by v.version desc
  limit 1;

  if previa_version is null or previa_diseno is null then
    raise exception 'No hay un diseño anterior para este negocio.';
  end if;

  perform set_config('gexi.omitir_version_diseno', '1', true);

  select case
           when jsonb_typeof(coalesce(n.apariencia, '{}'::jsonb)) = 'object'
             then coalesce(n.apariencia, '{}'::jsonb)
           else '{}'::jsonb
         end
    into base
  from public.negocios as n
  where n.id = p_negocio_id
  for update;

  if base is null then
    raise exception 'No encontramos el negocio.';
  end if;

  update public.negocios
     set apariencia = jsonb_set(base, '{layout}', previa_diseno, true)
   where id = p_negocio_id;

  update public.negocio_diseno_versiones
     set activa = false
   where negocio_id = p_negocio_id
     and activa;

  update public.negocio_diseno_versiones
     set activa = true
   where negocio_id = p_negocio_id
     and version = previa_version;

  return previa_diseno;
end;
$$;

revoke all on function public.registrar_diseno_tienda() from public, anon, authenticated;
grant execute on function public.registrar_diseno_tienda() to authenticated;

revoke all on function public.activar_diseno_anterior(uuid) from public, anon;
grant execute on function public.activar_diseno_anterior(uuid) to authenticated;

comment on table public.negocio_diseno_versiones is
  'Versiones del diseño. El vigente también está en negocios.apariencia.layout.';

comment on function public.activar_diseno_anterior(uuid) is
  'Activa la versión anterior del mismo negocio. Solo el dueño.';

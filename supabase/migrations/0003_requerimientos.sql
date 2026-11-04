-- Gexi: esquema amplio para los requerimientos que el prototipo todavía
-- no persiste. Aplicar después de 0001_gexi.sql y 0002_tienda_publica.sql.
-- Solo agrega columnas, tablas, índices, políticas y la auditoría.
-- No borra datos ni cambia el contrato que ya usa la app.

begin;

set local search_path to public, extensions;

-- ---------------------------------------------------------------------------
-- Negocio, personas y perfil
-- 1.1 cuenta, 1.2 negocio, 1.3 equipo y código de empleado, 5.x tienda
-- ---------------------------------------------------------------------------

create table if not exists public.perfiles (
  email text primary key,
  nombre text not null default '',
  foto_url text,
  creado_en timestamptz not null default now(),
  constraint perfiles_email_check check (length(trim(email)) > 0)
);

alter table public.negocios
  add column if not exists moneda text not null default 'USD',
  add column if not exists zona_horaria text not null default 'America/Asuncion',
  add column if not exists direccion text not null default '',
  add column if not exists horario text not null default '',
  add column if not exists documento_fiscal text,
  add column if not exists condicion_fiscal text;

alter table public.miembros
  add column if not exists nombre text not null default '',
  add column if not exists codigo_empleado text,
  add column if not exists activo boolean not null default true,
  add column if not exists creado_en timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.miembros'::regclass
      and conname = 'miembros_rol_check'
  ) then
    alter table public.miembros
      add constraint miembros_rol_check
      check (rol in ('administrador', 'vendedor', 'empleado'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.miembros'::regclass
      and conname = 'miembros_codigo_formato_check'
  ) then
    alter table public.miembros
      add constraint miembros_codigo_formato_check
      check (
        codigo_empleado is null
        or codigo_empleado = ''
        or codigo_empleado ~ '^[A-Z0-9]{4,12}$'
      );
  end if;
end $$;

create unique index if not exists miembros_codigo_lower_uidx
  on public.miembros (negocio_id, upper(codigo_empleado))
  where codigo_empleado is not null and codigo_empleado <> '';

create or replace function public.limitar_equipo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cantidad integer;
begin
  select count(*)
    into cantidad
  from public.miembros
  where negocio_id = new.negocio_id;

  if cantidad > 6 then
    raise exception
      'El negocio admite al dueño y hasta cinco personas más.';
  end if;
  return new;
end;
$$;

drop trigger if exists miembros_limitar_equipo on public.miembros;
create trigger miembros_limitar_equipo
  after insert on public.miembros
  for each row
  execute function public.limitar_equipo();

-- ---------------------------------------------------------------------------
-- Catálogo: categorías, atributos, variantes, series
-- 2.1 productos, 2.2 categorías, 2.3 atributos y visibilidad, 2.4 serie, 2.6 variantes
-- ---------------------------------------------------------------------------

alter table public.clientes
  add column if not exists notas text,
  add column if not exists es_potencial boolean not null default false,
  add column if not exists estado_pago text not null default 'pendiente',
  add column if not exists creado_en timestamptz not null default now();

create table if not exists public.categorias (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  nombre text not null,
  orden integer not null default 0,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create unique index if not exists categorias_nombre_lower_uidx
  on public.categorias (negocio_id, lower(nombre));

create table if not exists public.atributos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  nombre text not null,
  tipo text not null default 'texto',
  opciones text[] not null default '{}',
  visible_en_tienda boolean not null default true,
  orden integer not null default 0,
  constraint atributos_tipo_check check (tipo in ('texto', 'numero', 'lista'))
);

create unique index if not exists atributos_nombre_lower_uidx
  on public.atributos (negocio_id, lower(nombre));

alter table public.productos
  add column if not exists categoria_id uuid references public.categorias (id) on delete set null,
  add column if not exists descripcion text not null default '',
  add column if not exists sku text,
  add column if not exists imagen_url text,
  add column if not exists visible_en_tienda boolean not null default true,
  add column if not exists controla_serie boolean not null default false,
  add column if not exists umbral_stock_bajo integer not null default 2,
  add column if not exists activo boolean not null default true,
  add column if not exists creado_en timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.productos'::regclass
      and conname = 'productos_umbral_check'
  ) then
    alter table public.productos
      add constraint productos_umbral_check check (umbral_stock_bajo >= 0);
  end if;
end $$;

create unique index if not exists productos_sku_lower_uidx
  on public.productos (negocio_id, lower(sku))
  where sku is not null and sku <> '';

create table if not exists public.variantes_producto (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  producto_id uuid not null references public.productos (id) on delete cascade,
  nombre text not null,
  sku text,
  precio_compra numeric,
  precio_venta numeric,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create unique index if not exists variantes_nombre_lower_uidx
  on public.variantes_producto (producto_id, lower(nombre));

create table if not exists public.atributos_producto (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  atributo_id uuid not null references public.atributos (id) on delete cascade,
  producto_id uuid references public.productos (id) on delete cascade,
  variante_id uuid references public.variantes_producto (id) on delete cascade,
  valor text not null default '',
  constraint atributos_producto_destino_check check (
    (producto_id is not null and variante_id is null)
    or (producto_id is null and variante_id is not null)
  )
);

create unique index if not exists atributos_producto_producto_uidx
  on public.atributos_producto (atributo_id, producto_id)
  where producto_id is not null;

create unique index if not exists atributos_producto_variante_uidx
  on public.atributos_producto (atributo_id, variante_id)
  where variante_id is not null;

create table if not exists public.unidades_producto (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  producto_id uuid not null references public.productos (id) on delete cascade,
  variante_id uuid references public.variantes_producto (id) on delete set null,
  codigo text not null,
  estado text not null default 'disponible',
  pedido_id uuid references public.pedidos (id) on delete set null,
  creado_en timestamptz not null default now(),
  constraint unidades_estado_check check (
    estado in ('disponible', 'reservada', 'vendida', 'baja')
  )
);

create unique index if not exists unidades_codigo_lower_uidx
  on public.unidades_producto (negocio_id, lower(codigo));

alter table public.movimientos_stock
  add column if not exists variante_id uuid references public.variantes_producto (id) on delete set null,
  add column if not exists unidad_id uuid references public.unidades_producto (id) on delete set null,
  add column if not exists usuario_email text,
  add column if not exists creado_en timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- Ventas: origen, autor, precio histórico, seña y comprobante
-- 3.1 pedido, 3.2 seña, 3.3 comprobante, 3.4 WhatsApp, 3.5 filtros
-- ---------------------------------------------------------------------------

alter table public.pedidos
  add column if not exists cliente_id uuid references public.clientes (id) on delete set null,
  add column if not exists origen text not null default 'local',
  add column if not exists usuario_email text,
  add column if not exists medio_pago text,
  add column if not exists nota text not null default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.pedidos'::regclass
      and conname = 'pedidos_origen_check'
  ) then
    alter table public.pedidos
      add constraint pedidos_origen_check
      check (origen in ('local', 'tienda', 'asistente', 'manual'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.pedidos'::regclass
      and conname = 'pedidos_medio_pago_check'
  ) then
    alter table public.pedidos
      add constraint pedidos_medio_pago_check
      check (
        medio_pago is null
        or medio_pago in ('efectivo', 'transferencia', 'otro', 'fiado')
      );
  end if;
end $$;

alter table public.productos_pedido
  add column if not exists variante_id uuid references public.variantes_producto (id) on delete set null,
  add column if not exists unidad_id uuid references public.unidades_producto (id) on delete set null;

create table if not exists public.comprobantes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  pedido_id uuid references public.pedidos (id) on delete set null,
  cliente_id uuid references public.clientes (id) on delete set null,
  tipo text not null default 'pago',
  medio_pago text,
  monto numeric not null default 0,
  imagen_url text,
  nota text not null default '',
  usuario_email text,
  creado_en timestamptz not null default now(),
  constraint comprobantes_tipo_check check (tipo in ('senia', 'pago', 'foto')),
  constraint comprobantes_medio_check check (
    medio_pago is null
    or medio_pago in ('efectivo', 'transferencia', 'otro', 'fiado')
  )
);

create table if not exists public.historial_clientes (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes (id) on delete cascade,
  estado_anterior text not null,
  estado_nuevo text not null,
  creado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Finanzas: medio de pago y deuda vinculada al cliente y al pedido
-- 6.1 capital, 6.2 deudas, 6.3 medio y período (el período se calcula con la fecha)
-- ---------------------------------------------------------------------------

alter table public.movimientos_capital
  add column if not exists cliente_id uuid references public.clientes (id) on delete set null,
  add column if not exists pedido_id uuid references public.pedidos (id) on delete set null,
  add column if not exists medio_pago text,
  add column if not exists usuario_email text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.movimientos_capital'::regclass
      and conname = 'movimientos_capital_medio_check'
  ) then
    alter table public.movimientos_capital
      add constraint movimientos_capital_medio_check
      check (
        medio_pago is null
        or medio_pago in ('efectivo', 'transferencia', 'otro', 'fiado')
      );
  end if;
end $$;

create table if not exists public.deudas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  cliente_id uuid references public.clientes (id) on delete set null,
  pedido_id uuid references public.pedidos (id) on delete set null,
  persona text not null,
  monto_original numeric not null,
  saldo numeric not null,
  estado text not null default 'abierta',
  creado_en timestamptz not null default now(),
  constraint deudas_montos_check check (
    monto_original >= 0 and saldo >= 0 and saldo <= monto_original
  ),
  constraint deudas_estado_check check (estado in ('abierta', 'parcial', 'saldada'))
);

-- ---------------------------------------------------------------------------
-- Asistente: conversaciones, mensajes y tope del cupo
-- 4.1 a 4.4
-- ---------------------------------------------------------------------------

alter table public.asistente_cupo
  add column if not exists limite integer not null default 10;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.asistente_cupo'::regclass
      and conname = 'asistente_cupo_limite_check'
  ) then
    alter table public.asistente_cupo
      add constraint asistente_cupo_limite_check
      check (limite >= 0 and usados >= 0 and usados <= limite);
  end if;
end $$;

create table if not exists public.conversaciones_asistente (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  email text not null,
  titulo text not null default '',
  creado_en timestamptz not null default now()
);

create table if not exists public.mensajes_asistente (
  id uuid primary key default gen_random_uuid(),
  conversacion_id uuid not null references public.conversaciones_asistente (id) on delete cascade,
  rol text not null,
  contenido text not null,
  consumio_cupo boolean not null default false,
  creado_en timestamptz not null default now(),
  constraint mensajes_asistente_rol_check check (rol in ('user', 'assistant', 'system'))
);

-- ---------------------------------------------------------------------------
-- Auditoría. 1.4
-- El cliente autenticado solo lee. Escribe el disparador.
-- ---------------------------------------------------------------------------

create table if not exists public.auditoria (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references public.negocios (id) on delete cascade,
  tabla text not null,
  registro_id text not null default '',
  accion text not null,
  actor_email text,
  detalle jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now(),
  constraint auditoria_accion_check check (accion in ('insert', 'update', 'delete'))
);

create index if not exists auditoria_negocio_fecha_idx
  on public.auditoria (negocio_id, creado_en desc);

create or replace function public.registrar_auditoria()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  fila jsonb;
  negocio uuid;
  registro text;
begin
  if tg_op = 'DELETE' then
    fila := to_jsonb(old);
  else
    fila := to_jsonb(new);
  end if;

  registro := coalesce(fila ->> 'id', '');
  begin
    negocio := nullif(fila ->> 'negocio_id', '')::uuid;
  exception when invalid_text_representation then
    negocio := null;
  end;

  if negocio is null and fila ? 'pedido_id' then
    select p.negocio_id into negocio
    from public.pedidos as p
    where p.id = nullif(fila ->> 'pedido_id', '')::uuid;
  end if;

  if negocio is null and fila ? 'cliente_id' then
    select c.negocio_id into negocio
    from public.clientes as c
    where c.id = nullif(fila ->> 'cliente_id', '')::uuid;
  end if;

  if negocio is null and fila ? 'conversacion_id' then
    select cv.negocio_id into negocio
    from public.conversaciones_asistente as cv
    where cv.id = nullif(fila ->> 'conversacion_id', '')::uuid;
  end if;

  insert into public.auditoria (
    negocio_id, tabla, registro_id, accion, actor_email, detalle
  )
  values (
    negocio,
    tg_table_name,
    registro,
    lower(tg_op),
    nullif(lower(auth.jwt() ->> 'email'), ''),
    case
      when tg_op = 'DELETE' then jsonb_build_object('antes', to_jsonb(old))
      when tg_op = 'UPDATE' then jsonb_build_object('antes', to_jsonb(old), 'despues', to_jsonb(new))
      else jsonb_build_object('despues', to_jsonb(new))
    end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'negocios',
    'miembros',
    'clientes',
    'categorias',
    'atributos',
    'productos',
    'variantes_producto',
    'unidades_producto',
    'stock',
    'movimientos_stock',
    'pedidos',
    'productos_pedido',
    'comprobantes',
    'movimientos_capital',
    'deudas',
    'conversaciones_asistente',
    'mensajes_asistente'
  ]
  loop
    execute format('drop trigger if exists auditar_%I on public.%I', tabla, tabla);
    execute format(
      'create trigger auditar_%I after insert or update or delete on public.%I for each row execute function public.registrar_auditoria()',
      tabla,
      tabla
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Índices para los filtros de ventas, stock y deudas
-- ---------------------------------------------------------------------------

create index if not exists productos_categoria_idx on public.productos (categoria_id);
create index if not exists variantes_producto_idx on public.variantes_producto (producto_id);
create index if not exists unidades_producto_idx on public.unidades_producto (producto_id, estado);
create index if not exists pedidos_filtros_idx
  on public.pedidos (negocio_id, origen, creado_en desc);
create index if not exists pedidos_cliente_idx on public.pedidos (cliente_id);
create index if not exists comprobantes_pedido_idx on public.comprobantes (pedido_id);
create index if not exists deudas_cliente_idx on public.deudas (negocio_id, cliente_id, estado);
create index if not exists capital_fecha_idx
  on public.movimientos_capital (negocio_id, creado_en desc);
create index if not exists mensajes_conversacion_idx
  on public.mensajes_asistente (conversacion_id, creado_en);

-- La vidriera pública no muestra productos apagados ni ocultos.
create or replace view public.tienda_publica_productos
with (security_invoker = false)
as
select
  p.negocio_id,
  p.id,
  p.nombre,
  p.precio_venta,
  sum(s.cantidad)::bigint as stock
from public.productos as p
join public.negocios as n
  on n.id = p.negocio_id
 and n.tienda_activa
join public.stock as s
  on s.producto_id = p.id
 and s.negocio_id = p.negocio_id
where p.activo
  and p.visible_en_tienda
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0
group by p.negocio_id, p.id, p.nombre, p.precio_venta
having sum(s.cantidad) > 0;

alter view public.tienda_publica_productos owner to postgres;

-- ---------------------------------------------------------------------------
-- Acceso. Las tablas nuevas siguen la regla de 0001: miembro o dueño.
-- anon no recibe permisos. La auditoría no se escribe desde el cliente.
-- ---------------------------------------------------------------------------

alter table public.perfiles enable row level security;
alter table public.categorias enable row level security;
alter table public.atributos enable row level security;
alter table public.variantes_producto enable row level security;
alter table public.atributos_producto enable row level security;
alter table public.unidades_producto enable row level security;
alter table public.comprobantes enable row level security;
alter table public.historial_clientes enable row level security;
alter table public.deudas enable row level security;
alter table public.conversaciones_asistente enable row level security;
alter table public.mensajes_asistente enable row level security;
alter table public.auditoria enable row level security;

drop policy if exists perfiles_propia on public.perfiles;
create policy perfiles_propia
  on public.perfiles
  for all
  to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'))
  with check (lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists categorias_acceso on public.categorias;
create policy categorias_acceso
  on public.categorias
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists atributos_acceso on public.atributos;
create policy atributos_acceso
  on public.atributos
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists variantes_acceso on public.variantes_producto;
create policy variantes_acceso
  on public.variantes_producto
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists atributos_producto_acceso on public.atributos_producto;
create policy atributos_producto_acceso
  on public.atributos_producto
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists unidades_acceso on public.unidades_producto;
create policy unidades_acceso
  on public.unidades_producto
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists comprobantes_acceso on public.comprobantes;
create policy comprobantes_acceso
  on public.comprobantes
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists historial_clientes_acceso on public.historial_clientes;
create policy historial_clientes_acceso
  on public.historial_clientes
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.clientes as c
      where c.id = historial_clientes.cliente_id
        and (public.es_miembro(c.negocio_id) or public.es_dueno(c.negocio_id))
    )
  )
  with check (
    exists (
      select 1
      from public.clientes as c
      where c.id = historial_clientes.cliente_id
        and (public.es_miembro(c.negocio_id) or public.es_dueno(c.negocio_id))
    )
  );

drop policy if exists deudas_acceso on public.deudas;
create policy deudas_acceso
  on public.deudas
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists conversaciones_acceso on public.conversaciones_asistente;
create policy conversaciones_acceso
  on public.conversaciones_asistente
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists mensajes_acceso on public.mensajes_asistente;
create policy mensajes_acceso
  on public.mensajes_asistente
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.conversaciones_asistente as c
      where c.id = mensajes_asistente.conversacion_id
        and (public.es_miembro(c.negocio_id) or public.es_dueno(c.negocio_id))
    )
  )
  with check (
    exists (
      select 1
      from public.conversaciones_asistente as c
      where c.id = mensajes_asistente.conversacion_id
        and (public.es_miembro(c.negocio_id) or public.es_dueno(c.negocio_id))
    )
  );

drop policy if exists auditoria_lectura on public.auditoria;
create policy auditoria_lectura
  on public.auditoria
  for select
  to authenticated
  using (
    negocio_id is not null
    and (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  );

revoke all on function public.registrar_auditoria() from public, anon, authenticated;
revoke all on function public.limitar_equipo() from public, anon, authenticated;

revoke all on table
  public.perfiles,
  public.categorias,
  public.atributos,
  public.variantes_producto,
  public.atributos_producto,
  public.unidades_producto,
  public.comprobantes,
  public.historial_clientes,
  public.deudas,
  public.conversaciones_asistente,
  public.mensajes_asistente,
  public.auditoria
from public, anon;

grant select, insert, update, delete on table
  public.perfiles,
  public.categorias,
  public.atributos,
  public.variantes_producto,
  public.atributos_producto,
  public.unidades_producto,
  public.comprobantes,
  public.historial_clientes,
  public.deudas,
  public.conversaciones_asistente,
  public.mensajes_asistente
to authenticated;

grant select on table public.auditoria to authenticated;

commit;

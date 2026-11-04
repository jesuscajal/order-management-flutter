-- Gexi: esquema multi-negocio y RLS para Supabase/Postgres.
-- Ejecutar una sola vez, en el SQL Editor, sobre una base sin estas tablas.
-- El cliente usa la clave anon (rol authenticated). No uses service_role en la app:
-- ese rol saltea RLS.

begin;

create extension if not exists pgcrypto;

-- gen_random_uuid() vive en public o en extensions, según dónde esté pgcrypto.
set local search_path to public, extensions;

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table public.negocios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  descripcion text not null default '',
  codigo text not null unique,
  rubros text[] not null default '{}',
  plantilla text not null default '',
  categorias text[] not null default '{}',
  atributos text[] not null default '{}',
  tipo_tienda text not null default 'Catálogo',
  configurado boolean not null default false,
  dueno_email text not null
);

create table public.miembros (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  email text not null,
  rol text not null,
  unique (negocio_id, email)
);

create table public.clientes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  nombre text not null,
  telefono text,
  email text
);

create table public.productos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  nombre text not null,
  precio_compra numeric not null default 0,
  precio_venta numeric not null default 0
);

create table public.stock (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  producto_id uuid not null references public.productos (id),
  propietario text not null,
  cantidad integer not null,
  constraint stock_cantidad_no_negativa check (cantidad >= 0),
  unique (producto_id, propietario)
);

create table public.movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  producto_id uuid not null references public.productos (id),
  propietario text not null,
  cantidad integer not null,
  tipo text not null,
  descripcion text
);

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  cliente_nombre text not null,
  estado text not null default 'pendiente',
  senia numeric not null default 0,
  total numeric not null default 0,
  creado_en timestamptz not null default now()
);

create table public.productos_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  producto_id uuid null references public.productos (id) on delete set null,
  nombre text not null,
  cantidad integer not null,
  precio_venta numeric not null default 0
);

create table public.historial_pedidos (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  estado text not null,
  nota text,
  creado_en timestamptz not null default now()
);

create table public.movimientos_capital (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  persona text not null,
  monto numeric not null,
  tipo text not null,
  descripcion text,
  creado_en timestamptz not null default now()
);

create table public.asistente_cupo (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id),
  email text not null,
  usados integer not null default 0,
  unique (negocio_id, email)
);

-- El unique (negocio_id, email) distingue mayúsculas. El acceso compara en
-- minúsculas, así que estas dos impiden el mismo email escrito distinto.
create unique index miembros_negocio_email_lower_uidx
  on public.miembros (negocio_id, lower(email));

create unique index asistente_cupo_negocio_email_lower_uidx
  on public.asistente_cupo (negocio_id, lower(email));

create index negocios_dueno_email_lower_idx
  on public.negocios (lower(dueno_email));

create index clientes_negocio_id_idx on public.clientes (negocio_id);
create index productos_negocio_id_idx on public.productos (negocio_id);
create index stock_negocio_id_idx on public.stock (negocio_id);
create index movimientos_stock_negocio_id_idx on public.movimientos_stock (negocio_id);
create index movimientos_stock_producto_id_idx on public.movimientos_stock (producto_id);
create index pedidos_negocio_id_idx on public.pedidos (negocio_id);
create index productos_pedido_pedido_id_idx on public.productos_pedido (pedido_id);
create index productos_pedido_producto_id_idx on public.productos_pedido (producto_id);
create index historial_pedidos_pedido_id_idx on public.historial_pedidos (pedido_id);
create index movimientos_capital_negocio_id_idx on public.movimientos_capital (negocio_id);

-- ---------------------------------------------------------------------------
-- Helpers. security definer para leer miembros/negocios sin recursión de RLS.
-- Comparan el email del JWT ya pasado a minúsculas.
-- ---------------------------------------------------------------------------

create or replace function public.es_miembro(negocio uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.miembros as m
    where m.negocio_id = es_miembro.negocio
      and lower(m.email) = lower(auth.jwt() ->> 'email')
      and length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
  );
$$;

create or replace function public.es_dueno(negocio uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.negocios as n
    where n.id = es_dueno.negocio
      and lower(n.dueno_email) = lower(auth.jwt() ->> 'email')
      and length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
  );
$$;

comment on function public.es_miembro(uuid) is
  'True si el email del JWT, en minúsculas, está en miembros de ese negocio.';

comment on function public.es_dueno(uuid) is
  'True si el email del JWT, en minúsculas, es negocios.dueno_email.';

revoke all on function public.es_miembro(uuid) from public;
revoke all on function public.es_dueno(uuid) from public;
revoke all on function public.es_miembro(uuid) from anon;
revoke all on function public.es_dueno(uuid) from anon;
grant execute on function public.es_miembro(uuid) to authenticated;
grant execute on function public.es_dueno(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.negocios enable row level security;
alter table public.miembros enable row level security;
alter table public.clientes enable row level security;
alter table public.productos enable row level security;
alter table public.stock enable row level security;
alter table public.movimientos_stock enable row level security;
alter table public.pedidos enable row level security;
alter table public.productos_pedido enable row level security;
alter table public.historial_pedidos enable row level security;
alter table public.movimientos_capital enable row level security;
alter table public.asistente_cupo enable row level security;

-- Alta de negocio: cualquier autenticado, y el dueño es el email del JWT.
create policy negocios_alta
  on public.negocios
  for insert
  to authenticated
  with check (
    length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
    and lower(dueno_email) = lower(auth.jwt() ->> 'email')
  );

-- Dueño o miembro. El email se compara también sobre la fila nueva: es_dueno()
-- relee la tabla y, en el INSERT ... RETURNING, esa fila todavía no es visible.
create policy negocios_lectura
  on public.negocios
  for select
  to authenticated
  using (
    public.es_miembro(id)
    or public.es_dueno(id)
    or (
      length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
      and lower(dueno_email) = lower(auth.jwt() ->> 'email')
    )
  );

create policy negocios_cambio
  on public.negocios
  for update
  to authenticated
  using (
    public.es_miembro(id)
    or public.es_dueno(id)
    or (
      length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
      and lower(dueno_email) = lower(auth.jwt() ->> 'email')
    )
  )
  with check (
    public.es_miembro(id)
    or public.es_dueno(id)
    or (
      length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
      and lower(dueno_email) = lower(auth.jwt() ->> 'email')
    )
  );

create policy negocios_baja
  on public.negocios
  for delete
  to authenticated
  using (
    public.es_miembro(id)
    or public.es_dueno(id)
    or (
      length(trim(coalesce(auth.jwt() ->> 'email', ''))) > 0
      and lower(dueno_email) = lower(auth.jwt() ->> 'email')
    )
  );

-- Filas del negocio: un miembro o el dueño lee y escribe.
create policy miembros_acceso
  on public.miembros
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy clientes_acceso
  on public.clientes
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy productos_acceso
  on public.productos
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy stock_acceso
  on public.stock
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy movimientos_stock_acceso
  on public.movimientos_stock
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy pedidos_acceso
  on public.pedidos
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy movimientos_capital_acceso
  on public.movimientos_capital
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

create policy asistente_cupo_acceso
  on public.asistente_cupo
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

-- Sin negocio_id propio: el permiso sale del pedido padre.
create policy productos_pedido_acceso
  on public.productos_pedido
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.pedidos as p
      where p.id = productos_pedido.pedido_id
        and (public.es_miembro(p.negocio_id) or public.es_dueno(p.negocio_id))
    )
  )
  with check (
    exists (
      select 1
      from public.pedidos as p
      where p.id = productos_pedido.pedido_id
        and (public.es_miembro(p.negocio_id) or public.es_dueno(p.negocio_id))
    )
  );

create policy historial_pedidos_acceso
  on public.historial_pedidos
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.pedidos as p
      where p.id = historial_pedidos.pedido_id
        and (public.es_miembro(p.negocio_id) or public.es_dueno(p.negocio_id))
    )
  )
  with check (
    exists (
      select 1
      from public.pedidos as p
      where p.id = historial_pedidos.pedido_id
        and (public.es_miembro(p.negocio_id) or public.es_dueno(p.negocio_id))
    )
  );

revoke all on table
  public.negocios,
  public.miembros,
  public.clientes,
  public.productos,
  public.stock,
  public.movimientos_stock,
  public.pedidos,
  public.productos_pedido,
  public.historial_pedidos,
  public.movimientos_capital,
  public.asistente_cupo
from public, anon;

grant select, insert, update, delete on table
  public.negocios,
  public.miembros,
  public.clientes,
  public.productos,
  public.stock,
  public.movimientos_stock,
  public.pedidos,
  public.productos_pedido,
  public.historial_pedidos,
  public.movimientos_capital,
  public.asistente_cupo
to authenticated;

do $$
declare
  sin_rls text;
  politicas integer;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into sin_rls
  from pg_class as c
  join pg_namespace as n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relname in (
      'negocios',
      'miembros',
      'clientes',
      'productos',
      'stock',
      'movimientos_stock',
      'pedidos',
      'productos_pedido',
      'historial_pedidos',
      'movimientos_capital',
      'asistente_cupo'
    )
    and not c.relrowsecurity;

  if sin_rls is not null then
    raise exception 'RLS inactiva en: %', sin_rls;
  end if;

  select count(*)
    into politicas
  from pg_policies
  where schemaname = 'public'
    and tablename in (
      'negocios',
      'miembros',
      'clientes',
      'productos',
      'stock',
      'movimientos_stock',
      'pedidos',
      'productos_pedido',
      'historial_pedidos',
      'movimientos_capital',
      'asistente_cupo'
    );

  if politicas <> 14 then
    raise exception 'Se esperaban 14 políticas RLS y hay %', politicas;
  end if;
end $$;

commit;

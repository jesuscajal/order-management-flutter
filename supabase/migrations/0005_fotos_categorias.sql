-- Varias categorías por producto y varias fotos, también por variante.
-- Aplicar después de 0004_tienda_descripcion.sql.
-- anon sigue sin leer las tablas base. Solo ve las vistas públicas.
-- Los archivos viven en el bucket público `productos`. La tabla guarda la URL.

begin;

set local search_path to public, extensions;

create table if not exists public.productos_categorias (
  producto_id uuid not null references public.productos (id) on delete cascade,
  categoria_id uuid not null references public.categorias (id) on delete cascade,
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  primary key (producto_id, categoria_id)
);

create index if not exists productos_categorias_categoria_idx
  on public.productos_categorias (categoria_id);

create table if not exists public.fotos_producto (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  producto_id uuid not null references public.productos (id) on delete cascade,
  variante_id uuid references public.variantes_producto (id) on delete cascade,
  url text not null,
  orden integer not null default 0,
  creado_en timestamptz not null default now(),
  constraint fotos_producto_url_check check (length(trim(url)) > 0),
  constraint fotos_producto_orden_check check (orden >= 0)
);

create index if not exists fotos_producto_producto_idx
  on public.fotos_producto (producto_id, orden);

insert into public.productos_categorias (producto_id, categoria_id, negocio_id)
select p.id, p.categoria_id, p.negocio_id
from public.productos as p
where p.categoria_id is not null
on conflict do nothing;

insert into public.fotos_producto (negocio_id, producto_id, url, orden)
select p.negocio_id, p.id, p.imagen_url, 0
from public.productos as p
where length(trim(coalesce(p.imagen_url, ''))) > 0
  and not exists (
    select 1
    from public.fotos_producto as f
    where f.producto_id = p.id
      and f.variante_id is null
  );

alter table public.productos_categorias enable row level security;
alter table public.fotos_producto enable row level security;

drop policy if exists productos_categorias_acceso on public.productos_categorias;
create policy productos_categorias_acceso
  on public.productos_categorias
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists fotos_producto_acceso on public.fotos_producto;
create policy fotos_producto_acceso
  on public.fotos_producto
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

revoke all on table public.productos_categorias, public.fotos_producto
from public, anon;

grant select, insert, update, delete on table
  public.productos_categorias,
  public.fotos_producto
to authenticated;

drop trigger if exists auditar_productos_categorias on public.productos_categorias;
create trigger auditar_productos_categorias
  after insert or update or delete on public.productos_categorias
  for each row execute function public.registrar_auditoria();

drop trigger if exists auditar_fotos_producto on public.fotos_producto;
create trigger auditar_fotos_producto
  after insert or update or delete on public.fotos_producto
  for each row execute function public.registrar_auditoria();

-- La vista de 0004 no puede ganar columnas en el medio. Se recrea.
drop view if exists public.tienda_publica_productos;

create view public.tienda_publica_productos
with (security_invoker = false)
as
select
  p.negocio_id,
  p.id,
  p.nombre,
  p.precio_venta,
  p.descripcion,
  sum(s.cantidad)::bigint as stock,
  (
    select coalesce(
      array_agg(cat.nombre order by cat.orden, cat.nombre),
      '{}'::text[]
    )
    from public.productos_categorias as pc
    join public.categorias as cat
      on cat.id = pc.categoria_id
     and cat.activo
    where pc.producto_id = p.id
  ) as categorias,
  (
    select coalesce(
      array_agg(f.url order by f.orden, f.creado_en),
      '{}'::text[]
    )
    from public.fotos_producto as f
    where f.producto_id = p.id
      and f.variante_id is null
  ) as fotos
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
group by p.negocio_id, p.id, p.nombre, p.precio_venta, p.descripcion
having sum(s.cantidad) > 0;

alter view public.tienda_publica_productos owner to postgres;

create or replace view public.tienda_publica_fotos
with (security_invoker = false)
as
select
  p.negocio_id,
  p.id as producto_id,
  coalesce(v.nombre, '') as variante,
  f.url,
  f.orden
from public.fotos_producto as f
join public.productos as p
  on p.id = f.producto_id
join public.negocios as n
  on n.id = p.negocio_id
 and n.tienda_activa
left join public.variantes_producto as v
  on v.id = f.variante_id
where p.activo
  and p.visible_en_tienda
  and (f.variante_id is null or v.activo)
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

alter view public.tienda_publica_fotos owner to postgres;

revoke all on table public.tienda_publica_productos from public, anon, authenticated;
revoke all on table public.tienda_publica_fotos from public, anon, authenticated;
grant select on table public.tienda_publica_productos to anon, authenticated;
grant select on table public.tienda_publica_fotos to anon, authenticated;

-- Primera carpeta de la ruta = id del negocio. Así el miembro no sube a otra tienda.
create or replace function public.negocio_de_ruta_foto(ruta text)
returns uuid
language plpgsql
stable
set search_path = public
as $$
declare
  carpeta text;
begin
  carpeta := split_part(coalesce(ruta, ''), '/', 1);
  if carpeta !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return null;
  end if;
  return carpeta::uuid;
exception
  when others then
    return null;
end;
$$;

revoke all on function public.negocio_de_ruta_foto(text) from public, anon, authenticated;
grant execute on function public.negocio_de_ruta_foto(text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'productos',
  'productos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists productos_fotos_lectura on storage.objects;
create policy productos_fotos_lectura
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'productos'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  );

drop policy if exists productos_fotos_alta on storage.objects;
create policy productos_fotos_alta
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'productos'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  );

drop policy if exists productos_fotos_cambio on storage.objects;
create policy productos_fotos_cambio
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'productos'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  )
  with check (
    bucket_id = 'productos'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  );

drop policy if exists productos_fotos_baja on storage.objects;
create policy productos_fotos_baja
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'productos'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  );

drop policy if exists productos_fotos_publicas on storage.objects;
create policy productos_fotos_publicas
  on storage.objects
  for select
  to anon
  using (bucket_id = 'productos');

commit;

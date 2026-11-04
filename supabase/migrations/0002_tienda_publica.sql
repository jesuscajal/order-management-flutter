-- Tienda pública por subdominio. Aplicar después de 0001_gexi.sql.

begin;

alter table public.negocios
  add column if not exists slug text,
  add column if not exists tienda_activa boolean not null default false,
  add column if not exists whatsapp text,
  add column if not exists mensaje_publico text;

create unique index if not exists negocios_slug_lower_uidx
  on public.negocios (lower(slug))
  where slug is not null and slug <> '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.negocios'::regclass
      and conname = 'negocios_slug_formato_check'
  ) then
    alter table public.negocios
      add constraint negocios_slug_formato_check check (
        slug is null
        or slug = ''
        or (
          slug = lower(slug)
          and slug ~ '^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$'
          and slug !~ '--'
          and slug not in (
            'www', 'app', 'api', 'admin', 'mail', 'gexi', 'supabase',
            'tienda', 'login', 'static', 'ftp', 'smtp', 'ns1', 'ns2'
          )
        )
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.negocios'::regclass
      and conname = 'negocios_tienda_activa_datos_check'
  ) then
    alter table public.negocios
      add constraint negocios_tienda_activa_datos_check check (
        not tienda_activa
        or (
          length(trim(coalesce(slug, ''))) > 0
          and length(trim(coalesce(whatsapp, ''))) > 0
        )
      );
  end if;
end $$;

create or replace view public.tienda_publica
with (security_invoker = false)
as
select
  n.id,
  n.nombre,
  n.slug,
  n.whatsapp,
  n.mensaje_publico
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

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
where length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0
group by p.negocio_id, p.id, p.nombre, p.precio_venta
having sum(s.cantidad) > 0;

alter view public.tienda_publica owner to postgres;
alter view public.tienda_publica_productos owner to postgres;

revoke all on table public.tienda_publica from public, anon, authenticated;
revoke all on table public.tienda_publica_productos from public, anon, authenticated;
grant select on table public.tienda_publica to anon, authenticated;
grant select on table public.tienda_publica_productos to anon, authenticated;

commit;

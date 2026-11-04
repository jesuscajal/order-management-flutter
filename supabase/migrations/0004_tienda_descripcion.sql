-- Descripción en la vidriera pública.
-- Aplicar en el SQL Editor después de 0001, 0002 y 0003.
-- No abre RLS de productos ni de stock: anon sigue sin leer esas tablas.
-- Solo amplía la vista que anon ya puede consultar.
-- No incluye variantes: variantes_producto no es pública.

begin;

-- CREATE OR REPLACE no puede insertar una columna en el medio.
-- La vista de 0003 termina en stock; acá descripcion va antes.
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
group by p.negocio_id, p.id, p.nombre, p.precio_venta, p.descripcion
having sum(s.cantidad) > 0;

alter view public.tienda_publica_productos owner to postgres;

revoke all on table public.tienda_publica_productos from public, anon, authenticated;
grant select on table public.tienda_publica_productos to anon, authenticated;

commit;

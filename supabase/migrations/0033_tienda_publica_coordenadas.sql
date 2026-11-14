-- La página pública necesita el punto del local para abrir Google Maps
-- en esa coordenada, no solo el texto de la dirección.

create or replace view public.tienda_publica
with (security_invoker = false)
as
select
  n.id,
  n.nombre,
  n.slug,
  n.whatsapp,
  n.mensaje_publico,
  n.moneda,
  n.apariencia,
  n.logo_url,
  n.alias_cobro,
  n.facebook_url,
  n.instagram_url,
  n.maps_url,
  n.horario,
  n.rubros,
  n.tipo_tienda,
  n.latitud,
  n.longitud
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

grant select on table public.tienda_publica to anon, authenticated;

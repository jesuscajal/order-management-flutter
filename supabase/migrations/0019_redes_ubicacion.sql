-- Enlaces opcionales de la página del negocio: Facebook, Instagram
-- y ubicación (enlace de Google Maps o una dirección).

alter table public.negocios
  add column if not exists facebook_url text,
  add column if not exists instagram_url text,
  add column if not exists maps_url text;

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
  n.maps_url
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

grant select on table public.tienda_publica to anon, authenticated;

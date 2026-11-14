-- El horario ya vive en negocios. La página pública lo muestra
-- solo si el negocio lo cargó. Se recrea la vista de 0019 y se suma horario.

alter table public.negocios
  add column if not exists horario text not null default '';

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
  n.horario
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

grant select on table public.tienda_publica to anon, authenticated;

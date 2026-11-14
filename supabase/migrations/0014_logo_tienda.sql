-- Logo del negocio, visible en la página pública.

alter table public.negocios
  add column if not exists logo_url text;

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
  n.logo_url
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

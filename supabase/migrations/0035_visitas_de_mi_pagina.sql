-- El teléfono no guarda el id del negocio. Las visitas se leen por la dirección
-- de la página, y solo si esa cuenta es dueña o miembro.

drop function if exists public.visitas_negocio(uuid);

create or replace function public.visitas_de_mi_pagina(p_slug text)
returns table (hoy bigint, mes bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  negocio uuid;
begin
  select n.id
    into negocio
  from public.negocios as n
  where lower(n.slug) = lower(trim(coalesce(p_slug, '')))
    and length(trim(coalesce(n.slug, ''))) > 0
    and (public.es_miembro(n.id) or public.es_dueno(n.id))
  limit 1;
  if negocio is null then
    return;
  end if;
  return query
  select
    count(*) filter (
      where v.creado_en >= date_trunc('day', now())
    ),
    count(*) filter (
      where v.creado_en >= date_trunc('month', now())
    )
  from public.visitas_tienda as v
  where v.negocio_id = negocio;
end;
$$;

revoke all on function public.visitas_de_mi_pagina(text) from public, anon;
grant execute on function public.visitas_de_mi_pagina(text) to authenticated;

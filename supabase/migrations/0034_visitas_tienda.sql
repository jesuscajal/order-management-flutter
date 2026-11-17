-- Cada vez que alguien abre una tienda publicada se anota una visita.
-- No se guarda quién entró ni la dirección IP.

create table if not exists public.visitas_tienda (
  id bigint generated always as identity primary key,
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  creado_en timestamptz not null default now()
);

create index if not exists visitas_tienda_negocio_fecha_idx
  on public.visitas_tienda (negocio_id, creado_en desc);

alter table public.visitas_tienda enable row level security;

revoke all on table public.visitas_tienda from public, anon, authenticated;

create or replace function public.registrar_visita_tienda(p_slug text)
returns void
language plpgsql
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
    and n.tienda_activa
    and length(trim(coalesce(n.slug, ''))) > 0
  limit 1;
  if negocio is null then
    return;
  end if;
  insert into public.visitas_tienda (negocio_id) values (negocio);
end;
$$;

revoke all on function public.registrar_visita_tienda(text) from public;
grant execute on function public.registrar_visita_tienda(text) to anon, authenticated;

create or replace function public.visitas_negocio(p_negocio uuid)
returns table (hoy bigint, mes bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_negocio is null
      or not (public.es_miembro(p_negocio) or public.es_dueno(p_negocio)) then
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
  where v.negocio_id = p_negocio;
end;
$$;

revoke all on function public.visitas_negocio(uuid) from public, anon;
grant execute on function public.visitas_negocio(uuid) to authenticated;

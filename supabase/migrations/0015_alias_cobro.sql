-- Dato de cobro del negocio (CBU, CVU o alias en un solo texto)
-- y la dirección del comprobante que adjunta el visitante.

alter table public.negocios
  add column if not exists alias_cobro text;

alter table public.pedidos
  add column if not exists comprobante_url text;

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
  n.alias_cobro
from public.negocios as n
where n.tienda_activa
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

-- El visitante sube el archivo después de crear el pedido.
-- Solo se acepta la ruta de un pedido web reciente.
create or replace function public.ruta_comprobante_valida(ruta text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pedidos as p
    where p.origen = 'tienda'
      and p.creado_en > now() - interval '3 hours'
      and lower(coalesce(ruta, '')) =
          lower(p.negocio_id::text || '/comprobantes/' || p.id::text || '.jpg')
  );
$$;

revoke all on function public.ruta_comprobante_valida(text) from public;
grant execute on function public.ruta_comprobante_valida(text) to anon, authenticated;

drop policy if exists productos_comprobantes_visitante on storage.objects;
create policy productos_comprobantes_visitante
  on storage.objects
  for insert
  to anon, authenticated
  with check (
    bucket_id = 'productos'
    and public.ruta_comprobante_valida(name)
  );

drop policy if exists productos_comprobantes_reemplazo on storage.objects;
create policy productos_comprobantes_reemplazo
  on storage.objects
  for update
  to anon, authenticated
  using (
    bucket_id = 'productos'
    and public.ruta_comprobante_valida(name)
  )
  with check (
    bucket_id = 'productos'
    and public.ruta_comprobante_valida(name)
  );

-- Anota la URL pública. No recibe el alias ni el precio.
create or replace function public.registrar_comprobante_tienda(
  p_pedido uuid,
  p_url text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  destino public.pedidos%rowtype;
  limpia text := trim(coalesce(p_url, ''));
  esperada text;
  marca text;
  cola text;
  prefijo text;
  host_pedido text;
  desde integer;
begin
  if p_pedido is null or limpia = '' or length(limpia) > 800 then
    raise exception 'No se pudo guardar el comprobante.';
  end if;

  select *
    into destino
  from public.pedidos as p
  where p.id = p_pedido
    and p.origen = 'tienda'
    and p.creado_en > now() - interval '3 hours';

  if not found then
    raise exception 'No se pudo guardar el comprobante.';
  end if;

  esperada := lower(
    destino.negocio_id::text || '/comprobantes/' || destino.id::text || '.jpg'
  );
  marca := '/storage/v1/object/public/productos/' || esperada;
  desde := position(marca in lower(limpia));
  prefijo := substring(lower(limpia) from 1 for greatest(desde - 1, 0));
  host_pedido := lower(coalesce(
    nullif(current_setting('request.headers', true), '')::json->>'host',
    ''
  ));
  if desde = 0
     or prefijo !~ '^https://[a-z0-9.-]+$'
     or (host_pedido <> '' and prefijo <> ('https://' || host_pedido)) then
    raise exception 'No se pudo guardar el comprobante.';
  end if;
  cola := substring(lower(limpia) from desde + length(marca));
  if cola <> '' and cola !~ '^\?[^[:space:]]*$' then
    raise exception 'No se pudo guardar el comprobante.';
  end if;

  if coalesce(destino.comprobante_url, '') <> ''
     and lower(destino.comprobante_url) is distinct from lower(limpia) then
    raise exception 'Ese pedido ya tiene un comprobante.';
  end if;

  update public.pedidos as p
  set comprobante_url = limpia
  where p.id = destino.id;
end;
$$;

revoke all on function public.registrar_comprobante_tienda(uuid, text) from public;
grant execute on function public.registrar_comprobante_tienda(uuid, text) to anon, authenticated;

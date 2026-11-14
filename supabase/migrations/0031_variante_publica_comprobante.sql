-- La página puede pedir una variante publicada: el precio y el stock salen de la base.
-- El comprobante nuevo va a un depósito privado. El bucket público de fotos no se toca.

alter table public.variantes_producto
  add column if not exists stock integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.variantes_producto'::regclass
      and conname = 'variantes_stock_no_negativo'
  ) then
    alter table public.variantes_producto
      add constraint variantes_stock_no_negativo
      check (stock is null or stock >= 0);
  end if;
end $$;

drop view if exists public.tienda_publica_variantes;

create view public.tienda_publica_variantes
with (security_invoker = false)
as
select
  v.negocio_id,
  v.producto_id,
  v.id,
  v.nombre,
  coalesce(v.precio_venta, p.precio_venta) as precio_venta,
  v.stock
from public.variantes_producto as v
join public.productos as p
  on p.id = v.producto_id
join public.negocios as n
  on n.id = p.negocio_id
 and n.tienda_activa
where v.activo
  and v.stock is not null
  and p.activo
  and p.visible_en_tienda
  and length(trim(coalesce(n.slug, ''))) > 0
  and length(trim(coalesce(n.whatsapp, ''))) > 0;

alter view public.tienda_publica_variantes owner to postgres;

revoke all on table public.tienda_publica_variantes from public, anon, authenticated;
grant select on table public.tienda_publica_variantes to anon, authenticated;

create or replace function public.crear_pedido_tienda(
  p_slug text,
  p_nombre text,
  p_telefono text,
  p_lineas jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  negocio uuid;
  pedido uuid;
  nombre text := trim(coalesce(p_nombre, ''));
  telefono text := left(trim(coalesce(p_telefono, '')), 30);
  nota text := 'Pedido desde la página web.';
  linea record;
  fila_stock record;
  precio numeric;
  disponible bigint;
  importe numeric := 0;
  restante integer;
  tomar integer;
  variante_stock integer;
  variante_precio numeric;
  variante_nombre text;
begin
  if nombre = '' or length(nombre) > 80 then
    raise exception 'Ingresá tu nombre.';
  end if;
  if p_lineas is null
     or jsonb_typeof(p_lineas) is distinct from 'array'
     or jsonb_array_length(p_lineas) < 1
     or jsonb_array_length(p_lineas) > 30 then
    raise exception 'El pedido necesita al menos un producto.';
  end if;

  select n.id
    into negocio
  from public.negocios as n
  where lower(n.slug) = lower(trim(coalesce(p_slug, '')))
    and n.tienda_activa
    and length(trim(coalesce(n.whatsapp, ''))) > 0;

  if negocio is null then
    raise exception 'La tienda no está publicada.';
  end if;

  if telefono <> '' then
    nota := nota || ' Tel: ' || telefono;
  end if;

  insert into public.pedidos (
    negocio_id,
    cliente_nombre,
    estado,
    senia,
    total,
    origen,
    categoria,
    nota
  ) values (
    negocio,
    nombre,
    'pendiente',
    0,
    0,
    'tienda',
    'web',
    nota
  )
  returning id into pedido;

  for linea in
    select (item->>'producto_id')::uuid as producto_id,
           nullif(item->>'variante_id', '')::uuid as variante_id,
           sum((item->>'cantidad')::integer) as cantidad
    from jsonb_array_elements(p_lineas) as item
    group by 1, 2
    order by 1, 2
  loop
    if linea.producto_id is null
       or linea.cantidad is null
       or linea.cantidad <= 0
       or linea.cantidad > 99 then
      raise exception 'Hay un producto del pedido que no es válido.';
    end if;

    precio := null;
    select p.precio_venta
      into precio
    from public.productos as p
    where p.id = linea.producto_id
      and p.negocio_id = negocio
      and p.activo
      and p.visible_en_tienda
      and p.precio_venta > 0;

    if precio is null then
      raise exception 'Un producto del pedido ya no está disponible.';
    end if;

    variante_stock := null;
    variante_precio := null;
    variante_nombre := null;
    if linea.variante_id is not null then
      select v.stock, v.precio_venta, v.nombre
        into variante_stock, variante_precio, variante_nombre
      from public.variantes_producto as v
      where v.id = linea.variante_id
        and v.producto_id = linea.producto_id
        and v.negocio_id = negocio
        and v.activo
      for update;

      if variante_nombre is null then
        raise exception 'Esa variante ya no está disponible.';
      end if;
      if variante_stock is null or variante_stock < linea.cantidad then
        raise exception 'No hay stock suficiente.';
      end if;
      if variante_precio is not null then
        precio := variante_precio;
      end if;
      if precio is null or precio <= 0 then
        raise exception 'Un producto del pedido ya no está disponible.';
      end if;

      update public.variantes_producto as v
      set stock = v.stock - linea.cantidad::integer
      where v.id = linea.variante_id
        and v.stock >= linea.cantidad::integer;

      if not found then
        raise exception 'No hay stock suficiente.';
      end if;
    end if;

    perform 1
    from public.stock as s
    where s.producto_id = linea.producto_id
      and s.negocio_id = negocio
    order by s.id
    for update;

    select coalesce(sum(s.cantidad), 0)
      into disponible
    from public.stock as s
    where s.producto_id = linea.producto_id
      and s.negocio_id = negocio;

    if linea.cantidad > disponible then
      raise exception 'No hay stock suficiente.';
    end if;

    restante := linea.cantidad;
    for fila_stock in
      select s.id, s.cantidad, s.propietario
      from public.stock as s
      where s.producto_id = linea.producto_id
        and s.negocio_id = negocio
        and s.cantidad > 0
      order by
        case lower(s.propietario)
          when 'yo' then 0
          when 'nildo' then 1
          else 2
        end,
        s.id
      for update
    loop
      exit when restante <= 0;
      tomar := least(fila_stock.cantidad, restante);
      update public.stock as s
      set cantidad = s.cantidad - tomar
      where s.id = fila_stock.id;

      insert into public.movimientos_stock (
        negocio_id,
        producto_id,
        propietario,
        cantidad,
        tipo,
        descripcion
      ) values (
        negocio,
        linea.producto_id,
        fila_stock.propietario,
        tomar,
        'salida',
        'Salida por pedido web ' || pedido::text
      );

      restante := restante - tomar;
    end loop;

    if restante > 0 then
      raise exception 'No hay stock suficiente.';
    end if;

    insert into public.productos_pedido (
      pedido_id,
      producto_id,
      variante_id,
      nombre,
      cantidad,
      precio_venta
    )
    select pedido,
           p.id,
           linea.variante_id,
           p.nombre,
           linea.cantidad::integer,
           precio
    from public.productos as p
    where p.id = linea.producto_id;

    if not found then
      raise exception 'Un producto del pedido ya no está disponible.';
    end if;

    importe := importe + precio * linea.cantidad;
  end loop;

  if importe <= 0 then
    raise exception 'El pedido necesita al menos un producto.';
  end if;

  update public.pedidos as destino
  set total = importe
  where destino.id = pedido;

  insert into public.historial_pedidos (pedido_id, estado, nota)
  values (pedido, 'pendiente', nota);

  return pedido;
exception
  when invalid_text_representation then
    raise exception 'Hay un producto del pedido que no es válido.';
end;
$$;

revoke all on function public.crear_pedido_tienda(text, text, text, jsonb) from public;
grant execute on function public.crear_pedido_tienda(text, text, text, jsonb) to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'comprobantes',
  'comprobantes',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists comprobantes_visitante_alta on storage.objects;
create policy comprobantes_visitante_alta
  on storage.objects
  for insert
  to anon, authenticated
  with check (
    bucket_id = 'comprobantes'
    and public.ruta_comprobante_valida(name)
  );

drop policy if exists comprobantes_visitante_reemplazo on storage.objects;
create policy comprobantes_visitante_reemplazo
  on storage.objects
  for update
  to anon, authenticated
  using (
    bucket_id = 'comprobantes'
    and public.ruta_comprobante_valida(name)
  )
  with check (
    bucket_id = 'comprobantes'
    and public.ruta_comprobante_valida(name)
  );

drop policy if exists comprobantes_negocio_lectura on storage.objects;
create policy comprobantes_negocio_lectura
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'comprobantes'
    and public.negocio_de_ruta_foto(name) is not null
    and (
      public.es_miembro(public.negocio_de_ruta_foto(name))
      or public.es_dueno(public.negocio_de_ruta_foto(name))
    )
  );

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
  ruta text;
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
  ruta := lower(split_part(limpia, '?', 1));

  if ruta = esperada then
    if coalesce(destino.comprobante_url, '') <> ''
       and position(esperada in lower(destino.comprobante_url)) = 0 then
      raise exception 'Ese pedido ya tiene un comprobante.';
    end if;
    update public.pedidos as p
    set comprobante_url = esperada
    where p.id = destino.id;
    return;
  end if;

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
     and lower(destino.comprobante_url) is distinct from lower(limpia)
     and position(esperada in lower(destino.comprobante_url)) = 0 then
    raise exception 'Ese pedido ya tiene un comprobante.';
  end if;

  update public.pedidos as p
  set comprobante_url = limpia
  where p.id = destino.id;
end;
$$;

revoke all on function public.registrar_comprobante_tienda(uuid, text) from public;
grant execute on function public.registrar_comprobante_tienda(uuid, text) to anon, authenticated;

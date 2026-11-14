-- Un visitante de la página puede dejar un pedido sin iniciar sesión.
-- El precio y el stock se leen en la base, no los manda el navegador.

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
  precio numeric;
  disponible bigint;
  importe numeric := 0;
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
           sum((item->>'cantidad')::integer) as cantidad
    from jsonb_array_elements(p_lineas) as item
    group by 1
  loop
    if linea.producto_id is null
       or linea.cantidad is null
       or linea.cantidad <= 0
       or linea.cantidad > 99 then
      raise exception 'Hay un producto del pedido que no es válido.';
    end if;

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

    select coalesce(sum(s.cantidad), 0)
      into disponible
    from public.stock as s
    where s.producto_id = linea.producto_id
      and s.negocio_id = negocio;

    if linea.cantidad > disponible then
      raise exception 'No hay stock suficiente.';
    end if;

    insert into public.productos_pedido (
      pedido_id,
      producto_id,
      nombre,
      cantidad,
      precio_venta
    )
    select pedido, p.id, p.nombre, linea.cantidad, p.precio_venta
    from public.productos as p
    where p.id = linea.producto_id;

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

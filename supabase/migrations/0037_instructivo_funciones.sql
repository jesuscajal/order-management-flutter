-- Guía de cada función de la app. El asistente la lee para explicarle
-- al dueño cómo se usa. La versión 1 es la de esta app. Si una función
-- cambia, se reemplazan estas filas con una versión mayor.

create table if not exists public.instructivo_funciones (
  clave text primary key,
  titulo text not null,
  texto text not null,
  palabras text[] not null default '{}',
  orden integer not null,
  version integer not null,
  interruptor text not null default ''
);

alter table public.instructivo_funciones enable row level security;

revoke all on table public.instructivo_funciones from public, anon;
grant select on table public.instructivo_funciones to authenticated;

drop policy if exists instructivo_funciones_lectura on public.instructivo_funciones;
create policy instructivo_funciones_lectura
  on public.instructivo_funciones
  for select
  to authenticated
  using (true);

insert into public.instructivo_funciones
  (clave, titulo, texto, palabras, orden, version, interruptor)
values
  (
    'inicio',
    'Inicio',
    'El inicio muestra el logo y el resumen: ventas de hoy, ventas del mes, visitantes de la página y pedidos que salieron de la página. Tocá el resumen para abrir Ventas. Debajo están los accesos a cada parte.',
    array['inicio', 'resumen', 'visitantes', 'pagina'],
    1, 1, ''
  ),
  (
    'pedidos',
    'Pedidos',
    'En Pedidos ves los encargos y su estado. El botón verde Nuevo pedido carga uno a mano. El botón chico de la caja registra una venta directa. Un pedido de la página llega solo y descuenta el stock.',
    array['pedido', 'pedidos', 'nuevo pedido', 'venta directa'],
    2, 1, ''
  ),
  (
    'stock',
    'Stock',
    'En Stock buscás un producto por nombre. Cada fila muestra tu cantidad, la de Nildo, el precio de venta y el total. Si el total está en rojo, está bajo. Añadir stock, el botón azul, carga uno nuevo. Tocá el producto para cambiar nombre, precios o anotar una entrada o una salida. La cámara de la fila agrega hasta 4 fotos.',
    array['stock', 'producto', 'productos', 'anadir stock', 'agregar stock', 'foto'],
    3, 1, 'consultarStock'
  ),
  (
    'clientes',
    'Clientes',
    'En Clientes guardás nombre y contacto. Desde un pedido podés asociar a la persona. El estado de pago queda en la ficha del cliente.',
    array['cliente', 'clientes', 'contacto'],
    4, 1, ''
  ),
  (
    'ventas',
    'Ventas',
    'Ventas resume hoy, los últimos 7 días y el mes, con la ganancia si los productos tienen precio de compra. Abajo están los más vendidos y las últimas ventas. El filtro de arriba achica la lista por estado, medio u origen.',
    array['venta', 'ventas', 'cuanto vendi', 'ganancia'],
    5, 1, 'ventasHoy'
  ),
  (
    'cierre',
    'Cierre de caja',
    'Cierre de caja muestra lo que entró y salió hoy, y el efectivo por separado. Contás el efectivo y la app lo compara con las entradas en efectivo. Las salidas no se restan. Anotar diferencia deja el registro; no borra movimientos.',
    array['cierre', 'caja', 'efectivo', 'arqueo'],
    6, 1, ''
  ),
  (
    'compra',
    'Compra',
    'Compra anota lo que le compraste a un proveedor y suma esas unidades al stock.',
    array['compra', 'proveedor', 'mercaderia'],
    7, 1, ''
  ),
  (
    'capital',
    'Capital',
    'Capital anota entradas y salidas de cada persona. El saldo de cada una es lo que entró menos lo que salió. Está en Más.',
    array['capital', 'socio', 'aporte'],
    8, 1, ''
  ),
  (
    'deudores',
    'Deudores',
    'Deudores lista a quien le vendiste fiado y todavía no pagó. El asistente también puede decir quién te debe, con los datos del teléfono.',
    array['deuda', 'deudas', 'deudor', 'fiado', 'debe'],
    9, 1, ''
  ),
  (
    'categorias',
    'Categorías',
    'Categorías ordena el catálogo de la página. El cliente ve los productos agrupados en ese orden.',
    array['categoria', 'categorias', 'catalogo'],
    10, 1, ''
  ),
  (
    'pagina',
    'Tu página web',
    'Tu página web publica el catálogo en gexi.com.ar y tu dirección. Ahí cargás el nombre, el mensaje, el logo, el alias de cobro, el horario y la calle con numeración. Si hay coordenadas, Cómo llegar abre Google Maps en ese punto. Los interruptores del asistente también están en esa pantalla.',
    array['pagina', 'tienda web', 'direccion', 'horario', 'logo', 'slug', 'maps'],
    11, 1, 'horarioDireccion'
  ),
  (
    'asistente',
    'Asistente',
    'El asistente responde con los datos del teléfono: ventas, stock, deudas, pedidos, capital, horario y dirección. Esas respuestas no gastan chats. Para anotar una venta o una entrada de stock arma un plan y recién guarda cuando tocás Confirmar. Preguntale cómo se usa cualquier parte de la app.',
    array['asistente', 'chat', 'gecko'],
    12, 1, 'anotarVenta'
  ),
  (
    'equipo',
    'Equipo',
    'Equipo invita a otra persona con un código. El empleado entra con ese código en un teléfono nuevo. Un administrador puede desactivar el acceso.',
    array['equipo', 'empleado', 'codigo', 'vendedor'],
    13, 1, ''
  ),
  (
    'moneda',
    'País y moneda',
    'País y moneda, en Más, cambia la moneda en la que se muestran los importes. Si confirmás el cambio, los precios guardados se convierten.',
    array['moneda', 'pais', 'cambiar moneda'],
    14, 1, ''
  ),
  (
    'actividad',
    'Actividad',
    'Actividad es el historial de este teléfono: pedidos, stock, clientes y capital. Podés filtrar por hoy, por 7 días o por tipo, y buscar por la persona.',
    array['actividad', 'historial', 'movimientos'],
    15, 1, ''
  ),
  (
    'cuenta',
    'Borrar cuenta',
    'Cerrar sesión sale sin borrar nada. Borrar cuenta, en Más, pide que escribas BORRAR. Ahí se eliminan las fotos, el negocio si sos el dueño y la cuenta con la que entraste. No se puede deshacer.',
    array['borrar cuenta', 'eliminar cuenta', 'cerrar sesion'],
    16, 1, ''
  )
on conflict (clave) do update set
  titulo = excluded.titulo,
  texto = excluded.texto,
  palabras = excluded.palabras,
  orden = excluded.orden,
  version = excluded.version,
  interruptor = excluded.interruptor;

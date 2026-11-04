# Brechas de Gexi frente a apps de microcomercio

Nota para Jesús Leonel Cajal, autor del TIF de Gexi. El piloto es Novaceltec, en Formosa.

Fecha de lectura: 4 de noviembre de 2026. Se usaron páginas públicas (sitio, ayuda y ficha de tienda). No se abrió una cuenta de pago ni se copió una pantalla cerrada.

La comparación de fondo es **Treinta** (treinta.co). Se suman tres comparables solo donde aportan un gesto concreto:

- **Pulpos** (México): mostrador, compras y corte de caja.
- **Loyverse**: turno de caja, descuento y código de barras.
- **Tiendanube**, en la parte del vendedor chico: foto, texto y variante en el catálogo.

El TIF deja afuera, a propósito, la publicación en Google Play y App Store, el cobro Premium, iOS, las pasarelas de pago, la facturación electrónica, la carga de productos por foto y la API empresarial de WhatsApp. Esas funciones aparecen en la sección «Fuera del TIF» y no se recomiendan para el prototipo.

## Qué ya muestra el prototipo

Para no volver a pedirlas: login con correo, negocio multirrubro, código de empleado en este dispositivo (dueño más cinco), categorías, ficha de producto (atributos, serie o IMEI, variantes, visibilidad y stock bajo), venta directa, estados de pedido, comprobante dentro de la app, WhatsApp, resumen de ventas con filtro por origen, tienda pública con agotados y consentimiento, capital clasificado, deudas a cobrar y a pagar, asistente con cupo 10 y actividad filtrable.

El esquema Postgres de `supabase/migrations/0001_gexi.sql`, `0002_tienda_publica.sql` y `0003_requerimientos.sql` ya tiene 23 tablas y RLS. La app del teléfono sigue en Drift y no usa todas esas tablas.

También quedan fuera de esta lista, porque ya están anotados:

- El botón de Google no tiene Client ID.
- Al vender no se elige el IMEI ni la variante, aunque la ficha los guarda.
- La tienda pública no guarda el pedido ni deja subir el comprobante del comprador.
- El código de empleado no cruza dispositivos. En `0003` la tabla `miembros` ya tiene `codigo_empleado` y el tope del equipo.
- El precio de la línea, en el teléfono, vive al lado de Drift. En Postgres, `productos_pedido.precio_venta` ya existe desde `0001`.

Treinta sincroniza celular y computadora en la nube. Ese camino ya está dibujado en el SQL. Esta nota no lo repite como si fuera un requisito nuevo: mira lo que el usuario todavía no puede hacer en la demo.

Otras piezas de Treinta ya tienen un equivalente y no hace falta copiarlas: el pedido pendiente cubre el «ticket abierto» de Loyverse; cancelar un pedido confirmado repone el stock; el abono parcial de una deuda ya baja el saldo; el comprobante de la app y el mensaje de WhatsApp ya existen. Treinta también habla de «factura»: en Gexi el comprobante simple alcanza. El documento fiscal queda fuera.

## Dentro del prototipo

Cada función está en Treinta o en un comparable, y la demo de Gexi no la muestra. La prioridad es para una defensa corta con Novaceltec, no para un producto comercial.

### 1. Medio de pago y fiado en la misma venta

**Qué hace el usuario.** Al cerrar la venta elige efectivo, transferencia u otro. Si el cliente se lleva la mercadería y paga nada o una parte, elige fiado. El saldo queda en la cuenta de esa persona.

**Para Novaceltec.** En el mostrador la pregunta de siempre es «¿efectivo, transferencia o te lo anoto?». Hoy la seña vive en el pedido y la deuda se carga aparte, en Capital. El medio de un movimiento de capital se guarda dentro del texto de la descripción.

**Encaje.** Entra en el prototipo. `0003` ya define `pedidos.medio_pago` (`efectivo`, `transferencia`, `otro`, `fiado`) y la tabla `deudas` (cliente, pedido, saldo y estado `abierta`, `parcial` o `saldada`). Falta usarlo en la venta.

**Prioridad.** Alta.

Fuente: [Treinta, tiendas de barrio](https://treinta.co/software-tiendas-de-barrio) (efectivo, transferencia o fiado, y el stock se descuenta solo) y [deudas](https://treinta.co/control-de-deudas/). Pulpos, en la [ayuda del punto de venta](https://ayuda.pulpos.com/como-funciona-el-punto-de-venta-en-pulpos), cobra con uno o varios medios y puede dejar el resto como deuda.

### 2. Proveedor y compra que repone el stock

**Qué hace el usuario.** Carga la ficha del proveedor (nombre y teléfono). Registra una compra con productos, cantidades y costo. El stock sube en ese momento. Si pagó solo una parte, el saldo queda entre las deudas a pagar, con el historial de esa cuenta.

**Para Novaceltec.** Reponer fundas, cargadores o equipos es el movimiento que más se repite después de vender. Hoy hay una entrada manual de stock (Yo o Nildo) y un precio de compra en el producto. No hay proveedor, ni una compra que una el ingreso de unidades con lo que se le debe.

**Encaje.** Entra en el prototipo. Todavía no hay tabla de proveedores ni de compras en el SQL. Las deudas a pagar y la entrada de stock ya existen por separado: esta función las junta.

**Prioridad.** Alta.

Fuente: [Treinta, proveedores](https://treinta.co/programa-de-gestion-de-proveedores-para-tu-negocio) y la pregunta frecuente de [funcionalidades](https://treinta.co/funcionalidades) (la compra suma unidades y deja el gasto). Pulpos separa compra (suma stock) y gasto (no toca el stock) en [Compras y Gastos](https://ayuda.pulpos.com/como-funciona-compras-y-gastos-en-pulpos).

### 3. Cierre de caja del día

**Qué hace el usuario.** Al abrir anota el efectivo inicial. Al cerrar ve cuánto entró en efectivo, cuánto en transferencia y cuánto debería haber. Cuenta el billete, escribe la diferencia si no cierra y guarda el turno.

**Para Novaceltec.** Es la cuenta de la noche, la que hoy se hace de memoria o en un papel. Sirve para separar la plata del negocio de un retiro personal.

**Encaje.** Entra en el prototipo. No está modelado en `0003`. Depende del medio de pago de la venta (punto 1) y de los gastos del día. El resumen actual suma pedidos por fecha y origen, y no arquea la caja.

**Prioridad.** Alta.

Fuente: [Treinta, caja diaria](https://treinta.co/caja-diaria-y-cierre-de-caja-para-tu-negocio). Loyverse documenta el mismo gesto en [cierre por turnos](https://help.loyverse.com/es/help/shift-management-loyverse-pos). Pulpos lo lista como corte de caja en el [punto de venta](https://pulpos.com/punto-de-venta/).

### 4. Vender un servicio sin descontar unidades

**Qué hace el usuario.** Marca un ítem como servicio (cambio de módulo, desbloqueo, instalación) y lo cobra en la misma venta que un accesorio. El stock de los productos no se mueve por ese ítem.

**Para Novaceltec.** Un local de tecnología cobra arreglos al lado de la venta de equipos. La ficha ya tiene el interruptor «Controla stock», pensado para vender aunque no haya unidades. La venta confirmada igual exige stock y lo descuenta. Con el interruptor apagado, el servicio no se puede cerrar si la cantidad es cero.

**Encaje.** Entra en el prototipo. El interruptor está solo en el teléfono. `0003` no tiene una marca de servicio.

**Prioridad.** Alta.

Fuente: Treinta responde en [funcionalidades](https://treinta.co/funcionalidades) que se pueden registrar y vender productos y servicios juntos, y en [servicios](https://treinta.co/servicios/) que el descuento también aplica a un servicio.

### 5. Fecha de cobro y aviso por WhatsApp

**Qué hace el usuario.** Al anotar un fiado pone para cuándo espera la plata. Ve una lista de lo vencido. Desde esa fila abre WhatsApp con un texto ya armado (nombre, saldo y pedido) y lo envía él mismo.

**Para Novaceltec.** El fiado del barrio se pierde cuando no hay fecha ni un recordatorio a mano. La deuda ya tiene saldo y abono. Le falta el día y el atajo para cobrar.

**Encaje.** Entra en el prototipo. `deudas` no tiene fecha de vencimiento: hay que agregarla. El aviso usa el WhatsApp que la app ya abre. La API empresarial queda fuera.

**Prioridad.** Alta.

Fuente: [Treinta, funcionalidades](https://treinta.co/funcionalidades), cobranza: saldos, fechas de pago y recordatorios. En [servicios](https://treinta.co/servicios/) el recordatorio es parte del seguimiento del crédito. El de Treinta puede salir solo desde sus servidores. En Gexi alcanza con la lista y el mensaje que dispara la persona.

### 6. Foto, texto y variante en la vidriera

**Qué hace el usuario.** En la ficha adjunta una foto tomada o elegida de la galería, escribe la descripción y publica la variante (color, capacidad, estado). Quien entra al subdominio ve eso, el precio y si hay stock. Elige la variante antes de armar el pedido.

**Para Novaceltec.** Un catálogo de celulares sin foto ni capacidad es difícil de mandar por WhatsApp. La tienda pública ya existe, con agotados y consentimiento. Muestra nombre, precio y stock.

**Encaje.** Entra en el prototipo. `0003` ya tiene `productos.imagen_url`, `productos.descripcion`, `variantes_producto` y atributos con `visible_en_tienda`. La vista `tienda_publica_productos` no los publica. Adjuntar la foto a mano entra. Leer el producto con visión artificial es la carga por foto y queda fuera. Elegir IMEI o variante al vender en el mostrador ya está anotado arriba y no se repite acá.

**Prioridad.** Alta.

Fuente: Treinta describe el catálogo virtual con fotos, precios y descripciones en [deudas](https://treinta.co/control-de-deudas/) y en [minimercados](https://treinta.co/software-para-minimercados). Tiendanube, en [gestión de stock](https://www.tiendanube.com/funcionalidades/gestion-de-stock), publica título, descripción, fotos y la foto de la variante elegida.

### 7. Resumen por medio, por persona y con ganancia

**Qué hace el usuario.** Filtra el período por medio de pago y por quien vendió. Además del total vendido, ve la ganancia: precio cobrado menos costo de esa línea.

**Para Novaceltec.** «¿Cuánto entró por transferencia?» y «¿cuánto dejó el vendedor?» son las dos preguntas del dueño. El costo ya está en el producto y el precio de venta también, pero el resumen suma importes y unidades. No muestra margen ni abre el filtro por medio. Quien no administra ya ve solo sus ventas. El dueño no compara al equipo.

**Encaje.** Entra en el prototipo. `pedidos.medio_pago` y `pedidos.usuario_email` están en `0003`. El costo de la línea, congelado el día de la venta, no está: si mañana cambia el precio de compra, la ganancia vieja se movería. Conviene guardarlo junto al precio histórico de la línea.

**Prioridad.** Alta.

Fuente: la pregunta frecuente de [Treinta](https://treinta.co/funcionalidades) filtra reportes por fecha, empleado, método de pago o producto. En el tutorial público de inventario, Treinta carga costo y precio para ver la ganancia de cada producto. Loyverse deja ver, o ocultar, el efectivo esperado según el permiso del empleado ([derechos de acceso](https://help.loyverse.com/es/help/how-manage-access-rights-employees)).

### 8. Descuento en la venta

**Qué hace el usuario.** Al cobrar aplica un porcentaje o un monto, sobre una línea o sobre el total. El pedido guarda el precio ya rebajado y el resumen usa ese número.

**Para Novaceltec.** El precio de un equipo se conversa en el mostrador. Hoy se puede tipear otro precio en la línea, sin dejar asentado que hubo un descuento ni quién lo autorizó.

**Encaje.** Entra en el prototipo. No está en el SQL. El precio rebajado puede vivir en `productos_pedido.precio_venta`, que ya existe. Hace falta el dato del descuento (tipo y valor) si la demo quiere mostrarlo aparte.

**Prioridad.** Alta.

Fuente: [Treinta, comercios](https://treinta.co/comercios) y [servicios](https://treinta.co/servicios/) (porcentaje o valor en producto o servicio). Loyverse documenta descuento por porcentaje o por importe, con opción de restringirlo a ciertos empleados, en su [guía de usuario](https://help.loyverse.com/sites/default/files/loyversepos-manual-es.pdf). Pulpos lo ofrece desde el [punto de venta](https://pulpos.com/punto-de-venta/).

### 9. Historial completo en la ficha del cliente

**Qué hace el usuario.** Abre un cliente y ve sus pedidos, con fecha, estado, total y saldo. No un recorte de los últimos nombres de producto.

**Para Novaceltec.** Quien vuelve a buscar el mismo modelo, o el mismo arreglo, se atiende más rápido si la ficha cuenta la historia. Hoy la lista de clientes arma un texto con hasta tres compras y las junta por el nombre, no por el id.

**Encaje.** Entra en el prototipo. `0003` ya liga `pedidos.cliente_id`. Falta mostrarlo en la ficha.

**Prioridad.** Media.

Fuente: [Treinta, funcionalidades](https://treinta.co/funcionalidades), manejo de clientes: contacto, historial y seguimiento. Loyverse muestra el historial de compras en la ficha ([loyverse.com/es](https://loyverse.com/es)).

### 10. Permisos según el rol

**Qué hace el usuario.** El dueño decide qué ve cada persona: vender y mirar stock, o también caja, deudas, capital y el equipo. Un vendedor no abre el cierre ni borra un producto.

**Para Novaceltec.** Con hasta cinco personas en el local, el riesgo es que cualquiera vea la caja o cambie un precio. Hoy el rol (vendedor o administrador) existe en el equipo de este dispositivo, y el resumen esconde las ventas ajenas a quien no administra. Capital, deudas y stock siguen abiertos en el mismo teléfono.

**Encaje.** Entra en el prototipo. `0003` ya limita el rol a `administrador`, `vendedor` o `empleado`. Falta que las pantallas obedezcan ese rol. El código entre dispositivos sigue siendo el hueco ya conocido.

**Prioridad.** Media.

Fuente: [Treinta, funcionalidades](https://treinta.co/funcionalidades) (perfiles y permisos por módulo) y [minimercados](https://treinta.co/software-para-minimercados) (el encargado vende y ve inventario, sin reportes financieros ni configuración).

### 11. Gasto con categoría

**Qué hace el usuario.** Al cargar un gasto elige una categoría (alquiler, luz, flete, sueldo, otro). El cierre del día y el capital pueden agruparse por esa categoría. Un gasto no suma stock. Una compra de mercadería sí, y va por el punto 2.

**Para Novaceltec.** Sirve para ver si el local gasta más en flete que en lo que vende. Hoy «Gasto» es un tipo de movimiento, sin rubro.

**Encaje.** Entra en el prototipo. No está en el SQL. `movimientos_capital` ya distingue el tipo `gasto`.

**Prioridad.** Media.

Fuente: [Treinta, funcionalidades](https://treinta.co/funcionalidades), registro de gastos clasificados. Pulpos insiste en la misma separación entre gasto y compra.

### 12. Buscar la venta por SKU o código de barras

**Qué hace el usuario.** En la venta escribe o escanea un código y el producto entra al pedido. Al cargar el producto, ese código queda en la ficha. Con la cámara del teléfono alcanza para la demo. Un lector aparte es hardware y queda fuera.

**Para Novaceltec.** Acelera fundas, cables y vidrios, que se parecen entre sí. El celular en sí se identifica mejor por IMEI, y eso ya está anotado como hueco de la venta.

**Encaje.** Entra en el prototipo. `0003` ya tiene `productos.sku` y un índice único por negocio. Falta pedirlo en la venta y, si se quiere el escaneo, leer el código con la cámara. Treinta publica EAN-13 y UPC-A ligados al lector de su plan Balance. Para Gexi, guardar el código y buscarlo alcanza. El lector de mostrador queda fuera.

**Prioridad.** Media.

Fuente: pregunta frecuente de [Treinta](https://treinta.co/funcionalidades) y la venta por código en [ferreterías](https://treinta.co/sistema-de-gestion-para-ferreterias). Loyverse agrega el artículo al ticket al escanear, también con la cámara, en la misma guía de usuario.

### 13. Pesos y horario de Formosa

**Qué hace el usuario.** El negocio queda en pesos y en el horario de Argentina. Precios, deudas y resumen se leen en esa moneda. El día del cierre empieza y termina en esa zona.

**Para Novaceltec.** La demo en Formosa se entiende en pesos. La app muestra USD en los pedidos. En `0003`, `negocios.moneda` nace en `USD` y `zona_horaria` en `America/Asuncion`.

**Encaje.** Entra en el prototipo. Las dos columnas ya están. Falta usarlas en pantalla y dejar un valor inicial útil para el piloto (ARS y un huso de Argentina).

**Prioridad.** Media.

Fuente: no es una pantalla de Treinta. Surge al contrastar el piloto con una app que trabaja en la moneda local del tendero. Treinta publica precios de plan en pesos colombianos en [funcionalidades](https://treinta.co/funcionalidades). Esos planes no se copian: el cobro Premium está fuera del TIF.

### 14. Planilla para cargar y bajar el inventario

**Qué hace el usuario.** Baja una planilla modelo, la llena con nombre, costo, precio, stock, categoría y código, y la sube. También puede exportar el inventario para revisarlo.

**Para Novaceltec.** Ahorra tiempo si el local ya tiene la lista en una hoja. Para una demo con pocos productos pesa poco.

**Encaje.** Entra en el prototipo como mejora chica. No está en el SQL. La fila que se importa usa las columnas que el producto ya tiene.

**Prioridad.** Baja.

Fuente: Treinta lo cuenta en [minimercados](https://treinta.co/software-para-minimercados) y en [ferreterías](https://treinta.co/sistema-de-gestion-para-ferreterias). Tiendanube lo ofrece como carga masiva, con variantes, en [gestión de stock](https://www.tiendanube.com/funcionalidades/gestion-de-stock).

## Fuera del TIF

Estas funciones están en las apps leídas. No se recomiendan para el prototipo.

| Función en la otra app | Dónde se vio | Por qué queda afuera |
| --- | --- | --- |
| Publicar en Play Store o App Store, cobrar un plan, versión iOS | Treinta en Google Play y planes en [funcionalidades](https://treinta.co/funcionalidades) | El TIF lo excluye. Gexi se muestra en el teléfono y en la web del prototipo. |
| Pasarela (Mercado Pago y similares) | Pulpos y Tiendanube | El TIF lo excluye. El medio «transferencia» del punto 1 es un registro, no un cobro en línea. |
| Factura electrónica, CFDI, timbrado, complemento de pago | Pulpos, en el [punto de venta](https://pulpos.com/punto-de-venta/) | El TIF lo excluye. El comprobante simple de Gexi sigue siendo el válido para la demo. `documento_fiscal` y `condicion_fiscal` en `0003` pueden guardar un dato del negocio. Emitir el comprobante fiscal es otra cosa. |
| Cargar el producto sacando una foto y dejando que un modelo lo identifique | El propio alcance de Gexi | El TIF lo excluye. La foto de catálogo del punto 6 es un archivo que elige la persona. |
| Recordatorios o catálogo por la API empresarial de WhatsApp | Treinta habla de recordatorios automáticos | El TIF lo excluye. El punto 5 abre el chat para que la persona envíe el mensaje. |
| Impresora térmica, cajón de dinero, báscula, lector de barras de mostrador | Loyverse y el plan de Pulpos que conecta dispositivos. Treinta menciona el lector en Balance | Hardware de caja. La demo corre en el teléfono. |
| Varias sucursales, traspasos y más de un almacén | Pulpos, [inventario](https://pulpos.com/gestion-de-inventario/) | Novaceltec es un local. El stock ya separa Yo y Nildo, y con eso alcanza. |
| Recetas para restaurante | Plan de Treinta en [funcionalidades](https://treinta.co/funcionalidades) | No es el piloto. El servicio del punto 4 cubre el arreglo. |
| Puntos, tarjetas de lealtad y monedero | Loyverse y planes altos de Pulpos | Mejora futura, fuera del alcance de esta demo. |
| Cupón con fecha, carrito abandonado, mail masivo, SEO, Mercado Libre | [Tiendanube, funcionalidades](https://www.tiendanube.com/funcionalidades) | Tienda grande. Gexi ya tiene vidriera por subdominio. |
| Recargas de celular y pago de servicios de terceros | Pulpos, en la ayuda del punto de venta | Depende de una red de cobranza. Se parece a una pasarela. |
| Listas de precios distintas por tipo de cliente | Pulpos, planes desde Esencial | Mejora futura. Un solo precio de venta, más el descuento del punto 8, alcanza para el piloto. |
| Varios medios en una misma venta (mitad efectivo y mitad transferencia) | Pulpos | Mejora futura. `medio_pago` admite un solo valor. Para la demo, un medio por venta es claro. |
| Devolución de una sola línea, cotización formal, kits | Pulpos, planes avanzados | Mejora futura. Cancelar el pedido ya repone todo el stock. El pedido pendiente ya sirve como presupuesto informal. |

## Orden sugerido si se sigue después de esta nota

Los ocho de prioridad alta, en un orden en el que cada uno deja el dato que el siguiente necesita:

1. Medio de pago y fiado en la venta, usando `pedidos.medio_pago` y `deudas`.
2. Compra al proveedor que sube el stock y, si queda saldo, la deuda a pagar.
3. Cierre de caja con ese medio y esos gastos.
4. Servicio que se cobra sin exigir unidades.
5. Fecha en la deuda y aviso que abre WhatsApp.
6. Foto, descripción y variante en la vidriera, con las columnas que `0003` ya tiene.
7. Resumen por medio, por persona y con ganancia.
8. Descuento asentado en la venta.

Permisos, historial del cliente, categoría de gasto, SKU, pesos y horario pueden entrar en la misma entrega si sobra lugar. La planilla queda para después de la demo.

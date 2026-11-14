# Requerimientos de Gexi

Especificación de los requerimientos trabajados hasta el 12 de noviembre de 2026. Sigue el criterio de la ingeniería de software: un requerimiento es una condición o capacidad que el sistema debe cumplir para satisfacer al usuario (IEEE 610 / IEEE 830).

Hay dos clases:

- **Funcional.** Describe qué debe hacer el sistema: una función observable por el dueño, el empleado o el cliente.
- **No funcional.** Describe cómo debe hacerlo: seguridad, integridad, disponibilidad, usabilidad, límites y aislamiento. No agrega una pantalla nueva; condiciona a las funciones.

Cada ítem usa esta plantilla:

| Campo | Significado |
| --- | --- |
| Identificador | `RF` funcional o `RNF` no funcional, más un número estable. |
| Prioridad | Must (imprescindible para el piloto), Should (importante) o Could (deseable). |
| Descripción | Redactada con «el sistema debe». |
| Criterio de aceptación | Condición comprobable, no una intención. |
| Estado | **Hecho**, **Parcial** o **Pendiente**. |
| Avance | 0 a 100. Hecho no baja de 85. Pendiente no pasa de 25. |

**Hecho** significa que la función está en el código y se comprobó en la base o en el flujo principal. **Parcial** significa que el comportamiento existe, pero falta una comprobación en el teléfono o en el sitio publicado, o le falta un caso. **Pendiente** significa que el caso todavía no cierra.

## Resumen

| Clase | Ítems | Avance promedio |
| --- | ---: | ---: |
| Funcionales | 35 | 77 % |
| No funcionales | 16 | 83 % |
| Total | 51 | 79 % |

| Estado | Cantidad |
| --- | ---: |
| Hecho | 20 |
| Parcial | 31 |
| Pendiente | 0 |

## 1. Requerimientos funcionales

### RF-01. Ingreso con correo

- **Prioridad:** Must.
- **Descripción:** El sistema debe permitir crear una cuenta e ingresar con correo y contraseña. Si el correo ya existe, debe abrir esa sesión y no crear otra.
- **Criterio de aceptación:** Con un correo nuevo se crea la sesión. Con el mismo correo y la clave correcta se entra a la cuenta existente.
- **Estado:** Hecho.
- **Avance:** 100 %.

### RF-02. Alta e ingreso con Google

- **Prioridad:** Must.
- **Descripción:** El sistema debe ofrecer crear la cuenta con Google además del correo. Si esa cuenta de Google ya tiene negocio, debe entrar a la app. Si no tiene negocio, debe seguir los pasos de crear el negocio o unirse con el código de empleado.
- **Criterio de aceptación:** En Crear cuenta aparece «Crear cuenta con Google». Una cuenta nueva llega al alta del negocio. Una cuenta que ya es dueña o empleada entra al inicio.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** El flujo está en el código y en el APK nuevo. No se recorrió con una cuenta de Google nueva sobre el sitio ya publicado.

### RF-03. Alta del negocio

- **Prioridad:** Must.
- **Descripción:** El sistema debe pedir nombre, rubro y país del negocio, y guardar un código propio de seis caracteres.
- **Criterio de aceptación:** Al terminar el alta existe un negocio con código, rubros y moneda, en el teléfono y en Supabase.
- **Estado:** Hecho.
- **Avance:** 100 %.
- **Evidencia:** Novaceltec (`ZJW44E`) y Burguershop (`H3DZQ4`) están en `negocios`.

### RF-04. Equipo y código de empleado

- **Prioridad:** Must.
- **Descripción:** El sistema debe permitir hasta cinco personas además del dueño. Un empleado debe poder unirse con su código en otro teléfono y quedar identificado en el pedido que vende o cobra.
- **Criterio de aceptación:** Un código válido asocia al empleado con ese negocio. Un código de otro negocio se rechaza. El detalle del pedido muestra quién vendió y quién cobró.
- **Estado:** Hecho.
- **Avance:** 90 %.
- **Nota:** El administrador tiene que guardar el equipo para que los códigos existan en Supabase.

### RF-05. Catálogo, categorías y ficha

- **Prioridad:** Must.
- **Descripción:** El sistema debe guardar productos con precio, stock, descripción, categorías, variantes y la marca de visible en la tienda.
- **Criterio de aceptación:** Un producto visible, con precio y stock mayor que cero, aparece en la página. Uno oculto, agotado o sin precio no aparece.
- **Estado:** Hecho.
- **Avance:** 85 %.
- **Nota:** La ficha y la página ya leen categorías. Los cuatro productos de Novaceltec siguen sin categoría asignada en la nube, así que la separación de la página no se ve hasta cargarla.

### RF-06. Fotos en el teléfono y en la nube

- **Prioridad:** Must.
- **Descripción:** El sistema debe guardar las fotos del producto en el teléfono y también en Supabase. Si otro teléfono no las tiene, debe bajarlas. No debe borrar las fotos remotas cuando la lista local llega vacía.
- **Criterio de aceptación:** Al guardar, la foto queda en el depósito `productos` y en `fotos_producto`. Un teléfono sin fotos locales las descarga. El comprobante de pago no entra a ese depósito.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RF-07. Pedido de mostrador

- **Prioridad:** Must.
- **Descripción:** El sistema debe crear un pedido con cliente, líneas, seña y estado, y descontar el stock que controla unidades.
- **Criterio de aceptación:** El pedido queda en el teléfono y, con sesión, en `pedidos` y `productos_pedido`. El stock baja según la cantidad vendida.
- **Estado:** Hecho.
- **Avance:** 90 %.
- **Nota:** Quedó abierto un fallo de la pantalla de pedidos (`Null` no es un `String`). No se volvió a reproducir en esta etapa.

### RF-08. Pedidos de la página dentro de la app

- **Prioridad:** Must.
- **Descripción:** El sistema debe registrar el pedido que arma el visitante de la página, abrirlo en WhatsApp y mostrarlo en la app como pedido de la página web.
- **Criterio de aceptación:** Pedir guarda `origen = tienda` y `categoria = web`, con el precio y el stock leídos en el servidor. Al reabrir la app, el pedido aparece. Si la función falla, la página avisa y no finge que se guardó.
- **Estado:** Hecho.
- **Avance:** 85 %.
- **Evidencia:** El pedido de Kevin Cajal en Burguershop quedó como pedido web de $25.000. La función se probó y el pedido de prueba se borró.

### RF-09. Dirección pública única

- **Prioridad:** Must.
- **Descripción:** El sistema debe publicar cada tienda en `https://gexi.com.ar/{direccion}`. Si el nombre ya lo usa otro negocio, debe agregar el código del negocio. La raíz del dominio debe seguir siendo el ingreso a la app.
- **Criterio de aceptación:** Dos negocios no pueden tener la misma dirección. La página de un slug reservado o inválido no muestra un catálogo.
- **Estado:** Hecho.
- **Avance:** 90 %.
- **Nota:** El sitio público muestra la versión que se sube a Cloudflare Pages. La web se volvió a compilar el 12 de noviembre en `build\web`. El último deploy subió la carpeta fuente `web` en lugar de `build\web`, y por eso la tienda se ve en blanco hasta subir el build.

### RF-10. Buscador y separación por categoría

- **Prioridad:** Must.
- **Descripción:** La página debe dejar buscar por nombre, descripción, categoría o variante, y mostrar los productos agrupados bajo el título de cada categoría.
- **Criterio de aceptación:** El texto filtra la lista. Cada categoría con productos tiene su título. «Sin categoría» solo aparece si también hay productos categorizados. Un producto sin categoría no se pierde.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** La pantalla está hecha y el buscador también filtra por el nombre de la variante. En los datos actuales de Novaceltec ninguna publicación tiene categoría, así que el agrupado todavía no se ve con productos reales.

### RF-11. Logo del negocio

- **Prioridad:** Should.
- **Descripción:** El sistema debe permitir elegir, cambiar y quitar el logo desde la configuración de la página, y mostrarlo arriba del nombre. Si no hay logo, debe mostrar la inicial del negocio.
- **Criterio de aceptación:** La imagen queda en el depósito `productos`, su dirección en `negocios.logo_url`, y la página pública la muestra.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** Burguershop ya tiene `logo_url` cargado y se ve en el panel del desarrollador. Novaceltec no tiene logo y muestra la inicial. No se comprobó en la página publicada.

### RF-12. Publicar y ocultar la página

- **Prioridad:** Must.
- **Descripción:** El sistema debe publicar u ocultar la página con el interruptor, y ese cambio debe quedar en Supabase antes de confirmarlo. Con la página oculta, la dirección pública no debe mostrar el catálogo.
- **Criterio de aceptación:** Al apagar, `tienda_activa` pasa a falso y la vista pública no devuelve esa tienda. Si la nube no responde, el interruptor vuelve al estado anterior y avisa.
- **Estado:** Hecho.
- **Avance:** 100 %.
- **Evidencia:** Novaceltec se ocultó y la vista pública dejó de devolverla. Burguershop quedó publicada aparte.

### RF-13. Apariencia de la vidriera

- **Prioridad:** Should.
- **Descripción:** El sistema debe guardar color, forma, texto del botón y tipo de portada, y usarlos en la página.
- **Criterio de aceptación:** El cambio se guarda en el teléfono y en `negocios.apariencia`, y se recupera en otro teléfono.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RF-14. País y moneda

- **Prioridad:** Must.
- **Descripción:** El sistema debe guardar el país y la moneda del negocio, y mostrar los precios de la página en esa moneda.
- **Criterio de aceptación:** El alta y la configuración persisten un código de moneda de la lista admitida. Los importes de la página usan ese código.
- **Estado:** Parcial.
- **Avance:** 70 %.
- **Nota:** Guardar y mostrar la moneda está hecho. La conversión de importes al cambiar de moneda está en RF-19.

### RF-15. Sincronización del teléfono con la nube

- **Prioridad:** Must.
- **Descripción:** El sistema debe, al abrir la app con sesión, traer lo que falta en el teléfono y enviar lo que todavía no está en la nube.
- **Criterio de aceptación:** Un pedido o producto guardado en Supabase aparece al reabrir la app del mismo negocio. Lo creado en el teléfono se publica si hay sesión.
- **Estado:** Hecho.
- **Avance:** 85 %.

### RF-16. Aislamiento de los pedidos por negocio

- **Prioridad:** Must.
- **Descripción:** El sistema debe mostrar y sincronizar solo los pedidos, productos y clientes del negocio con el que se entró. Cambiar de negocio no debe copiar los pedidos del anterior.
- **Criterio de aceptación:** Burguershop no lista los pedidos de Novaceltec. Al entrar a un negocio distinto, el teléfono vacía la base local anterior y baja la de ese negocio.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Evidencia:** En la base se borraron las copias. Burguershop conserva solo a Kevin Cajal. Novaceltec conserva a María Gómez, Lucas Pérez, Jesús Cajal y Alex. El APK que evita la copia está generado; falta instalarlo en el celular que todavía tiene la base vieja.

### RF-17. Capital, deudas y resumen de ventas

- **Prioridad:** Should.
- **Descripción:** El sistema debe registrar movimientos de capital, saldos a cobrar y a pagar, y un resumen de ventas filtrable por origen.
- **Criterio de aceptación:** Un cobro o una deuda queda asociado a la persona. El resumen distingue una venta del mostrador de un pedido de la página.
- **Estado:** Hecho.
- **Avance:** 80 %.

### RF-18. Consentimiento del visitante

- **Prioridad:** Must.
- **Descripción:** La página debe pedir aceptación del uso de los datos antes de enviar el pedido, y debe pedir el nombre del comprador.
- **Criterio de aceptación:** Sin aceptación no se envía el pedido. Sin nombre, el servidor rechaza el alta.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RF-19. Conversión de moneda

- **Prioridad:** Could.
- **Descripción:** El sistema debe convertir los precios cuando el negocio cambia de moneda, sin pisar a mano cada producto.
- **Criterio de aceptación:** Al cambiar la moneda, los precios de venta quedan expresados en la moneda nueva con el factor usado en ese momento.
- **Estado:** Parcial.
- **Avance:** 60 %.
- **Nota:** Al cambiar de moneda en País y moneda, la app muestra la tasa y pide confirmar. `ConvertirMoneda.aplicar` convierte costos, precios de venta, variantes, pedidos, deudas y capital en el teléfono y después los copia a Supabase. No se recorrió con la cotización del día ni en un teléfono.

### RF-20. Stock del pedido web

- **Prioridad:** Should.
- **Descripción:** El sistema debe impedir vender de más en la página y descontar el stock cuando el pedido web queda registrado, igual que en el mostrador.
- **Criterio de aceptación:** No se puede pedir más que el stock actual. Después del pedido, el stock público baja en esa cantidad una sola vez.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** La migración 0030 está aplicada. `crear_pedido_tienda` bloquea las filas de stock, rechaza si no alcanza, descuenta (primero Yo, después Nildo) y deja la salida «Salida por pedido web». Un pedido de prueba en la base descontó una unidad y se revirtió. En el teléfono, confirmar el pedido no vuelve a restar y cancelarlo repone. `test/stock_pedido_web_test.dart` pasa. No se recorrió con la app nueva ni con la web publicada.

### RF-21. Comprobante del visitante

- **Prioridad:** Could.
- **Descripción:** El sistema debe guardar en la nube el comprobante que adjunta el comprador de la página, no solo en el teléfono del negocio.
- **Criterio de aceptación:** La imagen queda en un depósito con acceso del negocio y se puede abrir desde el pedido en otro teléfono.
- **Estado:** Parcial.
- **Avance:** 65 %.
- **Nota:** La migración 0031 está aplicada y el depósito `comprobantes` es privado. Un anónimo solo puede subir la ruta de un pedido web reciente. Al sincronizar, la app baja la imagen y el pedido la abre. No se probó desde la página publicada ni en otro teléfono.

### RF-22. Variante en la página pública

- **Prioridad:** Should.
- **Descripción:** El visitante debe poder elegir una variante publicada, con su precio y su stock, antes de pedir.
- **Criterio de aceptación:** La página remota muestra las variantes y el pedido guarda cuál se eligió.
- **Estado:** Parcial.
- **Avance:** 70 %.
- **Nota:** La migración 0031 está aplicada y `productos_pedido.variante_id` existe. La página muestra las variantes con precio y stock y manda la elegida. El servidor usa su precio y baja su stock. Al sincronizar, el teléfono anota la variante en el pedido. La web publicada todavía no tiene esta versión.

### RF-23. Aviso nativo de un pedido web

- **Prioridad:** Must.
- **Descripción:** El sistema debe avisar en el teléfono del comerciante, con una notificación del sistema, cuando un visitante deja un pedido en la página.
- **Criterio de aceptación:** Con la app cerrada o en segundo plano, el teléfono muestra un aviso del pedido nuevo de esa tienda. Abrirlo lleva al pedido. Un negocio no recibe el aviso de otro.
- **Estado:** Parcial.
- **Avance:** 60 %.
- **Nota:** El aviso usa `flutter_local_notifications` y un sondeo cada 8 segundos, filtrado por el negocio de la sesión, mientras la app está abierta o el proceso sigue en segundo plano. Si cierran la app del todo no hay Firebase y el aviso no sale. No se probó en un teléfono.

### RF-24. Asistente con clave en el servidor

- **Prioridad:** Must.
- **Descripción:** El sistema debe dejar usar el asistente a los usuarios del negocio con una clave guardada en el servidor. Esa clave no debe viajar al teléfono ni quedar en el repositorio. El teléfono no guarda claves de OpenAI.
- **Criterio de aceptación:** Un teléfono puede consultar el asistente y recibe respuesta sin tener una clave propia. La clave no aparece en el cliente, en las preferencias ni en el repositorio.
- **Estado:** Parcial.
- **Avance:** 60 %.
- **Nota:** `asistente-interpretar` y `asistente-imagen` están desplegadas con `verify_jwt`. Usan la clave activa del panel (RF-30) y, si no hay ninguna, el secreto `OPENAI_API_KEY`. En la base no hay ninguna clave cargada y la fuente activa es «ninguna». No se verificó si el secreto está cargado: sin él, la función responde que el asistente no está configurado. La app ya no tiene la llave del chat ni el almacén local de claves. No se probó en un teléfono.

### RF-25. Memoria del asistente por negocio

- **Prioridad:** Should.
- **Descripción:** El sistema debe guardar los mensajes del asistente y un contexto o resumen de cada negocio, y volver a usarlos en la consulta siguiente del mismo negocio.
- **Criterio de aceptación:** Al cerrar y reabrir el chat, los mensajes anteriores siguen. Otro teléfono del mismo negocio ve ese historial y el resumen. Un negocio no lee la memoria de otro.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** `asistente_mensajes` y `asistente_contexto` están aplicadas. Al abrir, la app recarga hasta 40 mensajes de ese negocio y la consulta siguiente manda el resumen, de hasta 500 caracteres. No se recorrió en un teléfono ni en otro aparato del mismo negocio.

### RF-26. Cupo de chats y tokens consumidos

- **Prioridad:** Must.
- **Descripción:** El sistema debe limitar la cantidad de chats del asistente de cada negocio y registrar los tokens que consume cada consulta.
- **Criterio de aceptación:** Al llegar al cupo, el asistente avisa y no llama al modelo. Cada consulta que sí llama deja anotados los tokens de entrada y de salida, asociados al negocio. El cupo que se muestra coincide con lo registrado.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** `asistente_uso` y `asistente_cupo` están aplicadas. Cada negocio arranca con 30 chats. `reservar_chat_asistente` descuenta uno al usar el modelo y, en cero, el asistente avisa y no consulta. Desde la migración 0029 cada fila también guarda el origen (asistente, foto o página) y el modelo. Hay 3 consultas registradas, todas de Burguershop y anteriores a ese cambio. No se probó el corte del cupo en el teléfono.

### RF-27. Dato de cobro y comprobante en la página

- **Prioridad:** Should.
- **Descripción:** El sistema debe mostrar en la página un dato de cobro del negocio —CBU, CVU o alias— para que el visitante lo copie, y debe dejarle adjuntar el comprobante de la transferencia al pedido.
- **Criterio de aceptación:** La página publicada muestra el dato y lo copia al portapapeles. El pedido queda con la imagen del comprobante y el comerciante la abre desde la app. Sin dato cargado, la página no inventa uno.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** La configuración guarda CBU, CVU o alias en `negocios.alias_cobro` y el diálogo del pedido muestra Copiar si hay dato. El comprobante nuevo va al depósito privado de RF-21. No se probó en la página publicada.

### RF-28. Panel del desarrollador

- **Prioridad:** Should.
- **Descripción:** El sistema debe ofrecer un panel visible solo para el desarrollador, con las tiendas activas, los usuarios de la app, los tokens consumidos y los chats disponibles.
- **Criterio de aceptación:** El desarrollador ve esas cuatro cuentas. Un dueño o un empleado no entra al panel ni ve los números de otro negocio.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** El panel es una página aparte de la app (`dev/panel`), que se abre con `dart run dev/panel/servir.dart` en `http://localhost:3000` e ingresa con Google. Además de los cuatro números muestra un mapa con una tiendita por negocio, los tokens y chats de cada uno, el consumo de la clave por llamada (negocio, origen, modelo y tokens, sin frases), la ciudad desde donde se usa la app y la configuración de IA (RF-30). La pantalla vieja dentro de la app quedó en el código pero ya no se abre desde Más. No se abrió con una cuenta que no sea del desarrollador.

### RF-29. Ubicación del negocio

- **Prioridad:** Should.
- **Descripción:** El sistema debe dejar buscar la dirección del local, guardarla con sus coordenadas y ofrecer en la página un enlace «Cómo llegar».
- **Criterio de aceptación:** Al elegir un lugar quedan la dirección, con la numeración si se cargó, y la latitud y longitud en `negocios`. «Cómo llegar» abre Google Maps en esas coordenadas. Editar la dirección a mano borra las coordenadas viejas.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** La búsqueda usa Nominatim (OpenStreetMap), sin clave de Google. Hay un campo Numeración: al cargarlo se vuelve a buscar ese punto y se guarda. La vista `tienda_publica` incluye `latitud` y `longitud` (0033). «Cómo llegar» abre `google.com/maps/dir` con el destino en esas coordenadas. Si no hay punto, usa el texto de la dirección. Ningún negocio tiene coordenadas guardadas todavía. El teléfono y la web publicada necesitan la versión nueva.

### RF-30. Configuración de IA en el panel

- **Prioridad:** Should.
- **Descripción:** El sistema debe dejar al desarrollador agregar y eliminar claves de API, elegir cuál está activa, y cargar, editar o quitar un modelo local compatible con OpenAI. Solo una fuente puede estar activa.
- **Criterio de aceptación:** Desde el panel se guarda una clave y después solo se ve su nombre y los últimos 4 caracteres. Al activar un modelo local, el asistente del teléfono llama a esa dirección. Sin fuente activa, el asistente usa el secreto del servidor.
- **Estado:** Parcial.
- **Avance:** 60 %.
- **Nota:** La migración 0032 está aplicada (`ia_claves` e `ia_config`, con RLS y sin políticas). El panel solo usa las RPC `ia_panel_*`, que responden a los cuatro correos del desarrollador. La app solo recibe la dirección, el modelo y la clave opcional del modelo local cuando esa es la fuente activa. No hay claves cargadas y no se probó un modelo local. En el teléfono, `127.0.0.1` es el propio aparato y Android puede bloquear direcciones `http://`.

### RF-31. Orquestador del asistente

- **Prioridad:** Must.
- **Descripción:** El sistema debe responder con los datos del teléfono lo que no necesita al modelo, y para el resto pedirle al modelo un plan de acciones. El modelo no debe escribir en la base: el plan se guarda recién cuando el comerciante lo confirma.
- **Criterio de aceptación:** Una consulta de stock, ventas, deudas, pedidos, capital, horario o dirección se responde sin gastar un chat. Una frase como «entraron 5 iPhone 11 a 100» devuelve un plan que no guarda nada hasta tocar Confirmar. Si un producto no se identifica con certeza, el asistente pregunta solo esa parte.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** `OrquestadorIa` resuelve las consultas locales. `OrquestadorAsistente` arma el plan JSON (crear producto, entrada de stock, venta) y solo lo aplica al confirmar. `test/asistente_test.dart` pasa. No se recorrió en un teléfono.

### RF-32. Funciones del asistente configurables

- **Prioridad:** Should.
- **Descripción:** El sistema debe dejar al comerciante prender o apagar las funciones del asistente desde la configuración de la página: consultar stock, anotar una venta, decir horario y dirección, y resumir las ventas de hoy.
- **Criterio de aceptación:** Una función apagada no se ofrece ni se ejecuta. El cambio queda en `negocios.apariencia` y se recupera en otro teléfono. Un negocio sin esa configuración las tiene prendidas.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** Están en Tu página, sección Asistente, y viajan en `apariencia.funcionesAsistente`. Con «anotar venta» apagada, la app descarta la venta aunque el modelo la devuelva. No se recorrió en un teléfono.

### RF-33. Cuenta del cliente al pedir

- **Prioridad:** Should.
- **Descripción:** Al confirmar el pedido en la página, el sistema debe ofrecer crear una cuenta, ingresar o pedir sin cuenta. Recién después debe pedir el nombre y el WhatsApp.
- **Criterio de aceptación:** Pedir sin cuenta no exige correo ni contraseña. Crear cuenta e ingresar usan Supabase Auth. Con sesión, el nombre viene cargado pero se confirma antes de enviar. Cancelar ese paso no envía el pedido.
- **Estado:** Parcial.
- **Avance:** 65 %.
- **Nota:** Está en `lib/widgets/cuenta_pedido_tienda.dart` y en la tienda pública. Sin Supabase, la cuenta queda en ese dispositivo. La contraseña no viaja con el pedido. La web publicada todavía no tiene esta versión.

### RF-34. Correo de bienvenida

- **Prioridad:** Could.
- **Descripción:** El sistema debe enviar un correo con el logo de Gexi cuando alguien crea una cuenta con correo y contraseña.
- **Criterio de aceptación:** Al crear la cuenta llega un correo con el logo, que confirma la cuenta y explica cómo entrar a la app y a la tienda. No incluye contraseñas ni claves.
- **Estado:** Parcial.
- **Avance:** 40 %.
- **Nota:** La plantilla está en `supabase/templates/bienvenida.html` y usa el logo de `https://gexi.com.ar/icons/Icon-512.png`. No está aplicada en Supabase: hay que pegarla en Authentication → Emails → Templates → Confirm signup, con Confirm email encendido. El alta con Google no manda este correo.

### RF-35. Foto de catálogo generada con IA

- **Prioridad:** Could.
- **Descripción:** El sistema debe dejar generar una foto de catálogo para un producto cuando no hay una imagen propia.
- **Criterio de aceptación:** Desde la ficha se pide una foto y queda guardada como foto del producto. Si el servicio no puede generarla, la app lo dice y deja subir una imagen.
- **Estado:** Parcial.
- **Avance:** 55 %.
- **Nota:** Sin modelo local, la foto sale de `asistente-imagen` (`gpt-image-2.5-flare` y, si falla, `gpt-image-1-mini`) y deja el consumo con origen foto. Con modelo local, intenta una vez `/images/generations` en esa dirección. Depende de una clave en el panel o del secreto del servidor. No se probó en un teléfono.

## 2. Requerimientos no funcionales

### RNF-01. Control de acceso

- **Prioridad:** Must.
- **Descripción:** El sistema debe impedir que un visitante anónimo inserte pedidos, productos o fotos por su cuenta. El alta pública debe pasar por una función que valida la tienda, el producto y el stock.
- **Criterio de aceptación:** El rol anónimo no tiene `INSERT` directo sobre `pedidos`. Puede ejecutar `crear_pedido_tienda`. Un miembro solo escribe en el depósito de su negocio.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RNF-02. Integridad del precio

- **Prioridad:** Must.
- **Descripción:** El sistema debe calcular el total del pedido web con el precio guardado en el servidor, no con el precio que manda el navegador.
- **Criterio de aceptación:** Alterar el precio en el pedido del visitante no cambia el total guardado.
- **Estado:** Hecho.
- **Avance:** 100 %.
- **Nota:** Con variante, el servidor usa el precio de la variante guardada.

### RNF-03. Unicidad de la dirección

- **Prioridad:** Must.
- **Descripción:** El sistema debe rechazar una dirección de tienda ya usada por otro negocio, sin distinguir mayúsculas.
- **Criterio de aceptación:** El índice único y la función `slug_de_otro` impiden el duplicado. La app propone el nombre más el código.
- **Estado:** Hecho.
- **Avance:** 100 %.

### RNF-04. Aislamiento entre negocios

- **Prioridad:** Must.
- **Descripción:** El sistema debe tratar a cada negocio como un inquilino distinto: sus pedidos, productos y archivos no se mezclan con los de otro, ni en la nube ni en el teléfono después de cambiar de cuenta.
- **Criterio de aceptación:** Una consulta de pedidos de Burguershop no devuelve filas de Novaceltec. Al cambiar el código del negocio, el teléfono no reenvía la base anterior.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** La nube ya quedó separada. El teléfono queda separado al instalar el APK nuevo y abrirlo.

### RNF-05. Disponibilidad de la página

- **Prioridad:** Should.
- **Descripción:** El sistema debe servir la app y las tiendas por HTTPS en `gexi.com.ar`, con la página de cada negocio en una ruta del mismo dominio.
- **Criterio de aceptación:** `https://gexi.com.ar/` responde la app y `https://gexi.com.ar/{direccion}` abre esa tienda si está publicada.
- **Estado:** Parcial.
- **Avance:** 70 %.
- **Nota:** El dominio está activo en Cloudflare Pages. Cada cambio de la app web hay que subirlo de nuevo, con el contenido de `build\web` en la raíz del deploy. El deploy actual sirve la carpeta fuente y la página queda en blanco.

### RNF-06. Usabilidad del ingreso

- **Prioridad:** Should.
- **Descripción:** El sistema debe mostrar el ingreso en una pantalla, con el logo contenido, el botón de Google reconocible y sin un texto de descripción que empuje el formulario fuera de la vista.
- **Criterio de aceptación:** En un teléfono común se ven el logo, el formulario, Continuar, Google y Crear cuenta sin desplazarse para encontrar el alta.
- **Estado:** Parcial.
- **Avance:** 70 %.
- **Nota:** El diseño está en el código. La comprobación visual del emulador se cortó y el sitio publicado puede seguir con una versión anterior.

### RNF-07. Límite de las imágenes

- **Prioridad:** Must.
- **Descripción:** El sistema debe limitar el tamaño y el tipo de las fotos para que el teléfono y el depósito no guarden archivos arbitrarios.
- **Criterio de aceptación:** El depósito acepta jpeg, png y webp de hasta 5 MB. La app reduce la foto antes de subirla.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RNF-08. Uso del teléfono sin red

- **Prioridad:** Must.
- **Descripción:** El sistema debe permitir vender y consultar el catálogo local si Supabase no responde, y sincronizar cuando la sesión vuelva.
- **Criterio de aceptación:** Un fallo de red no borra los pedidos locales ni impide crear uno nuevo en el teléfono.
- **Estado:** Hecho.
- **Avance:** 85 %.

### RNF-09. Protección de secretos

- **Prioridad:** Must.
- **Descripción:** El sistema debe tomar la URL y la clave anónima de Supabase desde la compilación, y no debe guardar claves de servicio ni el secreto de Google en el repositorio.
- **Criterio de aceptación:** El cliente usa solo `SUPABASE_URL` y `SUPABASE_ANON_KEY`. `dart_defines.json` no se versiona.
- **Estado:** Hecho.
- **Avance:** 100 %.

### RNF-10. Idioma de la interfaz

- **Prioridad:** Must.
- **Descripción:** El sistema debe mostrar las pantallas, los errores de la página y los rechazos del servidor en español.
- **Criterio de aceptación:** Un nombre vacío, una tienda apagada o la falta de stock devuelven un texto en español, no el error crudo de la base.
- **Estado:** Hecho.
- **Avance:** 90 %.

### RNF-11. Claves de IA fuera del teléfono

- **Prioridad:** Must.
- **Descripción:** El sistema debe custodiar las claves de OpenAI en el servidor. No debe enviarlas al teléfono, escribirlas en el repositorio ni dejarlas en el cliente compilado.
- **Criterio de aceptación:** El tráfico del teléfono hacia Supabase no contiene una clave de OpenAI. El repositorio no la tiene. Un comerciante autenticado no puede leer `ia_claves` ni `ia_config` con un `select`.
- **Estado:** Parcial.
- **Avance:** 65 %.
- **Nota:** Las claves del panel están en `ia_claves`, con RLS y sin políticas, y solo las leen las funciones de borde. El secreto `OPENAI_API_KEY` se lee del entorno y no se devuelve. La única configuración que recibe el teléfono es la del modelo local activo. No se comprobó el tráfico de un teléfono.

### RNF-12. Cupo aplicado en el servidor

- **Prioridad:** Must.
- **Descripción:** El sistema debe contar el cupo y los tokens en el servidor, por negocio. Borrar los datos del teléfono no debe devolver chats ni mezclar el consumo de dos negocios.
- **Criterio de aceptación:** Dos consultas simultáneas no dejan el cupo negativo. Reinstalar la app no reinicia el cupo. El registro de un negocio no suma tokens de otro.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** El descuento corre en el servidor y un update no puede subir el número. Reinstalar la app no recrea los 30 chats. El registro va por negocio. No se probaron dos consultas al mismo tiempo.

### RNF-13. Comprobante visible solo para el negocio

- **Prioridad:** Must.
- **Descripción:** El sistema debe guardar el comprobante del visitante de modo que solo el negocio de ese pedido pueda abrirlo. La página pública no debe listar comprobantes.
- **Criterio de aceptación:** Un anónimo no lee la imagen. Un miembro de otro negocio tampoco. El visitante adjunta el suyo y no ve los anteriores.
- **Estado:** Parcial.
- **Avance:** 75 %.
- **Nota:** Los comprobantes nuevos van al depósito privado `comprobantes`. Un anónimo solo sube la ruta de un pedido web reciente y no puede leer. Un miembro de otro negocio tampoco. Los comprobantes viejos siguen en el bucket público `productos`, y la función todavía acepta esa dirección para que el sitio anterior no deje de registrar el comprobante.

### RNF-14. Panel solo del desarrollador

- **Prioridad:** Must.
- **Descripción:** El sistema debe impedir que un dueño, un empleado o un visitante abra el panel del desarrollador o lea el listado de tiendas, usuarios, tokens, chats y claves de IA.
- **Criterio de aceptación:** Sin la cuenta del desarrollador, la consulta de ese listado se rechaza. Con esa cuenta, se ve el conjunto. No alcanza con conocer la URL.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** Las funciones del panel (`resumen_desarrollador`, `mapa_desarrollador`, `tokens_desarrollador`, `consumo_desarrollador` e `ia_panel_*`) solo responden a `jesus.cajal.work@gmail.com`, `jesuscajal49@gmail.com`, `piloto@novaceltec.local` y `leocajald@gmail.com`. No se comprobó con una cuenta de dueño o de empleado.

### RNF-15. Consumo sin conversaciones

- **Prioridad:** Should.
- **Descripción:** El sistema debe mostrar al desarrollador lo que consume cada llamada a la IA sin mostrarle lo que escribieron los comerciantes.
- **Criterio de aceptación:** El listado de consumo muestra negocio, origen, modelo, tokens y hora. No muestra frases, respuestas ni correos.
- **Estado:** Parcial.
- **Avance:** 80 %.
- **Nota:** `consumo_desarrollador` (0029) devuelve solo esas columnas y el panel ya no tiene la sección de conversaciones. Las llamadas hechas con la misma clave fuera de Gexi no se ven.

### RNF-16. Ubicación de uso sin datos precisos

- **Prioridad:** Should.
- **Descripción:** El sistema debe registrar desde qué ciudad se usa la app sin pedir el GPS ni guardar la IP.
- **Criterio de aceptación:** `accesos_app` guarda ciudad y país, a lo sumo una vez cada 12 horas por aparato. No hay columna de IP.
- **Estado:** Parcial.
- **Avance:** 70 %.
- **Nota:** La app consulta `ipwho.is` y llama a `registrar_acceso`. Hay un acceso registrado. No se comprobó en un teléfono.

## 3. Cómo se leyó el avance

El 79 % es el promedio simple de los 51 ítems. No pondera por prioridad: un Must pendiente pesa igual que un Could pendiente en esa cuenta.

Ningún requerimiento quedó Pendiente: todos tienen el comportamiento en el código y, cuando hace falta, la migración aplicada. Los 31 Parcial esperan una comprobación en el teléfono o en el sitio publicado, o una configuración de fuera del código.

Para cerrarlos frente a un usuario falta:

- Subir el contenido de `build\web` a Cloudflare Pages.
- Instalar el APK nuevo en los teléfonos de Burguershop y Novaceltec.
- Cargar una clave en el panel o el secreto `OPENAI_API_KEY`.
- Pegar la plantilla del correo de bienvenida en Supabase Auth.
- Guardar la ubicación y las categorías de los negocios.
- Configurar Firebase, para el aviso con la app cerrada.

# Backend Supabase de Gexi

Esquema y políticas RLS. Se pega una vez en un proyecto vacío. La app usa la clave anónima; no pongas `service_role` en el cliente.

## Pegar el SQL

1. Abrí el proyecto en el dashboard de Supabase.
2. Entrá a **SQL Editor** y creá una query nueva.
3. Copiá todo `supabase/migrations/0001_gexi.sql`, pegalo y ejecutalo.
4. Si termina sin errores, las once tablas quedan en `public` con RLS activa.

No lo vuelvas a correr si esas tablas ya existen: el script está pensado para una base vacía.

## Variables

Configuralas en el cliente, sin subirlas al repositorio y sin inventar valores:

- `SUPABASE_URL`: **Project Settings → API → Project URL** (`https://<ref>.supabase.co`).
- `SUPABASE_ANON_KEY`: la clave **anon public** de esa misma pantalla.

El login tiene que dejar el email en el JWT (`auth.jwt() ->> 'email'`). Con eso, un usuario autenticado crea su negocio como dueño y solo lee y escribe filas de los negocios donde ese email es dueño o miembro.

## Tienda pública
Después de aplicar `0001_gexi.sql`, ejecutá `supabase/migrations/0002_tienda_publica.sql` en el SQL Editor.
La migración agrega la configuración de tienda y vistas de solo lectura para `anon`, sin abrir las tablas base.
Configurá el DNS comodín `*.gexi-novaceltec.com` y el apex `gexi-novaceltec.com` hacia el mismo hosting de Flutter web.
Configurá también `www.gexi-novaceltec.com` hacia ese hosting.
La app decide por el host: un subdominio válido muestra su tienda; el apex y `www` muestran Gexi.

## Esquema amplio

Después de `0002_tienda_publica.sql`, ejecutá `supabase/migrations/0003_requerimientos.sql`.
Agrega lo que el prototipo local todavía no guarda, sin borrar las tablas de `0001`:

- Perfil, código de empleado, tope de cinco personas y datos fiscales del negocio.
- Categorías, atributos, variantes, número de serie y visibilidad en la tienda.
- Pedido con cliente, origen, autor, medio de pago y precio de línea ya guardado.
- Comprobante con imagen, deuda vinculada y movimientos con medio de pago.
- Conversaciones del asistente y tope del cupo.
- Auditoría de cambios, de solo lectura para la app.

La app de este prototipo sigue leyendo la base local. Estas tablas quedan listas para cuando se conecte Supabase.

## Fotos y varias categorías

Después de `0004_tienda_descripcion.sql`, ejecutá `supabase/migrations/0005_fotos_categorias.sql`.

- Un producto puede estar en varias categorías (`productos_categorias`).
- Puede tener varias fotos, y cada variante las suyas (`fotos_producto`).
- Los archivos van al bucket público `productos`. La vidriera lee las URLs por las vistas, sin abrir las tablas.
- `categoria_id` e `imagen_url` siguen existiendo: guardan la primera categoría y la primera foto general.

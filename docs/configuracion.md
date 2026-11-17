# Configuración de Gexi

Guía para armar el proyecto desde cero. Lo que dice acá sale del repositorio (código, migraciones y `docs/requerimientos.md`). Lo que solo se hace en un dashboard queda marcado: hay que confirmarlo ahí. No pegues en el repo `dart_defines.json`, la clave `service_role`, el client secret de Google ni `OPENAI_API_KEY`.

Gexi es la app de gestión para un comercio chico (pedidos, stock, caja, página pública) más la tienda en `https://gexi.com.ar/{slug}`. El paquete Flutter se llama `gestion_pedidos`. El README de la raíz sigue describiendo un sistema de limpieza: no lo uses como guía de este producto.

## 1. Compilar

Flutter stable. En esta máquina el SDK está en `C:\Users\leoca\flutter`.

En PowerShell no uses `&&`. Un comando por línea.

Dependencias:

```powershell
flutter pub get
```

Web (el sitio público sale de este build):

```powershell
flutter build web --dart-define-from-file=dart_defines.json
```

APK. El JDK que se usó es el 21 de Microsoft. `JAVA_HOME` tiene que existir antes del build:

```powershell
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.13.21-hotspot"
flutter build apk --dart-define-from-file=dart_defines.json
```

Sin esas dos claves de Supabase la app arranca igual, pero queda solo en la base local del teléfono (`lib/backend/supabase_cliente.dart`).

`applicationId` de Android: `com.example.gestion_pedidos` (`android/app/build.gradle.kts`). El NDK que recomienda el README viejo es `27.0.12077973`; el Gradle actual usa `flutter.ndkVersion`, no un número fijo.

## 2. `dart_defines.json`

Está en `.gitignore`. Va en la raíz del repo. No se versiona.

El código Dart solo lee dos claves con `String.fromEnvironment`:

| Clave | Dónde se consigue |
| --- | --- |
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL (`https://<ref>.supabase.co`) |
| `SUPABASE_ANON_KEY` | La misma pantalla, clave **anon public** |

El Client ID de Google no va en este archivo. Está fijo en el repo (sección 5). El panel local (`dev/panel/servir.dart`) lee las mismas dos claves del JSON y las mete solo en la respuesta HTTP.

Ejemplo, sin valores reales:

```json
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon public>"
}
```

La URL concreta del proyecto no está escrita en el código ni en `docs/`. Hay que confirmarla en el dashboard. No uses `service_role` en el cliente.

## 3. Supabase

Proyecto de Postgres con Auth. El cliente usa la clave anónima. `service_role` saltea RLS: no va en la app. Las funciones de borde sí la leen del entorno que inyecta Supabase.

La CLI de Supabase no está instalada en esta máquina. Las migraciones se pegan a mano.

### Orden

SQL Editor → New query → pegar el archivo entero → Run. En una base vacía, en este orden. No hay `0017`. No vuelvas a correr `0001_gexi.sql` si las tablas ya existen: está pensado para una base vacía.

| Archivo | Qué agrega |
| --- | --- |
| `0001_gexi.sql` | Negocio, miembros, clientes, productos, stock, pedidos y RLS. El dueño es el email del JWT. |
| `0002_tienda_publica.sql` | Slug, tienda activa, WhatsApp y mensaje público. Vistas de solo lectura para `anon`. |
| `0003_requerimientos.sql` | Perfil, equipo (tope de cinco), ficha fiscal, categorías, variantes, series, pedido con origen y autor, comprobante, deudas, chats del asistente, auditoría de solo lectura. |
| `0004_tienda_descripcion.sql` | Descripción en la vidriera. No abre las tablas base a `anon`. |
| `0005_fotos_categorias.sql` | Varias categorías y varias fotos. Bucket público `productos`. |
| `0006_negocio_moneda.sql` | Moneda del negocio. Los ya guardados quedan en USD. |
| `0007_pais_moneda_latam.sql` | País, nacionalidad y monedas de América Latina. |
| `0008_pedidos_categoria.sql` | Categoría del pedido: manual o página web. |
| `0009_tienda_moneda.sql` | La página pública muestra la moneda. |
| `0010_apariencia_tienda.sql` | Diseño de la vidriera en el negocio. |
| `0011_unirse_codigo.sql` | El empleado reclama el código y queda como miembro. |
| `0012_slug_unico.sql` | Dice si otro negocio ya usa esa dirección, sin decir de quién es. |
| `0013_pedido_tienda.sql` | Pedido del visitante sin sesión. Precio y stock salen de la base. |
| `0014_logo_tienda.sql` | Logo en la página pública. |
| `0015_alias_cobro.sql` | Alias, CBU o CVU, y la ruta del comprobante del visitante. |
| `0016_asistente_chats.sql` | Chat, contexto, consumo y cupo por negocio. El alta arranca en 30 chats. `anon` no entra. |
| `0018_resumen_desarrollador.sql` | Resumen del panel. Si falta 0016, el conteo del asistente queda en cero. |
| `0019_redes_ubicacion.sql` | Facebook, Instagram y ubicación. |
| `0020_horario_tienda.sql` | Horario en la página, solo si está cargado. |
| `0021_pedidos_realtime.sql` | `REPLICA IDENTITY FULL` para filtrar INSERT de pedidos por negocio. |
| `0022_chats_desarrollador.sql` | Últimas conversaciones, solo la lista de correos del desarrollador. |
| `0023_diseno_tienda.sql` | Historial del layout dentro de `apariencia`. |
| `0024_rubro_tienda.sql` | Rubro público para elegir la plantilla. |
| `0025_accesos_app.sql` | Ciudad y país de uso. Sin IP ni GPS. |
| `0026_mapa_tiendas.sql` | Coordenadas del local. El mapa del panel es solo del desarrollador. |
| `0027_tokens_por_tienda.sql` | Tokens por negocio, sin correos ni texto del chat. |
| `0028_mapa_direccion.sql` | Dirección escrita para locales sin coordenadas. |
| `0029_consumo_api.sql` | Cada llamada: origen, modelo y tokens. Sin la frase. |
| `0030_stock_pedido_web.sql` | El pedido web descuenta stock una sola vez. |
| `0031_variante_publica_comprobante.sql` | Variante publicada. Comprobante nuevo en el bucket privado `comprobantes`. |
| `0032_configuracion_ia.sql` | Claves de IA. RLS sin políticas para el cliente. Solo las leen las funciones de borde. |
| `0033_tienda_publica_coordenadas.sql` | El punto del local en la vista pública, para Google Maps. |
| `0034_visitas_tienda.sql` | Una visita por apertura. Sin identidad ni IP. |
| `0035_visitas_de_mi_pagina.sql` | El teléfono lee visitas por el slug, si es dueño o miembro. |
| `0036_borrar_cuenta.sql` | Borrado de datos. Solo la función de borde, con la clave de servicio. |
| `0037_instructivo_funciones.sql` | Textos que el asistente usa para explicar la app. Versión 1. |
| `0038_instructivo_clientes.sql` | Instructivo versión 2 (clientes). |
| `0039_instructivo_deudores.sql` | Instructivo versión 3 (deudores). |
| `0040_instructivo_categorias.sql` | Instructivo versión 4 (categorías). |
| `0041_instructivo_sin_proveedor.sql` | Se sacó la compra al proveedor y el reparto entre socios. |
| `0042_instructivo_perfil.sql` | El alta pide nombre y apellido; el WhatsApp solo al dueño. |

### RLS

`0001` enciende RLS. Un autenticado crea su negocio y el dueño queda como el email del JWT. Dueño y miembro leen y escriben las filas de ese negocio. `anon` no inserta pedidos ni productos a mano: el alta pública pasa por funciones (`crear_pedido_tienda` y las que siguen). Las vistas públicas no abren las tablas base.

La allowlist del panel está repetida en SQL (`0018`, `0022`, `0025` a `0029`, `0032`) y en `lib/services/desarrollador.dart`. Si cambiás un correo, hay que cambiar los dos lados.

### Funciones de borde

Código en `supabase/functions/`. No hay `config.toml`.

| Función | Uso |
| --- | --- |
| `asistente-interpretar` | Interpreta la frase del comerciante. La app la llama con el JWT. |
| `asistente-imagen` | Foto de catálogo. La app la llama con el JWT. |
| `borrar-cuenta` | Borra imágenes, datos del negocio del dueño y la cuenta. El cuerpo tiene que traer `confirmacion: "BORRAR"`. |

`docs/requerimientos.md` dice que `asistente-interpretar` y `asistente-imagen` ya están desplegadas con `verify_jwt`. Usan la clave activa del panel y, si no hay ninguna, el secreto `OPENAI_API_KEY`. En la base no había ninguna clave cargada y la fuente activa era «ninguna». No se verificó si el secreto está cargado. `borrar-cuenta` está en el repo y la app la invoca; hay que confirmar en el dashboard que sigue desplegada.

Secretos del entorno de la función (los pone Supabase o el dashboard, no el repo): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. `OPENAI_API_KEY` es el respaldo. No se devuelve al teléfono.

### A mano en el dashboard

Esto no sale de un `git push`:

- Crear el proyecto y copiar URL y anon key a `dart_defines.json`.
- Pegar las migraciones si la base está vacía. Si el proyecto de producción ya las tiene, no las repitas.
- Authentication → Providers → Google, activado, con el mismo Client ID de la sección 5. El client secret se carga ahí y no se copia al repo. Hay que confirmar que el proveedor sigue activo.
- Authentication → URL Configuration: Site URL `https://gexi.com.ar`. Redirect URLs: `https://gexi.com.ar` y `http://localhost:3000`.
- Plantilla de correo (sección 4). El repo dice que no está pegada.
- Secreto `OPENAI_API_KEY` en Edge Functions, o una clave cargada desde el panel. Hay que confirmar cuál de las dos está.
- Desplegar las tres funciones si el proyecto es nuevo. Sin CLI, se pegan o se suben desde el dashboard. Hay que confirmar el método que usaron la última vez: no está en el repo.
- Realtime para `public.pedidos`, porque `0021` deja la identidad de réplica y la app escucha INSERT. Hay que confirmar que la tabla está en la publicación de Realtime.
- Buckets: `productos` (público, jpeg/png/webp, hasta 5 MB) lo crea `0005`. `comprobantes` (privado) lo crea `0031`. Si el SQL ya corrió, no hace falta crearlos a mano.

## 4. Correos

No hay un servicio de correo aparte en el código. `smtp` solo aparece como slug reservado, para que nadie publique `gexi.com.ar/smtp`. El alta con correo usa Supabase Auth (`signUp` con `emailRedirectTo: https://gexi.com.ar`). Si el proyecto usa SMTP propio, hay que confirmarlo en el dashboard: el repo no lo configura.

`supabase/templates/bienvenida.html` es el mail de activación (plantilla **Confirm signup**), no un newsletter.

- Asunto sugerido: `Activá tu cuenta de Gexi`.
- El botón y el enlace de texto usan `{{ .ConfirmationURL }}`. No los borres.
- El logo apunta a `https://gexi.com.ar/icons/Icon-512.png`.

En el dashboard, a mano (la CLI no está instalada y la plantilla no se aplica sola):

1. Authentication → Sign In / Providers → Email: **Confirm email** encendido.
2. Authentication → Emails → Templates → **Confirm signup**: pegar el HTML del archivo.
3. Site URL `https://gexi.com.ar`. Redirect permitido `https://gexi.com.ar`.

`docs/requerimientos.md` (RF-34) dice que la plantilla no está aplicada. No des por hecho que ya está pegada: abrí el template y comparalo.

Google no manda este correo. Con Confirm email apagado, `signUp` puede devolver sesión al instante y el usuario entra sin el mail. Con Confirm email encendido, la app no abre hasta que el correo está confirmado y, si falta, reenvía el mail (`lib/backend/sesion_remota.dart`).

## 5. Google

Inicio de sesión con el paquete `google_sign_in`. El Client ID web es público y ya está en el repo:

`1067483603691-m3ntv4uq5n3innuoa3mb502urva2e2o6.apps.googleusercontent.com`

Está en `web/index.html` (meta `google-signin-client_id`) y en `lib/services/google_ids.dart`. En Android ese mismo id se usa como `serverClientId` para que Google entregue el id token. No hay client secret en el repo. No lo agregues.

La app no usa el redirect de OAuth para entrar. Pide el id token y llama `signInWithIdToken` con proveedor `google`. Si Supabase responde que el proveedor está apagado o que el Client ID no coincide, el texto de la app lo dice en español.

El panel sí usa OAuth: `dev/panel/panel.js` llama `signInWithOAuth` con `redirectTo: http://localhost:3000`.

En Google Cloud, cliente OAuth de tipo Web con ese Client ID:

- Orígenes JavaScript que el código nombra: `https://gexi.com.ar` y `http://localhost:3000`. `servir.dart` dice que `http://localhost:3000` es el origen que Google ya acepta, y que la página tiene que ser `localhost`, no `127.0.0.1`. `www.gexi.com.ar` también abre la app, no una tienda.
- Si corrés la app web en otro puerto (`flutter run -d chrome`), ese origen tiene que estar autorizado. El repo no lista el puerto. Hay que confirmarlo en la consola.
- Para el OAuth del panel, el redirect autorizado en Google es el callback de Supabase: `https://<ref>.supabase.co/auth/v1/callback`. El `<ref>` es el de Project URL. No está escrito en el repo: hay que confirmarlo en el dashboard.
- En Supabase el redirect de vuelta de la app es `https://gexi.com.ar` y el del panel es `http://localhost:3000` (sección 3).

El client secret se carga solo en Supabase → Google provider. No va en `dart_defines.json` ni en la guía.

## 6. Cloudflare Pages

El sitio público es `https://gexi.com.ar/{slug}`. No es Netlify.

- `https://gexi.com.ar/` y `https://www.gexi.com.ar/` abren el ingreso a la app.
- `https://gexi.com.ar/novaceltec` abre esa tienda. Un solo segmento de ruta, 3 a 30 caracteres, minúsculas, números y guiones. `www`, `app`, `api`, `smtp` y el resto de la lista de `lib/services/subdominio_tienda.dart` están reservados.
- Un subdominio `slug.gexi.com.ar` también abre la tienda. El deploy que se usa es la ruta en el mismo dominio.

Qué se sube: el **contenido** de `build\web` (lo que generó `flutter build web`), en la raíz del proyecto de Pages. No subas la carpeta fuente `web`. `docs/requerimientos.md` anota que un deploy subió `web` y la tienda quedó en blanco.

`web/_redirects` tiene `/* /index.html 200`. Flutter lo copia al build. Sin esa regla, un slug recargado no llega a la app. El dominio ya estaba activo en Cloudflare; el nombre del proyecto de Pages no está en el repo. Hay que confirmarlo en el dashboard de Cloudflare.

Cada cambio de la app web hay que volver a compilar y subir `build\web` de nuevo.

## 7. Emulador Android

No hace falta dejarlo corriendo para publicar ni para compilar.

En las pruebas se usó la imagen `sdk gphone64 x86 64`. El repo no fija el AVD en ningún archivo: hay que confirmar el dispositivo en Android Studio.

```powershell
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.13.21-hotspot"
flutter run --dart-define-from-file=dart_defines.json
```

El splash nativo y los recursos de `android/app/src/main/res` (ícono, `splash_icon`, `launch_background`) no aparecen con hot reload. Hay que parar el proceso y volver a hacer `flutter run`, o reinstalar el APK.

En debug, fuera de la web, `DevicePreview` está activo (`lib/main.dart`). En release no.

El aviso de un pedido web usa notificación local y un sondeo cada 8 segundos mientras el proceso vive. Si Android mata la app, no hay aviso: Firebase no está configurado (`docs/requerimientos.md`, RF-23).

## 8. Panel del desarrollador

Desde la raíz del repo:

```powershell
dart run dev/panel/servir.dart
```

Abre `http://localhost:3000`. Hace falta `dart_defines.json` con las dos claves. Entrá con Google. La allowlist, en código y en SQL:

- `jesus.cajal.work@gmail.com`
- `jesuscajal49@gmail.com`
- `piloto@novaceltec.local`
- `leocajald@gmail.com`

Otra cuenta ve la pantalla de sin acceso. El panel no usa `service_role`. Si el enlace de Google no vuelve, agregá `http://localhost:3000` en Redirect URLs de Supabase.

## 9. Flujo de cuentas

1. Google entra directo, sin el mail de activación.
2. Correo y contraseña: si Confirm email está ON, la app espera el mail de la sección 4 y no abre la sesión hasta que el correo está confirmado. Mínimo 6 caracteres.
3. Sin negocio, la pantalla pregunta «¿Cómo entrás?».
   - Dueño: nombre, apellido y WhatsApp del local (si no empieza con `+` ni con `54`, la app antepone `+54`). Después crea el negocio.
   - Empleado: nombre, apellido y el código que le pasó quien administra. Sin WhatsApp.
4. En una PC, con la ventana de 760 px o más, la gestión va en una columna de 440 px centrada. La tienda pública (`/{slug}`) usa todo el ancho.

## 10. Qué no está hecho

Anotado el 15 de noviembre de 2026 en `docs/requerimientos.md`, sección «Requerimientos futuros». No hay código ni migración. No lo configures como si ya existiera.

- **RF-36.** Bandeja de WhatsApp Business dentro de Gexi. Hoy el número del negocio abre WhatsApp por fuera.
- **RF-37.** Varios empleados en esa misma bandeja.
- **RF-38.** Un agente que contesta al cliente con datos públicos del negocio.
- **RNF-17.** Ese agente no puede leer deudas ajenas, costos, capital ni datos del equipo.

Tampoco está cerrado, y el propio documento lo deja pendiente de un paso de afuera:

- Volver a subir el contenido de `build\web` a Cloudflare Pages.
- Pegar la plantilla de activación en Supabase.
- Cargar una clave de IA en el panel o el secreto `OPENAI_API_KEY`.
- Configurar Firebase si se quiere el aviso con la app cerrada del todo.

## 11. Git

No cambies `git config`. Para commitear en este disco (la ruta tiene espacios):

```powershell
git -c safe.directory="D:/CARRERA LIC EN SISTEMAS/Leo programador/order-management-flutter" -c user.name="martin ramon quintana" -c user.email="martinrquinta97@gmail.com" status
```

Esos `-c` valen solo para ese comando. Identidad de los commits: `martin ramon quintana` / `martinrquinta97@gmail.com`.

No subas `dart_defines.json`, `.env`, `service_role`, el client secret de Google ni claves de OpenAI.

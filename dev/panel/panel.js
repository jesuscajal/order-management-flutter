import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/+esm";

// Misma lista que lib/services/desarrollador.dart y resumen_desarrollador().
const CORREOS = new Set([
  "jesus.cajal.work@gmail.com",
  "jesuscajal49@gmail.com",
  "piloto@novaceltec.local",
  "leocajald@gmail.com",
]);

const REDIRECT = "http://localhost:3000";

const $ = (id) => document.getElementById(id);

function leerConfig() {
  const nodo = $("gexi-panel-config");
  if (!nodo) return null;
  try {
    const datos = JSON.parse(nodo.textContent.trim());
    if (!datos.url || !datos.anonKey) return null;
    return datos;
  } catch {
    return null;
  }
}

function mostrar(id) {
  for (const seccion of ["cargando", "ingreso", "sin-acceso", "resumen"]) {
    $(seccion).hidden = seccion !== id;
  }
}

function miles(valor) {
  return new Intl.NumberFormat("es-AR").format(valor);
}

function entero(valor) {
  const numero = Number(valor);
  return Number.isFinite(numero) ? numero : 0;
}

function filaDe(data) {
  if (Array.isArray(data)) return data[0] ?? null;
  if (data && typeof data === "object") return data;
  return null;
}

function esDesarrollador(email) {
  return CORREOS.has((email || "").trim().toLowerCase());
}

const config = leerConfig();
if (!config) {
  $("cargando").textContent =
    "Falta la configuración. Abrí esta página con el servidor local, no como archivo.";
  throw new Error("config");
}

const supabase = createClient(config.url, config.anonKey, {
  auth: {
    detectSessionInUrl: true,
    persistSession: true,
    flowType: "pkce",
    autoRefreshToken: true,
  },
});

let turno = 0;
let sesionActual = null;
let mapa = null;

const COLORES = ["#1a56f0", "#16c96a", "#f5a524", "#ef5b8a", "#7c5cfc", "#14b8a6", "#f97316"];

function colorDe(nombre) {
  const texto = String(nombre || "");
  let indice = 0;
  for (const letra of texto) indice = (indice + letra.charCodeAt(0)) % COLORES.length;
  return COLORES[indice];
}

function vaciarMapa() {
  if (mapa) {
    mapa.remove();
    mapa = null;
  }
  const aviso = $("aviso-mapa");
  const sinLugar = $("lista-sin-lugar");
  const calle = $("calle");
  if (aviso) aviso.textContent = "";
  if (sinLugar) sinLugar.replaceChildren();
  if (calle) calle.replaceChildren();
}

function coordenada(valor) {
  if (valor == null || valor === "") return null;
  const numero = Number(valor);
  return Number.isFinite(numero) ? numero : null;
}

function esPunto(lat, lng) {
  return (
    lat != null &&
    lng != null &&
    Math.abs(lat) <= 90 &&
    Math.abs(lng) <= 180 &&
    !(lat === 0 && lng === 0)
  );
}

async function ubicarPorDireccion(filas) {
  const ubicadas = [];
  const sin = [];
  for (const fila of filas) {
    const direccion = String(fila.maps_url || "").trim();
    if (direccion.length < 3 || direccion.includes("://")) {
      sin.push(fila);
      continue;
    }
    const clave = `gexi-lugar:${direccion}`;
    let punto = null;
    try {
      const guardado = sessionStorage.getItem(clave);
      if (guardado) punto = JSON.parse(guardado);
    } catch {
      punto = null;
    }
    if (!punto) {
      try {
        const uri = new URL("https://nominatim.openstreetmap.org/search");
        uri.searchParams.set("format", "jsonv2");
        uri.searchParams.set("limit", "1");
        uri.searchParams.set("q", direccion);
        const respuesta = await fetch(uri, { headers: { "Accept-Language": "es" } });
        const lista = respuesta.ok ? await respuesta.json() : [];
        const primero = Array.isArray(lista) ? lista[0] : null;
        const lat = coordenada(primero?.lat);
        const lng = coordenada(primero?.lon);
        const caja = Array.isArray(primero?.boundingbox)
          ? primero.boundingbox.map(Number)
          : null;
        if (esPunto(lat, lng)) {
          punto = { lat, lng, caja };
          sessionStorage.setItem(clave, JSON.stringify(punto));
        }
      } catch {
        punto = null;
      }
    }
    if (punto && esPunto(punto.lat, punto.lng)) {
      ubicadas.push({ ...fila, lat: punto.lat, lng: punto.lng, caja: punto.caja });
    } else {
      sin.push(fila);
    }
  }
  return { ubicadas, sin };
}

function textoHtml(valor) {
  return String(valor ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function caraTienda(logo, nombre) {
  const inicial = (String(nombre || "?").trim().charAt(0) || "?").toUpperCase();
  const direccion = String(logo || "").trim();
  return /^https:\/\//i.test(direccion)
    ? `<img src="${textoHtml(direccion)}" alt="">`
    : `<span>${textoHtml(inicial)}</span>`;
}

function iconoTienda(logo, nombre) {
  const titulo = String(nombre || "Tienda").trim();
  return L.divIcon({
    className: "marca-tienda",
    html: `<div class="pin-local" style="--toldo:${colorDe(titulo)}">
      <div class="toldo"></div>
      <div class="vidriera">${caraTienda(logo, titulo)}</div>
      <div class="rotulo">${textoHtml(titulo)}</div>
    </div>`,
    iconSize: [76, 88],
    iconAnchor: [38, 84],
    popupAnchor: [0, -70],
  });
}

function pintarCalle(filas) {
  const calle = $("calle");
  calle.replaceChildren();
  if (filas.length === 0) {
    calle.textContent = "Todavía no hay microemprendimientos.";
    return;
  }
  for (const fila of filas) {
    const nombre = String(fila.nombre || "Sin nombre").trim();
    const slug = String(fila.slug || "").trim();
    const tarjeta = document.createElement(slug ? "a" : "article");
    tarjeta.className = "tiendita";
    tarjeta.dataset.slug = slug;
    tarjeta.style.setProperty("--toldo", colorDe(nombre));
    if (slug) {
      tarjeta.href = `https://gexi.com.ar/${encodeURIComponent(slug)}`;
      tarjeta.target = "_blank";
      tarjeta.rel = "noopener";
    }
    const toldo = document.createElement("div");
    toldo.className = "toldo";
    const fachada = document.createElement("div");
    fachada.className = "fachada";
    const cartel = document.createElement("p");
    cartel.className = "cartel";
    cartel.textContent = nombre;
    const vidriera = document.createElement("div");
    vidriera.className = "vidriera";
    vidriera.innerHTML = caraTienda(fila.logo_url, nombre);
    const datos = document.createElement("div");
    datos.className = "datos";
    const lugar = document.createElement("span");
    lugar.className = fila.lat != null ? "lugar si" : "lugar no";
    lugar.textContent = fila.lat != null ? "En el mapa" : "Falta el lugar";
    const consumo = document.createElement("span");
    consumo.className = "consumo";
    consumo.textContent = "Cargando tokens…";
    datos.append(lugar, consumo);
    fachada.append(cartel, vidriera, datos);
    tarjeta.append(toldo, fachada);
    calle.append(tarjeta);
  }
}

function anotarConsumo(filas) {
  for (const fila of filas) {
    const slug = String(fila.slug || "").trim();
    const tarjeta = slug
      ? document.querySelector(`#calle [data-slug="${CSS.escape(slug)}"] .consumo`)
      : null;
    if (!tarjeta) continue;
    const total = entero(fila.tokens_entrada) + entero(fila.tokens_salida);
    tarjeta.textContent = `${miles(total)} tokens · ${miles(entero(fila.chats_disponibles))} chats`;
  }
}

async function cargarMapa(miTurno) {
  vaciarMapa();
  const aviso = $("aviso-mapa");
  aviso.textContent = "Cargando el mapa…";
  const { data, error } = await supabase.rpc("mapa_desarrollador");
  if (miTurno !== turno) return;
  if (error) {
    aviso.textContent = "No se pudieron leer las tiendas.";
    return;
  }
  const conPunto = [];
  const sinCoordenada = [];
  for (const fila of filasDe(data)) {
    const lat = coordenada(fila.latitud);
    const lng = coordenada(fila.longitud);
    if (esPunto(lat, lng)) conPunto.push({ ...fila, lat, lng });
    else sinCoordenada.push(fila);
  }
  aviso.textContent = sinCoordenada.some((fila) => String(fila.maps_url || "").trim())
    ? "Buscando en el mapa la dirección guardada…"
    : aviso.textContent;
  const { ubicadas, sin } = await ubicarPorDireccion(sinCoordenada);
  if (miTurno !== turno) return;
  const puestos = [...conPunto, ...ubicadas];
  const sinPunto = sin;
  pintarCalle([...puestos, ...sinPunto]);
  if (typeof L === "undefined") {
    aviso.textContent = "No se pudo cargar el mapa. Las tienditas de arriba sí están.";
    return;
  }
  $("mapa").classList.toggle("vacio", puestos.length === 0);
  mapa = L.map("mapa", { scrollWheelZoom: false }).setView([-34.6, -64.2], 4);
  L.tileLayer("https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png", {
    subdomains: "abc",
    maxZoom: 19,
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(mapa);
  const marcas = [];
  for (const fila of puestos) {
    const marca = L.marker([fila.lat, fila.lng], {
      icon: iconoTienda(fila.logo_url, fila.nombre),
      title: fila.nombre || "Tienda",
    }).addTo(mapa);
    const popup = document.createElement("div");
    const titulo = document.createElement("strong");
    titulo.textContent = fila.nombre || "Tienda";
    popup.append(titulo);
    const slug = String(fila.slug || "").trim();
    if (slug) {
      const enlace = document.createElement("a");
      enlace.href = `https://gexi.com.ar/${encodeURIComponent(slug)}`;
      enlace.target = "_blank";
      enlace.rel = "noopener";
      enlace.textContent = "Abrir la tienda";
      enlace.style.display = "block";
      popup.append(enlace);
    }
    marca.bindPopup(popup);
    marcas.push(marca);
  }
  if (marcas.length === 1) {
    const caja = puestos[0].caja;
    if (Array.isArray(caja) && caja.length === 4 && caja.every((n) => Number.isFinite(n))) {
      mapa.fitBounds(
        [
          [caja[0], caja[2]],
          [caja[1], caja[3]],
        ],
        { padding: [24, 24], maxZoom: 14 },
      );
    } else {
      mapa.setView(marcas[0].getLatLng(), 13);
    }
  } else if (marcas.length > 1) {
    mapa.fitBounds(L.featureGroup(marcas).getBounds().pad(0.3));
  }
  aviso.textContent =
    puestos.length === 0
      ? "El mapa espera el lugar de cada local. Las tienditas de arriba ya están, cada una con su color."
      : "";
  $("lista-sin-lugar").replaceChildren();
  setTimeout(() => {
    if (mapa) mapa.invalidateSize();
  }, 120);
}

function limpiarNumeros() {
  for (const id of ["tiendas", "usuarios", "tokens", "chats"]) {
    $(id).textContent = "—";
  }
  $("aviso-asistente").hidden = true;
  $("aviso-resumen").textContent = "";
  $("lista-consumo").replaceChildren();
  $("aviso-consumo").textContent = "";
  $("lista-accesos").replaceChildren();
  $("aviso-accesos").textContent = "";
  $("lista-tokens").replaceChildren();
  $("aviso-tokens").textContent = "";
  vaciarMapa();
}

function filasDe(data) {
  if (Array.isArray(data)) return data;
  if (data && typeof data === "object") return [data];
  return [];
}

function fechaLocal(valor) {
  const date = new Date(valor);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("es-AR", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(date);
}

function linea(etiqueta, texto) {
  const p = document.createElement("p");
  const fuerte = document.createElement("strong");
  fuerte.textContent = etiqueta;
  p.append(fuerte, document.createTextNode(` ${texto || "—"}`));
  return p;
}

function celda(texto, clase) {
  const td = document.createElement("td");
  if (clase) td.className = clase;
  td.textContent = texto;
  return td;
}

function pintarTokens(filas) {
  const cuerpo = $("lista-tokens");
  cuerpo.replaceChildren();
  if (filas.length === 0) {
    $("aviso-tokens").textContent = "Todavía no hay microemprendimientos.";
    return;
  }
  $("aviso-tokens").textContent = "";
  for (const fila of filas) {
    const tr = document.createElement("tr");
    const tienda = document.createElement("td");
    const nombre = String(fila.nombre || "Sin nombre").trim();
    const quien = document.createElement("span");
    quien.className = "quien";
    quien.style.setProperty("--toldo", colorDe(nombre));
    const direccion = String(fila.logo_url || "").trim();
    if (/^https:\/\//i.test(direccion)) {
      const imagen = document.createElement("img");
      imagen.src = direccion;
      imagen.alt = "";
      quien.append(imagen);
    } else {
      const inicial = document.createElement("span");
      inicial.className = "muestra";
      inicial.textContent = (nombre.charAt(0) || "?").toUpperCase();
      quien.append(inicial);
    }
    const etiqueta = document.createElement("span");
    etiqueta.textContent = nombre;
    quien.append(etiqueta);
    tienda.append(quien);
    const entrada = entero(fila.tokens_entrada);
    const salida = entero(fila.tokens_salida);
    tr.append(
      tienda,
      celda(miles(entero(fila.consultas)), "num"),
      celda(miles(entrada), "num"),
      celda(miles(salida), "num"),
      celda(miles(entero(fila.tokens_cache)), "num"),
      celda(miles(entrada + salida), "num total"),
      celda(miles(entero(fila.chats_disponibles)), "num"),
    );
    cuerpo.append(tr);
  }
}

async function cargarTokens(miTurno) {
  $("lista-tokens").replaceChildren();
  $("aviso-tokens").textContent = "Cargando el consumo…";
  const { data, error } = await supabase.rpc("tokens_desarrollador");
  if (miTurno !== turno) return;
  if (error) {
    $("aviso-tokens").textContent = "No se pudo leer el consumo de tokens.";
    return;
  }
  const filas = filasDe(data);
  pintarTokens(filas);
  anotarConsumo(filas);
}

function nombreOrigen(valor) {
  switch (String(valor || "").trim()) {
    case "foto":
      return "Foto";
    case "pagina":
      return "Página";
    default:
      return "Asistente";
  }
}

function pintarConsumo(filas) {
  const cuerpo = $("lista-consumo");
  cuerpo.replaceChildren();
  if (filas.length === 0) {
    $("aviso-consumo").textContent = "Todavía no hay envíos anotados.";
    return;
  }
  $("aviso-consumo").textContent = "";
  for (const fila of filas) {
    const entrada = entero(fila.tokens_entrada);
    const salida = entero(fila.tokens_salida);
    const modelo = String(fila.modelo || "").trim();
    const tr = document.createElement("tr");
    tr.append(
      celda(fechaLocal(fila.creado_en) || "—"),
      celda(String(fila.negocio || "Sin nombre").trim()),
      celda(nombreOrigen(fila.origen)),
      celda(modelo || "—"),
      celda(miles(entrada), "num"),
      celda(miles(salida), "num"),
      celda(miles(entrada + salida), "num total"),
    );
    cuerpo.append(tr);
  }
}

async function cargarConsumo(miTurno) {
  $("lista-consumo").replaceChildren();
  $("aviso-consumo").textContent = "Cargando los envíos…";
  const { data, error } = await supabase.rpc("consumo_desarrollador", {
    p_limite: 40,
  });
  if (miTurno !== turno) return;
  if (error) {
    $("aviso-consumo").textContent = "No se pudieron leer los envíos.";
    return;
  }
  pintarConsumo(filasDe(data));
}

async function cargarResumen(email) {
  limpiarNumeros();
  mostrar("resumen");
  $("correo-ok").textContent = email;
  const miTurno = turno;
  const { data, error } = await supabase.rpc("resumen_desarrollador");
  if (miTurno !== turno) return;
  if (error) {
    $("aviso-resumen").textContent = "No se pudo leer el resumen.";
    await cargarConsumo(miTurno);
    await cargarAccesos(miTurno);
    await cargarMapa(miTurno);
    await cargarTokens(miTurno);
    await cargarIa(miTurno);
    return;
  }
  const fila = filaDe(data);
  if (!fila) {
    mostrarSinAcceso(email);
    return;
  }
  $("tiendas").textContent = miles(entero(fila.tiendas_activas));
  $("usuarios").textContent = miles(entero(fila.usuarios));
  $("tokens").textContent = miles(entero(fila.tokens));
  $("chats").textContent = miles(entero(fila.chats_disponibles));
  $("aviso-asistente").hidden = fila.asistente_sin_datos !== true;
  $("aviso-resumen").textContent = "";
  await cargarConsumo(miTurno);
  await cargarAccesos(miTurno);
  await cargarMapa(miTurno);
  await cargarTokens(miTurno);
  await cargarIa(miTurno);
}

function mostrarSinAcceso(email) {
  limpiarNumeros();
  $("correo-rechazado").textContent = email || "";
  mostrar("sin-acceso");
}

async function aplicarSesion(session) {
  const actual = ++turno;
  sesionActual = session;
  if (!session) {
    limpiarNumeros();
    mostrar("ingreso");
    return;
  }
  const email = session.user?.email?.trim() || "";
  if (!esDesarrollador(email)) {
    if (actual !== turno) return;
    mostrarSinAcceso(email);
    return;
  }
  await cargarResumen(email);
}

async function cargarAccesos(miTurno) {
  const lista = $("lista-accesos");
  lista.replaceChildren();
  $("aviso-accesos").textContent = "Cargando lugares…";
  const { data, error } = await supabase.rpc("accesos_desarrollador");
  if (miTurno !== turno) return;
  if (error) {
    $("aviso-accesos").textContent = "No se pudieron leer los lugares.";
    return;
  }
  const filas = filasDe(data);
  if (filas.length === 0) {
    $("aviso-accesos").textContent =
      "Todavía no hay registros. Aparecen cuando alguien abre la app con sesión.";
    return;
  }
  $("aviso-accesos").textContent = "";
  for (const fila of filas) {
    const articulo = document.createElement("article");
    articulo.className = "chat";
    const lugar = [fila.ciudad, fila.region, fila.pais]
      .map((parte) => String(parte || "").trim())
      .filter((parte, indice, todos) => parte && todos.indexOf(parte) === indice)
      .join(", ");
    articulo.append(
      linea("Cuenta:", fila.email),
      linea("Lugar:", lugar),
      linea("Última vez:", fechaLocal(fila.visto_en)),
    );
    lista.append(articulo);
  }
}

async function salir() {
  await supabase.auth.signOut();
  sesionActual = null;
  limpiarNumeros();
  mostrar("ingreso");
}

function avisoIngreso(texto, esError) {
  const aviso = $("aviso-ingreso");
  aviso.textContent = texto;
  aviso.classList.toggle("error", Boolean(esError));
}

$("entrar").addEventListener("click", async () => {
  const boton = $("entrar");
  boton.disabled = true;
  avisoIngreso("", false);
  const { error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: REDIRECT,
      queryParams: { prompt: "select_account" },
    },
  });
  boton.disabled = false;
  if (error) avisoIngreso("No se pudo abrir Google. Volvé a intentar.", true);
});

$("salir").addEventListener("click", salir);
$("salir-rechazado").addEventListener("click", salir);
$("actualizar").addEventListener("click", () => {
  const email = sesionActual?.user?.email?.trim() || "";
  if (!esDesarrollador(email)) {
    mostrarSinAcceso(email);
    return;
  }
  cargarResumen(email);
});

let iaOcupada = false;
let iaVista = null;

function avisoIa(texto, esError) {
  const aviso = $("aviso-ia");
  if (!aviso) return;
  aviso.textContent = texto;
  aviso.classList.toggle("error", Boolean(esError));
}

function mensajeErrorIa(error) {
  const texto = String(error?.message || "").replace(/\s+/g, " ").trim();
  if (!texto || /sk-|bearer|api[_ -]?key/i.test(texto)) {
    return "No se pudo guardar la configuración.";
  }
  return texto;
}

function filaIa(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  return data;
}

function sufijoVisible(valor) {
  const texto = String(valor || "").trim();
  return texto ? `····${texto}` : "";
}

function textoFuente(vista) {
  if (!vista) return "No se pudo leer la configuración.";
  if (vista.fuente === "clave") {
    const activa = (vista.claves || []).find((clave) => clave.activa);
    const nombre = String(activa?.etiqueta || "Clave").trim();
    const cola = sufijoVisible(activa?.sufijo);
    return cola
      ? `Fuente activa: ${nombre} ${cola}. El asistente compartido usa esta clave.`
      : `Fuente activa: ${nombre}. El asistente compartido usa esta clave.`;
  }
  if (vista.fuente === "local" && vista.local) {
    return `Fuente activa: ${vista.local.modelo} en ${vista.local.base_url}. El teléfono llama a ese servidor.`;
  }
  return "No hay una fuente del panel. El asistente usa el secreto de la función.";
}

function pintarIa(data) {
  const vista = filaIa(data);
  iaVista = vista;
  const lista = $("ia-claves");
  const fuente = $("ia-fuente");
  if (!lista || !fuente) return;
  fuente.textContent = textoFuente(vista);
  lista.replaceChildren();
  const claves = Array.isArray(vista?.claves) ? vista.claves : [];
  if (claves.length === 0) {
    const vacio = document.createElement("p");
    vacio.className = "ayuda";
    vacio.textContent = "Todavía no hay claves guardadas.";
    lista.append(vacio);
  }
  for (const clave of claves) {
    const item = document.createElement("article");
    item.className = clave.activa ? "ia-item activa" : "ia-item";
    const textos = document.createElement("div");
    const nombre = document.createElement("p");
    nombre.textContent = String(clave.etiqueta || "Clave").trim();
    if (clave.activa) {
      const pill = document.createElement("span");
      pill.className = "pill";
      pill.textContent = "Activa";
      nombre.append(pill);
    }
    const detalle = document.createElement("p");
    detalle.className = "detalle";
    detalle.textContent = sufijoVisible(clave.sufijo) || "Guardada";
    textos.append(nombre, detalle);
    const acciones = document.createElement("div");
    acciones.className = "acciones";
    if (!clave.activa) {
      const usar = document.createElement("button");
      usar.type = "button";
      usar.className = "chico";
      usar.textContent = "Usar";
      usar.addEventListener("click", () => activarClaveIa(clave.id));
      acciones.append(usar);
    }
    const borrar = document.createElement("button");
    borrar.type = "button";
    borrar.className = "peligro chico";
    borrar.textContent = "Eliminar";
    borrar.addEventListener("click", () => borrarClaveIa(clave));
    acciones.append(borrar);
    item.append(textos, acciones);
    lista.append(item);
  }

  const local = vista?.local || null;
  const url = $("ia-local-url");
  const modelo = $("ia-local-modelo");
  const claveLocal = $("ia-local-clave");
  if (url && document.activeElement !== url) url.value = local?.base_url || "";
  if (modelo && document.activeElement !== modelo) modelo.value = local?.modelo || "";
  if (claveLocal) {
    claveLocal.placeholder = local?.tiene_clave
      ? `Dejá vacío para conservar la clave ${sufijoVisible(local.sufijo) || "guardada"}`
      : "Opcional";
  }
  const activarLocal = $("ia-local-activar");
  if (activarLocal && document.activeElement !== activarLocal) {
    activarLocal.checked = Boolean(local?.activo) || (!local && vista?.fuente === "ninguna");
  }
  const quitarClave = $("ia-quitar-clave-local");
  const quitar = $("ia-quitar-local");
  const secreto = $("ia-usar-secreto");
  if (quitarClave) quitarClave.hidden = !local?.tiene_clave;
  if (quitar) quitar.hidden = !local;
  if (secreto) secreto.hidden = !vista || vista.fuente === "ninguna";
}

async function cargarIa(miTurno) {
  const fuente = $("ia-fuente");
  if (fuente) fuente.textContent = "Cargando la configuración…";
  const { data, error } = await supabase.rpc("ia_panel_ver");
  if (miTurno !== turno) return;
  if (error || !filaIa(data)) {
    if (fuente) fuente.textContent = "No se pudo leer la configuración de IA.";
    return;
  }
  pintarIa(data);
}

async function mutarIa(nombre, args = {}) {
  if (iaOcupada) return null;
  iaOcupada = true;
  avisoIa("", false);
  const { data, error } = await supabase.rpc(nombre, args);
  iaOcupada = false;
  if (error || !filaIa(data)) {
    avisoIa(error ? mensajeErrorIa(error) : "No se pudo guardar la configuración.", true);
    return null;
  }
  pintarIa(data);
  return data;
}

async function activarClaveIa(id) {
  const data = await mutarIa("ia_panel_activar_clave", { p_id: id });
  if (data) avisoIa("Esa clave quedó como la fuente activa.", false);
}

async function borrarClaveIa(clave) {
  const nombre = String(clave.etiqueta || "esa clave").trim();
  if (!window.confirm(`¿Eliminar «${nombre}»? No se puede deshacer.`)) return;
  const data = await mutarIa("ia_panel_borrar_clave", { p_id: clave.id });
  if (data) avisoIa("Clave eliminada.", false);
}

$("ia-agregar-clave").addEventListener("click", async () => {
  const valor = $("ia-clave-valor").value;
  if (!valor.trim()) {
    avisoIa("La clave está vacía.", true);
    return;
  }
  const activar = $("ia-clave-activar").checked;
  const data = await mutarIa("ia_panel_agregar_clave", {
    p_etiqueta: $("ia-clave-nombre").value,
    p_valor: valor,
    p_activar: activar,
  });
  if (!data) return;
  $("ia-clave-valor").value = "";
  $("ia-clave-nombre").value = "";
  avisoIa(
    data.repetida
      ? activar
        ? "Esa clave ya estaba y quedó activa."
        : "Esa clave ya estaba guardada."
      : "Clave guardada. Solo vas a ver el nombre y los últimos 4 caracteres.",
    false,
  );
});

$("ia-guardar-local").addEventListener("click", async () => {
  const clave = $("ia-local-clave").value;
  const tenia = Boolean(iaVista?.local?.tiene_clave);
  const data = await mutarIa("ia_panel_guardar_local", {
    p_base_url: $("ia-local-url").value,
    p_modelo: $("ia-local-modelo").value,
    p_clave: clave,
    p_cambiar_clave: clave.trim().length > 0 || !tenia,
    p_activar: $("ia-local-activar").checked,
  });
  if (!data) return;
  $("ia-local-clave").value = "";
  avisoIa("Modelo local guardado.", false);
});

$("ia-quitar-clave-local").addEventListener("click", async () => {
  const data = await mutarIa("ia_panel_guardar_local", {
    p_base_url: $("ia-local-url").value,
    p_modelo: $("ia-local-modelo").value,
    p_clave: "",
    p_cambiar_clave: true,
    p_activar: $("ia-local-activar").checked,
  });
  if (!data) return;
  $("ia-local-clave").value = "";
  avisoIa("La clave del modelo quedó vacía.", false);
});

$("ia-quitar-local").addEventListener("click", async () => {
  const nombre = String(iaVista?.local?.modelo || "el modelo local").trim();
  if (!window.confirm(`¿Quitar ${nombre}? La dirección deja de usarse.`)) return;
  const data = await mutarIa("ia_panel_quitar_local");
  if (!data) return;
  $("ia-local-url").value = "";
  $("ia-local-modelo").value = "";
  $("ia-local-clave").value = "";
  avisoIa("Modelo local quitado.", false);
});

$("ia-usar-secreto").addEventListener("click", async () => {
  const data = await mutarIa("ia_panel_usar_secreto");
  if (data) avisoIa("El asistente va a usar el secreto de la función.", false);
});

const params = new URLSearchParams(location.search);
if (params.get("error") || params.get("error_description")) {
  avisoIngreso("El ingreso con Google no se completó. Volvé a intentar desde esta página.", true);
}

const { data } = await supabase.auth.getSession();
await aplicarSesion(data.session);
supabase.auth.onAuthStateChange((_evento, session) => {
  aplicarSesion(session);
});

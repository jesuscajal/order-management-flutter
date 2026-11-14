// Foto de catálogo con fondo blanco.
// Usa la clave activa del panel si hay una. Si no, OPENAI_API_KEY.
// No devuelve la clave.
//
// No escribe en asistente_mensajes. La app recomprime el JPEG y lo guarda en la vidriera.
// gpt-image-1 se apagó el 23 oct 2026. dall-e-3 se retiró el 12 may 2026.
// Flare es el modelo documentado para generación cotidiana. Si esta cuenta no lo tiene,
// gpt-image-1-mini acepta el mismo body (fondo opaco, jpeg, 1024).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const MENSAJE_NO_CONFIGURADA =
  "Para generar la foto hace falta configurar el asistente.";

const MODELOS = ["gpt-image-2.5-flare", "gpt-image-1-mini"];

Deno.serve(async (req: Request) => {
  const secreto = await claveOpenAi();
  if (req.method !== "POST") {
    return responder({ error: "metodo", mensaje: "Usá POST." }, 405, secreto);
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ") || auth.trim().length < 16) {
    return responder(
      {
        error: "sin_sesion",
        mensaje:
          "Iniciá sesión para generar la foto.",
      },
      401,
      secreto,
    );
  }

  if (!secreto) {
    return responder(
      { error: "imagen_no_configurada", mensaje: MENSAJE_NO_CONFIGURADA },
      401,
      secreto,
    );
  }

  const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
  const anon = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
  if (!supabaseUrl || !anon) {
    return responder(
      { error: "imagen_no_configurada", mensaje: MENSAJE_NO_CONFIGURADA },
      401,
      secreto,
    );
  }

  const negocioId = await negocioDeLaSesion(supabaseUrl, anon, auth);
  if (!negocioId) {
    return responder(
      {
        error: "sin_sesion",
        mensaje:
          "No encontré el negocio de esta sesión. Iniciá sesión para generar la foto.",
      },
      403,
      secreto,
    );
  }

  let body: Record<string, unknown> = {};
  try {
    const decoded = await req.json();
    if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
      body = decoded as Record<string, unknown>;
    }
  } catch {
    return responder(
      { error: "body", mensaje: "No pude leer el pedido." },
      400,
      secreto,
    );
  }

  const nombre = textoCorto(body.nombre, 120);
  if (!nombre) {
    return responder(
      {
        error: "nombre",
        mensaje: "Falta el nombre del producto para generar la foto.",
      },
      400,
      secreto,
    );
  }

  const imagen = await generarImagen(
    secreto,
    promptCatalogo(
      nombre,
      textoCorto(body.categoria, 80),
      textoCorto(body.descripcion, 240),
    ),
  );
  return responder(imagen.cuerpo, imagen.estado, secreto);
});

function responder(
  cuerpo: Record<string, unknown>,
  estado: number,
  secreto: string,
): Response {
  const limpio: Record<string, unknown> = {};
  for (const [clave, valor] of Object.entries(cuerpo)) {
    if (clave === "imagen_base64" && typeof valor === "string") {
      limpio[clave] = valor;
      continue;
    }
    limpio[clave] = typeof valor === "string" ? sinSecreto(valor, secreto) : valor;
  }
  return new Response(JSON.stringify(limpio), {
    status: estado,
    headers: { "Content-Type": "application/json" },
  });
}

function sinSecreto(texto: string, secreto: string): string {
  let limpio = secreto ? texto.split(secreto).join("") : texto;
  limpio = limpio.replace(/\bsk-[A-Za-z0-9_-]{8,}/g, "");
  return limpio.trim();
}

async function negocioDeLaSesion(
  supabaseUrl: string,
  anon: string,
  auth: string,
): Promise<string | null> {
  const respuesta = await fetch(
    `${supabaseUrl}/rest/v1/negocios?select=id&limit=1`,
    {
      headers: {
        Authorization: auth,
        apikey: anon,
        Accept: "application/json",
      },
    },
  );
  if (!respuesta.ok) return null;
  const filas = await respuesta.json();
  if (!Array.isArray(filas) || filas.length === 0) return null;
  const id = filas[0]?.id;
  return typeof id === "string" && id.length > 0 ? id : null;
}

async function claveOpenAi(): Promise<string> {
  const delPanel = await claveDelPanel();
  if (delPanel) return delPanel;
  return (Deno.env.get("OPENAI_API_KEY") ?? "").trim();
}

async function claveDelPanel(): Promise<string> {
  const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
  const service = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
  if (!supabaseUrl || !service) return "";
  try {
    const respuesta = await fetch(
      `${supabaseUrl}/rest/v1/rpc/ia_clave_openai_activa`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${service}`,
          apikey: service,
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: "{}",
      },
    );
    if (!respuesta.ok) return "";
    const valor = await respuesta.json();
    return typeof valor === "string" ? valor.trim() : "";
  } catch {
    return "";
  }
}

function promptCatalogo(
  nombre: string,
  categoria: string,
  descripcion: string,
): string {
  const deRubro = categoria.length === 0 ? "" : `, categoría ${categoria}`;
  const deDetalle = descripcion.length === 0
    ? ""
    : ` Características: ${descripcion}.`;
  return `Una sola foto de catálogo para una tienda online del producto "${nombre}"${deRubro}.${deDetalle} `
    + "El producto está centrado, entero y apoyado sobre un fondo blanco puro (#FFFFFF). "
    + "Luz de estudio pareja, sombra de contacto muy suave, encuadre cuadrado. "
    + "Sin texto, sin letras, sin logo, sin marca de agua, sin precio, sin manos "
    + "y sin otros objetos.";
}

async function generarImagen(
  secreto: string,
  prompt: string,
): Promise<{ estado: number; cuerpo: Record<string, unknown> }> {
  let ultimo: { estado: number; cuerpo: Record<string, unknown> } | null = null;
  for (let i = 0; i < MODELOS.length; i++) {
    const resultado = await pedirModelo(secreto, prompt, MODELOS[i]);
    if (resultado.imagen) {
      return {
        estado: 200,
        cuerpo: {
          imagen_base64: resultado.imagen,
          modelo: resultado.modelo,
          usage: resultado.usage,
        },
      };
    }
    ultimo = { estado: resultado.estado, cuerpo: resultado.cuerpo };
    if (!resultado.otroModelo) break;
  }
  return ultimo ?? {
    estado: 502,
    cuerpo: {
      error: "openai",
      mensaje: "No pude generar la foto. Podés subir una.",
    },
  };
}

async function pedirModelo(
  secreto: string,
  prompt: string,
  modelo: string,
): Promise<{
  estado: number;
  imagen: string | null;
  modelo: string;
  usage: Record<string, unknown>;
  otroModelo: boolean;
  cuerpo: Record<string, unknown>;
}> {
  let respuesta: Response;
  try {
    respuesta = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      signal: AbortSignal.timeout(120_000),
      headers: {
        Authorization: `Bearer ${secreto}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: modelo,
        prompt,
        n: 1,
        size: "1024x1024",
        quality: "medium",
        background: "opaque",
        output_format: "jpeg",
        output_compression: 70,
      }),
    });
  } catch {
    return {
      estado: 502,
      imagen: null,
      modelo: "",
      usage: {},
      otroModelo: false,
      cuerpo: {
        error: "conexion",
        mensaje:
          "No se pudo generar la foto. Revisá la conexión o subí una imagen.",
      },
    };
  }

  let data: Record<string, unknown> = {};
  try {
    const decoded = await respuesta.json();
    if (decoded && typeof decoded === "object") {
      data = decoded as Record<string, unknown>;
    }
  } catch {
    data = {};
  }

  if (!respuesta.ok) {
    const fallo = motivoOpenAi(respuesta.status, data);
    return {
      estado: fallo.estado,
      imagen: null,
      modelo: "",
      usage: {},
      otroModelo: fallo.otroModelo,
      cuerpo: { error: fallo.error, mensaje: fallo.mensaje },
    };
  }

  const imagen = leerImagen(data);
  if (!imagen) {
    return {
      estado: 502,
      imagen: null,
      modelo: "",
      usage: {},
      otroModelo: false,
      cuerpo: {
        error: "vacio",
        mensaje: "OpenAI no devolvió la imagen. Podés subir una foto.",
      },
    };
  }
  return {
    estado: 200,
    imagen,
    modelo,
    usage: usoImagen(data.usage),
    otroModelo: false,
    cuerpo: {},
  };
}

function usoImagen(usage: unknown): Record<string, unknown> {
  const mapa = usage && typeof usage === "object"
    ? usage as Record<string, unknown>
    : {};
  const entrada = typeof mapa.input_tokens === "number"
    ? mapa.input_tokens
    : mapa.prompt_tokens;
  const salida = typeof mapa.output_tokens === "number"
    ? mapa.output_tokens
    : mapa.completion_tokens;
  const entero = (valor: unknown) =>
    typeof valor === "number" && Number.isFinite(valor) ? Math.trunc(valor) : 0;
  return {
    prompt_tokens: entero(entrada),
    completion_tokens: entero(salida),
  };
}

function leerImagen(data: Record<string, unknown>): string | null {
  const filas = data.data;
  if (!Array.isArray(filas) || filas.length === 0) return null;
  const primera = filas[0];
  if (!primera || typeof primera !== "object") return null;
  const b64 = (primera as Record<string, unknown>).b64_json;
  if (typeof b64 !== "string") return null;
  const limpio = b64.trim();
  return limpio.length > 0 ? limpio : null;
}

function motivoOpenAi(
  status: number,
  data: Record<string, unknown>,
): { estado: number; error: string; mensaje: string; otroModelo: boolean } {
  const error = data.error;
  const mapa = error && typeof error === "object"
    ? error as Record<string, unknown>
    : {};
  const codigo = typeof mapa.code === "string" ? mapa.code.toLowerCase() : "";
  const parametro = typeof mapa.param === "string" ? mapa.param.toLowerCase() : "";
  const detalle = typeof mapa.message === "string" ? mapa.message.toLowerCase() : "";

  if (
    status === 401 ||
    codigo === "invalid_api_key" ||
    codigo === "incorrect_api_key" ||
    detalle.includes("incorrect api key") ||
    detalle.includes("invalid api key") ||
    detalle.includes("api key") && detalle.includes("expired")
  ) {
    return {
      estado: 401,
      error: "clave_invalida",
      otroModelo: false,
      mensaje: "La clave de OpenAI del asistente no es válida.",
    };
  }

  if (
    status === 402 ||
    codigo === "insufficient_quota" ||
    codigo === "billing_hard_limit_reached" ||
    codigo === "billing_not_active" ||
    detalle.includes("insufficient_quota") ||
    detalle.includes("exceeded your current quota") ||
    detalle.includes("billing hard limit") ||
    detalle.includes("check your plan and billing")
  ) {
    return {
      estado: 402,
      error: "sin_saldo",
      otroModelo: false,
      mensaje: "La cuenta de OpenAI no tiene saldo para generar la foto.",
    };
  }

  if (
    status === 413 ||
    codigo === "image_too_large" ||
    codigo === "payload_too_large" ||
    detalle.includes("image is too large") ||
    detalle.includes("image too large") ||
    detalle.includes("file is too large")
  ) {
    return {
      estado: 413,
      error: "foto_pesada",
      otroModelo: false,
      mensaje: "La imagen es muy pesada. Probá con una foto más chica.",
    };
  }

  const mencionaModelo = detalle.includes("model") ||
    detalle.includes("gpt-image") ||
    detalle.includes("dall-e");
  const modeloCaido = codigo === "model_not_found" ||
    codigo === "model_not_available" ||
    parametro === "model" ||
    mencionaModelo && (
      detalle.includes("not found") ||
      detalle.includes("does not exist") ||
      detalle.includes("do not exist") ||
      detalle.includes("not available") ||
      detalle.includes("do not have access") ||
      detalle.includes("deprecated") ||
      detalle.includes("shut down") ||
      detalle.includes("shutdown") ||
      detalle.includes("no longer") ||
      detalle.includes("not supported")
    );
  if (modeloCaido) {
    return {
      estado: 502,
      error: "modelo_no_disponible",
      otroModelo: true,
      mensaje: "El modelo de imagen no está disponible en esta cuenta.",
    };
  }

  if (status === 429 || codigo === "rate_limit_exceeded") {
    return {
      estado: 429,
      error: "limite",
      otroModelo: false,
      mensaje:
        "OpenAI limitó la generación de imágenes. Esperá un momento o subí una foto.",
    };
  }

  if (
    codigo === "moderation_blocked" ||
    detalle.includes("safety system") ||
    detalle.includes("content policy")
  ) {
    return {
      estado: 502,
      error: "moderacion",
      otroModelo: false,
      mensaje: "OpenAI no dejó generar esa foto. Podés subir una.",
    };
  }

  return {
    estado: status >= 400 ? status : 502,
    error: "openai",
    otroModelo: false,
    mensaje: `No pude generar la foto (${status}). Podés subir una.`,
  };
}

function textoCorto(valor: unknown, tope: number): string {
  if (typeof valor !== "string") return "";
  const limpio = valor.replace(/\s+/g, " ").trim();
  return limpio.length <= tope ? limpio : limpio.slice(0, tope);
}

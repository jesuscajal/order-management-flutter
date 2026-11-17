// Borra las imágenes, los datos del negocio del dueño y la cuenta de Auth.
// El correo sale de la sesión. La app tiene que mandar confirmacion = BORRAR.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type Admin = ReturnType<typeof createClient>;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "metodo", mensaje: "Usá POST." }, 405);
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return json({ error: "sesion", mensaje: "No hay una cuenta abierta." }, 401);
  }

  let cuerpo: Record<string, unknown> = {};
  try {
    const decoded = await req.json();
    if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
      cuerpo = decoded as Record<string, unknown>;
    }
  } catch (_) {
    cuerpo = {};
  }
  if (cuerpo.confirmacion !== "BORRAR") {
    return json(
      { error: "confirmacion", mensaje: "Escribí BORRAR para confirmar." },
      400,
    );
  }

  const url = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
  const anon = (Deno.env.get("SUPABASE_ANON_KEY") ?? "").trim();
  const service = (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trim();
  if (!url || !anon || !service) {
    return json(
      { error: "config", mensaje: "No se pudo borrar la cuenta." },
      500,
    );
  }

  const sesion = createClient(url, anon, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await sesion.auth.getUser();
  const usuario = userData?.user;
  const correo = (usuario?.email ?? "").trim().toLowerCase();
  if (userError || !usuario || !correo) {
    return json({ error: "sesion", mensaje: "No hay una cuenta abierta." }, 401);
  }

  const admin = createClient(url, service, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: negocios, error: negociosError } = await admin
    .from("negocios")
    .select("id, dueno_email")
    .ilike("dueno_email", correo);
  if (negociosError) {
    return json(
      { error: "datos", mensaje: "No se pudieron leer los datos de la cuenta." },
      500,
    );
  }

  const ids = [
    ...new Set(
      (negocios ?? [])
        .filter((fila) =>
          String(fila.dueno_email ?? "").trim().toLowerCase() === correo
        )
        .map((fila) => String(fila.id ?? "").trim())
        .filter((id) => id.length > 0),
    ),
  ];

  try {
    for (const id of ids) {
      await vaciarCarpeta(admin, "productos", id);
      await vaciarCarpeta(admin, "comprobantes", id);
    }
  } catch (_) {
    return json(
      { error: "imagenes", mensaje: "No se pudieron borrar las imágenes." },
      500,
    );
  }

  const { error: datosError } = await admin.rpc("borrar_datos_de_cuenta", {
    p_email: correo,
  });
  if (datosError) {
    return json(
      { error: "datos", mensaje: "No se pudieron borrar los datos de la cuenta." },
      500,
    );
  }

  const { error: cuentaError } = await admin.auth.admin.deleteUser(usuario.id);
  if (cuentaError) {
    return json(
      {
        error: "cuenta",
        mensaje: "Se borraron los datos, pero la cuenta de ingreso sigue activa.",
      },
      500,
    );
  }

  return json({ ok: true }, 200);
});

async function vaciarCarpeta(admin: Admin, bucket: string, prefijo: string) {
  const { data, error } = await admin.storage.from(bucket).list(prefijo, {
    limit: 1000,
  });
  if (error) throw error;
  const archivos: string[] = [];
  for (const item of data ?? []) {
    const nombre = String(item.name ?? "").trim();
    if (!nombre) continue;
    const ruta = `${prefijo}/${nombre}`;
    if (item.id == null) {
      await vaciarCarpeta(admin, bucket, ruta);
    } else {
      archivos.push(ruta);
    }
  }
  for (let i = 0; i < archivos.length; i += 100) {
    const lote = archivos.slice(i, i + 100);
    const { error: removeError } = await admin.storage.from(bucket).remove(lote);
    if (removeError) throw removeError;
  }
}

function json(cuerpo: Record<string, unknown>, estado: number) {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { "Content-Type": "application/json" },
  });
}

-- Chat del asistente, contexto corto, consumo y cupo por negocio.
-- anon no tiene permisos ni políticas: no lee ni escribe estas tablas.
-- El cupo anterior (una fila por email, con usados/limite) no lo usa la app
-- y estaba vacío. Pasa a una fila por negocio.

drop policy if exists asistente_cupo_acceso on public.asistente_cupo;
drop table if exists public.asistente_cupo;

create table public.asistente_mensajes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  usuario_email text not null,
  rol text not null,
  contenido text not null,
  creado_en timestamptz not null default now(),
  constraint asistente_mensajes_rol_check check (rol in ('user', 'assistant'))
);

create index asistente_mensajes_negocio_fecha_idx
  on public.asistente_mensajes (negocio_id, creado_en desc);

create table public.asistente_contexto (
  negocio_id uuid primary key references public.negocios (id) on delete cascade,
  resumen text not null default '',
  actualizado_en timestamptz not null default now(),
  constraint asistente_contexto_resumen_largo check (char_length(resumen) <= 500)
);

create table public.asistente_uso (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios (id) on delete cascade,
  usuario_email text not null,
  tokens_entrada integer not null default 0,
  tokens_salida integer not null default 0,
  tokens_cache integer not null default 0,
  creado_en timestamptz not null default now()
);

create index asistente_uso_negocio_fecha_idx
  on public.asistente_uso (negocio_id, creado_en desc);

create table public.asistente_cupo (
  negocio_id uuid primary key references public.negocios (id) on delete cascade,
  chats_disponibles integer not null default 30,
  constraint asistente_cupo_chats_check check (chats_disponibles >= 0)
);

-- El alta siempre arranca en 30. Un update no puede subir el número,
-- así que no se recarga el cupo desde el cliente.
create or replace function public.asistente_cupo_no_sube()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.chats_disponibles := 30;
    return new;
  end if;
  if new.chats_disponibles > old.chats_disponibles then
    raise exception 'el cupo del asistente no se puede aumentar';
  end if;
  return new;
end;
$$;

drop trigger if exists asistente_cupo_no_sube on public.asistente_cupo;
create trigger asistente_cupo_no_sube
  before insert or update on public.asistente_cupo
  for each row
  execute function public.asistente_cupo_no_sube();

-- Descuenta un chat si queda alguno. Crea la fila en 30 si no existe.
--  >= 0: chats que quedan después de descontar (0 es el último).
--  -1: el negocio no es de esta sesión.
--  -2: no quedaban chats; no descontó.
create or replace function public.reservar_chat_asistente(p_negocio uuid)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  quedan integer;
begin
  if p_negocio is null
     or not (public.es_miembro(p_negocio) or public.es_dueno(p_negocio)) then
    return -1;
  end if;

  insert into public.asistente_cupo (negocio_id)
  values (p_negocio)
  on conflict (negocio_id) do nothing;

  update public.asistente_cupo
  set chats_disponibles = chats_disponibles - 1
  where negocio_id = p_negocio
    and chats_disponibles > 0
  returning chats_disponibles into quedan;

  if quedan is null then
    return -2;
  end if;
  return quedan;
end;
$$;

alter table public.asistente_mensajes enable row level security;
alter table public.asistente_contexto enable row level security;
alter table public.asistente_uso enable row level security;
alter table public.asistente_cupo enable row level security;

drop policy if exists asistente_mensajes_acceso on public.asistente_mensajes;
create policy asistente_mensajes_acceso
  on public.asistente_mensajes
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (
    (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
    and lower(usuario_email) = lower(auth.jwt() ->> 'email')
  );

drop policy if exists asistente_contexto_acceso on public.asistente_contexto;
create policy asistente_contexto_acceso
  on public.asistente_contexto
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

drop policy if exists asistente_uso_acceso on public.asistente_uso;
create policy asistente_uso_acceso
  on public.asistente_uso
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (
    (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
    and lower(usuario_email) = lower(auth.jwt() ->> 'email')
  );

drop policy if exists asistente_cupo_acceso on public.asistente_cupo;
create policy asistente_cupo_acceso
  on public.asistente_cupo
  for all
  to authenticated
  using (public.es_miembro(negocio_id) or public.es_dueno(negocio_id))
  with check (public.es_miembro(negocio_id) or public.es_dueno(negocio_id));

revoke all on table
  public.asistente_mensajes,
  public.asistente_contexto,
  public.asistente_uso,
  public.asistente_cupo
from public, anon, authenticated;

grant select, insert on table public.asistente_mensajes to authenticated;
grant select, insert, update on table public.asistente_contexto to authenticated;
grant select, insert on table public.asistente_uso to authenticated;
grant select, insert, update on table public.asistente_cupo to authenticated;

revoke all on function public.asistente_cupo_no_sube() from public, anon, authenticated;
revoke all on function public.reservar_chat_asistente(uuid) from public, anon;
grant execute on function public.reservar_chat_asistente(uuid) to authenticated;

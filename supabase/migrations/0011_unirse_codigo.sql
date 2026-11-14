-- El empleado reclama su código desde otro teléfono y queda como miembro.

create or replace function public.unirse_por_codigo(p_codigo text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  codigo text := upper(trim(coalesce(p_codigo, '')));
  cantidad integer;
  fila public.miembros%rowtype;
begin
  if correo = '' then
    raise exception 'Necesitás una cuenta para entrar.';
  end if;
  if codigo = '' or codigo !~ '^[A-Z0-9]{4,12}$' then
    raise exception 'El código no es válido.';
  end if;

  select count(*)
    into cantidad
  from public.miembros
  where upper(codigo_empleado) = codigo
    and activo;

  if cantidad = 0 then
    raise exception 'No encontramos ese código de empleado.';
  end if;
  if cantidad > 1 then
    raise exception 'Ese código está repetido. Pedile otro a quien administra.';
  end if;

  select *
    into fila
  from public.miembros
  where upper(codigo_empleado) = codigo
    and activo;

  if lower(fila.email) <> correo and fila.email not like '%@equipo.gexi' then
    raise exception 'Ese código ya lo usa otra cuenta.';
  end if;

  update public.miembros
  set email = correo
  where id = fila.id;

  return fila.negocio_id;
end;
$$;

revoke all on function public.unirse_por_codigo(text) from public;
grant execute on function public.unirse_por_codigo(text) to authenticated;

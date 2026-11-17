-- Borra los datos de una cuenta. La llama solo la función de borde, con la
-- clave de servicio, después de comprobar la sesión. No la puede llamar la app.

create or replace function public.borrar_datos_de_cuenta(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  correo text := lower(trim(coalesce(p_email, '')));
  negocio uuid;
begin
  if correo = '' then
    raise exception 'falta el correo';
  end if;

  for negocio in
    select n.id
    from public.negocios as n
    where lower(n.dueno_email) = correo
  loop
    delete from public.movimientos_stock where negocio_id = negocio;
    delete from public.stock where negocio_id = negocio;
    delete from public.pedidos where negocio_id = negocio;
    delete from public.productos where negocio_id = negocio;
    delete from public.clientes where negocio_id = negocio;
    delete from public.movimientos_capital where negocio_id = negocio;
    delete from public.negocios where id = negocio;
  end loop;

  delete from public.miembros where lower(email) = correo;
  delete from public.perfiles where lower(email) = correo;
  delete from public.accesos_app where lower(email) = correo;
end;
$$;

revoke all on function public.borrar_datos_de_cuenta(text) from public, anon, authenticated;
grant execute on function public.borrar_datos_de_cuenta(text) to service_role;

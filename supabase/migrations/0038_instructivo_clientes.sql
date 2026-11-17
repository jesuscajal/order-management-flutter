-- La pantalla de clientes cambió: búsqueda, filtros y ficha.
-- Se sube todo el instructivo a la versión 2 para que coincida con la app.

update public.instructivo_funciones
set version = 2;

update public.instructivo_funciones
set
  texto = 'En Clientes buscás por nombre, teléfono o mail. Los filtros son Todos, Activos, Potenciales y Deben. Cada fila muestra el contacto y, si debe, el saldo a cobrar. Tocá la persona para escribirle por WhatsApp, llamarla, editarla, cambiar el estado de pago o eliminarla. Añadir cliente, el botón azul, carga una ficha nueva. Si tiene pedidos, no se puede borrar.',
  palabras = array['cliente', 'clientes', 'contacto', 'whatsapp']
where clave = 'clientes';

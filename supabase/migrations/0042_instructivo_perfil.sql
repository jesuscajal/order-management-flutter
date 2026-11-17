-- El alta pide nombre y apellido, y el WhatsApp solo al dueño.

update public.instructivo_funciones
set version = 6;

update public.instructivo_funciones
set texto = 'Equipo invita a otra persona con un código. Al entrar, el empleado carga nombre y apellido. Quien crea el negocio carga nombre, apellido y el WhatsApp del local. Un administrador puede desactivar el acceso.'
where clave = 'equipo';

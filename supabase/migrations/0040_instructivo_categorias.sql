-- Alta de stock con categorías y confirmación al borrar. Versión 4.

update public.instructivo_funciones
set version = 4;

update public.instructivo_funciones
set texto = 'En Stock buscás un producto por nombre. Cada fila muestra tu cantidad, la de Nildo, el precio de venta y el total. Si el total está en rojo, está bajo. Añadir stock, el botón azul, carga uno nuevo y te muestra las categorías que ya existen, o te deja crear una. Tocá el producto para cambiar nombre, precios o anotar una entrada o una salida. La cámara de la fila agrega hasta 4 fotos.'
where clave = 'stock';

update public.instructivo_funciones
set texto = 'Categorías ordena el catálogo de la página. El cliente ve los productos agrupados en ese orden. Para borrar una, la app pregunta si estás seguro. Si todavía tiene productos, no se puede eliminar.'
where clave = 'categorias';

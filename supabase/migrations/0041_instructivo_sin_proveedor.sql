-- Se sacó la compra al proveedor y el reparto del stock entre socios.

update public.instructivo_funciones
set version = 5;

update public.instructivo_funciones
set texto = 'En Stock buscás un producto por nombre. Cada fila muestra el precio de venta y la cantidad. Si está en rojo, está bajo. Añadir stock, el botón azul, carga uno nuevo y te muestra las categorías que ya existen, o te deja crear una. Tocá el producto para cambiar nombre, precios o anotar una entrada o una salida. La cámara de la fila agrega hasta 4 fotos.'
where clave = 'stock';

update public.instructivo_funciones
set texto = 'Para reponer mercadería usá Añadir stock. No hace falta anotar un proveedor: el stock entra directo al local.'
where clave = 'compra';

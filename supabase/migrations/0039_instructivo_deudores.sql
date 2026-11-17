-- La pantalla de deudores pasó a lista nativa. El instructivo sube a la versión 3.

update public.instructivo_funciones
set version = 3;

update public.instructivo_funciones
set
  texto = 'En Deudores ves a quién le vendiste fiado. Arriba está lo que te deben en total, cuántas personas y cuántas están vencidas. Podés buscar por nombre y filtrar Todos o Vencidos. Tocá la persona para anotar un pago parcial, el día de cobro, el teléfono o avisarle por WhatsApp.',
  palabras = array['deuda', 'deudas', 'deudor', 'deudores', 'fiado', 'debe', 'cobro']
where clave = 'deudores';

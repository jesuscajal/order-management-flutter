-- Categoría visible en Pedidos: manual o página web.
-- Aplicar después de 0003_requerimientos.sql.

begin;

alter table public.pedidos
  add column if not exists categoria text;

update public.pedidos
set categoria = case
  when origen = 'tienda' then 'web'
  else 'manual'
end
where categoria is null
  or categoria not in ('manual', 'web');

alter table public.pedidos
  alter column categoria set default 'manual';

alter table public.pedidos
  alter column categoria set not null;

alter table public.pedidos
  drop constraint if exists pedidos_categoria_check;

alter table public.pedidos
  add constraint pedidos_categoria_check
  check (categoria in ('manual', 'web'));

create index if not exists pedidos_negocio_categoria_idx
  on public.pedidos (negocio_id, categoria, creado_en desc);

commit;

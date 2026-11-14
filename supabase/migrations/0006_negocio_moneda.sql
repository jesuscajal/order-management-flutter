-- Moneda del negocio, elegida al crear la cuenta.
-- Los negocios ya guardados quedan en USD.
-- Aplicar después de 0005_fotos_categorias.sql.

begin;

alter table public.negocios
  add column if not exists moneda text;

update public.negocios
set moneda = upper(trim(moneda))
where moneda is not null
  and moneda <> upper(trim(moneda));

update public.negocios
set moneda = 'USD'
where moneda is null
  or length(trim(moneda)) = 0
  or upper(trim(moneda)) not in ('USD', 'ARS', 'EUR', 'BRL', 'CLP', 'UYU');

alter table public.negocios
  alter column moneda set default 'USD';

alter table public.negocios
  alter column moneda set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.negocios'::regclass
      and conname = 'negocios_moneda_check'
  ) then
    alter table public.negocios
      add constraint negocios_moneda_check
      check (moneda in ('USD', 'ARS', 'EUR', 'BRL', 'CLP', 'UYU'));
  end if;
end $$;

commit;

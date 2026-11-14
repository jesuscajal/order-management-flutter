-- País, nacionalidad y monedas de América Latina.
-- Aplicar después de 0006_negocio_moneda.sql.

begin;

alter table public.negocios
  add column if not exists pais text;

alter table public.negocios
  add column if not exists nacionalidad text;

alter table public.negocios
  drop constraint if exists negocios_moneda_check;

update public.negocios
set moneda = 'USD'
where upper(trim(moneda)) not in (
  'USD', 'EUR', 'ARS', 'BOB', 'BRL', 'CLP', 'COP', 'CRC', 'CUP',
  'GTQ', 'HTG', 'HNL', 'MXN', 'NIO', 'PAB', 'PYG', 'PEN', 'DOP',
  'UYU', 'VES', 'BZD', 'GYD', 'SRD'
);

alter table public.negocios
  add constraint negocios_moneda_check
  check (moneda in (
    'USD', 'EUR', 'ARS', 'BOB', 'BRL', 'CLP', 'COP', 'CRC', 'CUP',
    'GTQ', 'HTG', 'HNL', 'MXN', 'NIO', 'PAB', 'PYG', 'PEN', 'DOP',
    'UYU', 'VES', 'BZD', 'GYD', 'SRD'
  ));

commit;

-- 0034: Prices for every country, the client's country from their App Store
-- or Google Play account, licences in more than one country, and therapists
-- paid 80% of each session's price. Safe to run more than once.
--
--  1. Countries: the 220 countries and territories in the pricing sheet
--     (MindPillars-Global-Pricing, 16 November 2026; Jersey and Guernsey share a row there), with their two- and
--     three-letter codes, so a store's country code can be read either way.
--  2. Prices: one row per country from the sheet, in the local currency,
--     except the 15 places the sheet says to price in US dollars (high
--     inflation or an unstable currency). Paystack settles in Kenyan
--     shillings, so each price also carries the shillings charged for it,
--     at the sheet's rate of 130.0287 to the dollar, to the nearest 10.
--     The lower and upper prices are kept for reference. A price an admin
--     has changed is never overwritten by running this again.
--  3. The client's country: the app sends what the phone knows (the App
--     Store or Google Play account's country, the SIM's on Android, and the
--     region setting) and therapy_detect_country() picks the first of those
--     it recognises. It's fixed once they've paid for a session, and an
--     admin's choice always wins. Older app builds can still pick a country
--     by hand until one has been detected.
--  4. Pay: a therapist earns therapist_share() (80%) of the session's price,
--     in the session's currency, written on the session when it's completed
--     (including when the client didn't join). The share is stamped on each
--     session as it's booked. Completed sessions that never got a fee get
--     one now. The per-country fee table (therapist_rates) is no longer
--     used.
--  5. Licences: a therapist can hold a licence in several countries
--     (therapist_licences). Their main one comes from their application;
--     others arrive as licence documents with a country, checked by the
--     care team as in 0033. The admin's session list says which country
--     each client is priced in, so the care team can see whether a
--     therapist is licensed there. Nothing blocks a booking.
--  6. The therapist agreement moves to the version of 17 November 2026,
--     for the new pay. Deploy the therapist site in the same sitting: its
--     AGREEMENT_VERSION must match. Afterwards:
--       select public.notify_agreement_changed();

begin;

-- ── 1. Countries ─────────────────────────────────────────────────────

create table if not exists public.countries (
  code text primary key check (code ~ '^[A-Z]{2}$'),
  iso3 text not null unique check (iso3 ~ '^[A-Z]{3}$'),
  name text not null,
  -- The local currency, which isn't always what the price is in.
  currency text not null check (currency ~ '^[A-Z]{3}$')
);
alter table public.countries enable row level security;
-- No policies: read through the functions below.

insert into public.countries (code, iso3, name, currency)
values
  ('AD', 'AND', 'Andorra', 'EUR'),
  ('AE', 'ARE', 'United Arab Emirates', 'AED'),
  ('AF', 'AFG', 'Afghanistan', 'AFN'),
  ('AG', 'ATG', 'Antigua and Barbuda', 'XCD'),
  ('AL', 'ALB', 'Albania', 'ALL'),
  ('AM', 'ARM', 'Armenia', 'AMD'),
  ('AO', 'AGO', 'Angola', 'AOA'),
  ('AR', 'ARG', 'Argentina', 'ARS'),
  ('AS', 'ASM', 'American Samoa', 'USD'),
  ('AT', 'AUT', 'Austria', 'EUR'),
  ('AU', 'AUS', 'Australia', 'AUD'),
  ('AW', 'ABW', 'Aruba', 'AWG'),
  ('AZ', 'AZE', 'Azerbaijan', 'AZN'),
  ('BA', 'BIH', 'Bosnia and Herzegovina', 'BAM'),
  ('BB', 'BRB', 'Barbados', 'BBD'),
  ('BD', 'BGD', 'Bangladesh', 'BDT'),
  ('BE', 'BEL', 'Belgium', 'EUR'),
  ('BF', 'BFA', 'Burkina Faso', 'XOF'),
  ('BG', 'BGR', 'Bulgaria', 'EUR'),
  ('BH', 'BHR', 'Bahrain', 'BHD'),
  ('BI', 'BDI', 'Burundi', 'BIF'),
  ('BJ', 'BEN', 'Benin', 'XOF'),
  ('BM', 'BMU', 'Bermuda', 'BMD'),
  ('BN', 'BRN', 'Brunei', 'BND'),
  ('BO', 'BOL', 'Bolivia', 'BOB'),
  ('BR', 'BRA', 'Brazil', 'BRL'),
  ('BS', 'BHS', 'Bahamas', 'BSD'),
  ('BT', 'BTN', 'Bhutan', 'BTN'),
  ('BW', 'BWA', 'Botswana', 'BWP'),
  ('BY', 'BLR', 'Belarus', 'BYN'),
  ('BZ', 'BLZ', 'Belize', 'BZD'),
  ('CA', 'CAN', 'Canada', 'CAD'),
  ('CD', 'COD', 'DR Congo', 'CDF'),
  ('CF', 'CAF', 'Central African Republic', 'XAF'),
  ('CG', 'COG', 'Congo (Republic)', 'XAF'),
  ('CH', 'CHE', 'Switzerland', 'CHF'),
  ('CI', 'CIV', 'Côte d''Ivoire', 'XOF'),
  ('CL', 'CHL', 'Chile', 'CLP'),
  ('CM', 'CMR', 'Cameroon', 'XAF'),
  ('CN', 'CHN', 'China', 'CNY'),
  ('CO', 'COL', 'Colombia', 'COP'),
  ('CR', 'CRI', 'Costa Rica', 'CRC'),
  ('CU', 'CUB', 'Cuba', 'CUP'),
  ('CV', 'CPV', 'Cabo Verde', 'CVE'),
  ('CW', 'CUW', 'Curaçao', 'XCG'),
  ('CY', 'CYP', 'Cyprus', 'EUR'),
  ('CZ', 'CZE', 'Czechia', 'CZK'),
  ('DE', 'DEU', 'Germany', 'EUR'),
  ('DJ', 'DJI', 'Djibouti', 'DJF'),
  ('DK', 'DNK', 'Denmark', 'DKK'),
  ('DM', 'DMA', 'Dominica', 'XCD'),
  ('DO', 'DOM', 'Dominican Republic', 'DOP'),
  ('DZ', 'DZA', 'Algeria', 'DZD'),
  ('EC', 'ECU', 'Ecuador', 'USD'),
  ('EE', 'EST', 'Estonia', 'EUR'),
  ('EG', 'EGY', 'Egypt', 'EGP'),
  ('ER', 'ERI', 'Eritrea', 'ERN'),
  ('ES', 'ESP', 'Spain', 'EUR'),
  ('ET', 'ETH', 'Ethiopia', 'ETB'),
  ('FI', 'FIN', 'Finland', 'EUR'),
  ('FJ', 'FJI', 'Fiji', 'FJD'),
  ('FM', 'FSM', 'Micronesia', 'USD'),
  ('FO', 'FRO', 'Faroe Islands', 'DKK'),
  ('FR', 'FRA', 'France', 'EUR'),
  ('GA', 'GAB', 'Gabon', 'XAF'),
  ('GB', 'GBR', 'United Kingdom', 'GBP'),
  ('GD', 'GRD', 'Grenada', 'XCD'),
  ('GE', 'GEO', 'Georgia', 'GEL'),
  ('GG', 'GGY', 'Guernsey', 'GBP'),
  ('GH', 'GHA', 'Ghana', 'GHS'),
  ('GI', 'GIB', 'Gibraltar', 'GIP'),
  ('GL', 'GRL', 'Greenland', 'DKK'),
  ('GM', 'GMB', 'Gambia', 'GMD'),
  ('GN', 'GIN', 'Guinea', 'GNF'),
  ('GQ', 'GNQ', 'Equatorial Guinea', 'XAF'),
  ('GR', 'GRC', 'Greece', 'EUR'),
  ('GT', 'GTM', 'Guatemala', 'GTQ'),
  ('GU', 'GUM', 'Guam', 'USD'),
  ('GW', 'GNB', 'Guinea-Bissau', 'XOF'),
  ('GY', 'GUY', 'Guyana', 'GYD'),
  ('HK', 'HKG', 'Hong Kong', 'HKD'),
  ('HN', 'HND', 'Honduras', 'HNL'),
  ('HR', 'HRV', 'Croatia', 'EUR'),
  ('HT', 'HTI', 'Haiti', 'HTG'),
  ('HU', 'HUN', 'Hungary', 'HUF'),
  ('ID', 'IDN', 'Indonesia', 'IDR'),
  ('IE', 'IRL', 'Ireland', 'EUR'),
  ('IL', 'ISR', 'Israel', 'ILS'),
  ('IM', 'IMN', 'Isle of Man', 'GBP'),
  ('IN', 'IND', 'India', 'INR'),
  ('IQ', 'IRQ', 'Iraq', 'IQD'),
  ('IR', 'IRN', 'Iran', 'IRR'),
  ('IS', 'ISL', 'Iceland', 'ISK'),
  ('IT', 'ITA', 'Italy', 'EUR'),
  ('JE', 'JEY', 'Jersey', 'GBP'),
  ('JM', 'JAM', 'Jamaica', 'JMD'),
  ('JO', 'JOR', 'Jordan', 'JOD'),
  ('JP', 'JPN', 'Japan', 'JPY'),
  ('KE', 'KEN', 'Kenya', 'KES'),
  ('KG', 'KGZ', 'Kyrgyzstan', 'KGS'),
  ('KH', 'KHM', 'Cambodia', 'KHR'),
  ('KI', 'KIR', 'Kiribati', 'AUD'),
  ('KM', 'COM', 'Comoros', 'KMF'),
  ('KN', 'KNA', 'St Kitts and Nevis', 'XCD'),
  ('KP', 'PRK', 'North Korea', 'USD'),
  ('KR', 'KOR', 'South Korea', 'KRW'),
  ('KW', 'KWT', 'Kuwait', 'KWD'),
  ('KY', 'CYM', 'Cayman Islands', 'KYD'),
  ('KZ', 'KAZ', 'Kazakhstan', 'KZT'),
  ('LA', 'LAO', 'Laos', 'LAK'),
  ('LB', 'LBN', 'Lebanon', 'LBP'),
  ('LC', 'LCA', 'St Lucia', 'XCD'),
  ('LI', 'LIE', 'Liechtenstein', 'CHF'),
  ('LK', 'LKA', 'Sri Lanka', 'LKR'),
  ('LR', 'LBR', 'Liberia', 'LRD'),
  ('LS', 'LSO', 'Lesotho', 'LSL'),
  ('LT', 'LTU', 'Lithuania', 'EUR'),
  ('LU', 'LUX', 'Luxembourg', 'EUR'),
  ('LV', 'LVA', 'Latvia', 'EUR'),
  ('LY', 'LBY', 'Libya', 'LYD'),
  ('MA', 'MAR', 'Morocco', 'MAD'),
  ('MC', 'MCO', 'Monaco', 'EUR'),
  ('MD', 'MDA', 'Moldova', 'MDL'),
  ('ME', 'MNE', 'Montenegro', 'EUR'),
  ('MF', 'MAF', 'St Martin (French part)', 'EUR'),
  ('MG', 'MDG', 'Madagascar', 'MGA'),
  ('MH', 'MHL', 'Marshall Islands', 'USD'),
  ('MK', 'MKD', 'North Macedonia', 'MKD'),
  ('ML', 'MLI', 'Mali', 'XOF'),
  ('MM', 'MMR', 'Myanmar', 'MMK'),
  ('MN', 'MNG', 'Mongolia', 'MNT'),
  ('MO', 'MAC', 'Macau', 'MOP'),
  ('MP', 'MNP', 'Northern Mariana Islands', 'USD'),
  ('MR', 'MRT', 'Mauritania', 'MRU'),
  ('MT', 'MLT', 'Malta', 'EUR'),
  ('MU', 'MUS', 'Mauritius', 'MUR'),
  ('MV', 'MDV', 'Maldives', 'MVR'),
  ('MW', 'MWI', 'Malawi', 'MWK'),
  ('MX', 'MEX', 'Mexico', 'MXN'),
  ('MY', 'MYS', 'Malaysia', 'MYR'),
  ('MZ', 'MOZ', 'Mozambique', 'MZN'),
  ('NA', 'NAM', 'Namibia', 'NAD'),
  ('NC', 'NCL', 'New Caledonia', 'XPF'),
  ('NE', 'NER', 'Niger', 'XOF'),
  ('NG', 'NGA', 'Nigeria', 'NGN'),
  ('NI', 'NIC', 'Nicaragua', 'NIO'),
  ('NL', 'NLD', 'Netherlands', 'EUR'),
  ('NO', 'NOR', 'Norway', 'NOK'),
  ('NP', 'NPL', 'Nepal', 'NPR'),
  ('NR', 'NRU', 'Nauru', 'AUD'),
  ('NZ', 'NZL', 'New Zealand', 'NZD'),
  ('OM', 'OMN', 'Oman', 'OMR'),
  ('PA', 'PAN', 'Panama', 'USD'),
  ('PE', 'PER', 'Peru', 'PEN'),
  ('PF', 'PYF', 'French Polynesia', 'XPF'),
  ('PG', 'PNG', 'Papua New Guinea', 'PGK'),
  ('PH', 'PHL', 'Philippines', 'PHP'),
  ('PK', 'PAK', 'Pakistan', 'PKR'),
  ('PL', 'POL', 'Poland', 'PLN'),
  ('PR', 'PRI', 'Puerto Rico', 'USD'),
  ('PS', 'PSE', 'Palestine', 'ILS'),
  ('PT', 'PRT', 'Portugal', 'EUR'),
  ('PW', 'PLW', 'Palau', 'USD'),
  ('PY', 'PRY', 'Paraguay', 'PYG'),
  ('QA', 'QAT', 'Qatar', 'QAR'),
  ('RO', 'ROU', 'Romania', 'RON'),
  ('RS', 'SRB', 'Serbia', 'RSD'),
  ('RU', 'RUS', 'Russia', 'RUB'),
  ('RW', 'RWA', 'Rwanda', 'RWF'),
  ('SA', 'SAU', 'Saudi Arabia', 'SAR'),
  ('SB', 'SLB', 'Solomon Islands', 'SBD'),
  ('SC', 'SYC', 'Seychelles', 'SCR'),
  ('SD', 'SDN', 'Sudan', 'SDG'),
  ('SE', 'SWE', 'Sweden', 'SEK'),
  ('SG', 'SGP', 'Singapore', 'SGD'),
  ('SI', 'SVN', 'Slovenia', 'EUR'),
  ('SK', 'SVK', 'Slovakia', 'EUR'),
  ('SL', 'SLE', 'Sierra Leone', 'SLE'),
  ('SM', 'SMR', 'San Marino', 'EUR'),
  ('SN', 'SEN', 'Senegal', 'XOF'),
  ('SO', 'SOM', 'Somalia', 'SOS'),
  ('SR', 'SUR', 'Suriname', 'SRD'),
  ('SS', 'SSD', 'South Sudan', 'SSP'),
  ('ST', 'STP', 'São Tomé and Príncipe', 'STN'),
  ('SV', 'SLV', 'El Salvador', 'USD'),
  ('SX', 'SXM', 'Sint Maarten', 'XCG'),
  ('SY', 'SYR', 'Syria', 'SYP'),
  ('SZ', 'SWZ', 'Eswatini', 'SZL'),
  ('TC', 'TCA', 'Turks and Caicos Islands', 'USD'),
  ('TD', 'TCD', 'Chad', 'XAF'),
  ('TG', 'TGO', 'Togo', 'XOF'),
  ('TH', 'THA', 'Thailand', 'THB'),
  ('TJ', 'TJK', 'Tajikistan', 'TJS'),
  ('TL', 'TLS', 'Timor-Leste', 'USD'),
  ('TM', 'TKM', 'Turkmenistan', 'TMT'),
  ('TN', 'TUN', 'Tunisia', 'TND'),
  ('TO', 'TON', 'Tonga', 'TOP'),
  ('TR', 'TUR', 'Türkiye', 'TRY'),
  ('TT', 'TTO', 'Trinidad and Tobago', 'TTD'),
  ('TV', 'TUV', 'Tuvalu', 'AUD'),
  ('TW', 'TWN', 'Taiwan', 'TWD'),
  ('TZ', 'TZA', 'Tanzania', 'TZS'),
  ('UA', 'UKR', 'Ukraine', 'UAH'),
  ('UG', 'UGA', 'Uganda', 'UGX'),
  ('US', 'USA', 'United States', 'USD'),
  ('UY', 'URY', 'Uruguay', 'UYU'),
  ('UZ', 'UZB', 'Uzbekistan', 'UZS'),
  ('VA', 'VAT', 'Vatican City (Holy See)', 'EUR'),
  ('VC', 'VCT', 'St Vincent and the Grenadines', 'XCD'),
  ('VE', 'VEN', 'Venezuela', 'VES'),
  ('VG', 'VGB', 'British Virgin Islands', 'USD'),
  ('VI', 'VIR', 'US Virgin Islands', 'USD'),
  ('VN', 'VNM', 'Vietnam', 'VND'),
  ('VU', 'VUT', 'Vanuatu', 'VUV'),
  ('WS', 'WSM', 'Samoa', 'WST'),
  ('XK', 'XKX', 'Kosovo', 'EUR'),
  ('YE', 'YEM', 'Yemen', 'YER'),
  ('ZA', 'ZAF', 'South Africa', 'ZAR'),
  ('ZM', 'ZMB', 'Zambia', 'ZMW'),
  ('ZW', 'ZWE', 'Zimbabwe', 'USD')
on conflict (code) do update
set iso3 = excluded.iso3, name = excluded.name, currency = excluded.currency;

-- 'KE', 'ke' and 'KEN' are all Kenya (Apple's storefronts use three
-- letters, Google Play two). Null for anything else.
create or replace function public.country_code_of(p_code text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select c.code from public.countries c
  where c.code = case upper(trim(coalesce(p_code, ''))) when 'UK' then 'GB' else upper(trim(coalesce(p_code, ''))) end
     or c.iso3 = upper(trim(coalesce(p_code, '')))
  limit 1;
$$;

-- ── 2. Prices ────────────────────────────────────────────────────────

alter table public.therapy_prices
  add column if not exists concession_minor integer check (concession_minor > 0),
  add column if not exists upper_minor integer check (upper_minor > 0),
  add column if not exists basis text
    check (basis in ('researched', 'researched_thin', 'modelled', 'modelled_weak', 'set_by_admin')),
  add column if not exists note text check (length(note) <= 500),
  add column if not exists payment_fee_rate numeric(5, 4) check (payment_fee_rate between 0 and 0.5),
  -- Shillings for one unit of the price's currency, at the sheet's rates,
  -- so the admin page can suggest what to charge for a new price.
  add column if not exists kes_per_unit numeric(18, 8) check (kes_per_unit > 0);

-- Lebanese pounds run to hundreds of millions of minor units.
alter table public.therapy_prices drop constraint if exists therapy_prices_price_minor_check;
alter table public.therapy_prices
  add constraint therapy_prices_price_minor_check check (price_minor between 100 and 1000000000);

insert into public.therapy_prices as p (
  country_code, currency, price_minor, charge_currency, charge_minor,
  concession_minor, upper_minor, basis, note, payment_fee_rate, kes_per_unit, updated_by, updated_at
)
select v.code, v.currency, v.price_minor, v.charge_currency, v.charge_minor,
       v.concession_minor, v.upper_minor, v.basis, v.note, v.fee_rate, v.kes_per_unit,
       'Pricing sheet, 16 Nov 2026', now()
from (values
  ('AD', 'EUR', 4500, 'KES', 645000, 3000, 6500, 'modelled', null, 0.035, 143.42086953),
  ('AE', 'AED', 18000, 'KES', 637000, 12000, 25000, 'modelled', null, 0.035, 35.40603376),
  ('AF', 'AFN', 75000, 'KES', 150000, 50000, 100000, 'modelled', null, 0.035, 2.00281264),
  ('AG', 'XCD', 12000, 'KES', 578000, 8000, 18000, 'modelled', null, 0.035, 48.15876259),
  ('AL', 'ALL', 250000, 'KES', 396000, 150000, 350000, 'modelled', null, 0.035, 1.58280429),
  ('AM', 'AMD', 1000000, 'KES', 361000, 650000, 1500000, 'modelled', null, 0.035, 0.36077949),
  ('AO', 'USD', 2000, 'KES', 260000, 1300, 2700, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (20% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('AR', 'USD', 3200, 'KES', 416000, 2300, 4500, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (220% in 2024): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('AS', 'USD', 3500, 'KES', 455000, 2200, 5000, 'modelled_weak', 'Income data is from 2022; Local price level estimated from income', 0.035, 130.02865900),
  ('AT', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('AU', 'AUD', 8500, 'KES', 749000, 5500, 12000, 'modelled', null, 0.035, 88.11661018),
  ('AW', 'AWG', 8500, 'KES', 617000, 5500, 12000, 'modelled', null, 0.035, 72.64170894),
  ('AZ', 'AZN', 4000, 'KES', 306000, 2500, 5500, 'modelled', null, 0.035, 76.45906666),
  ('BA', 'BAM', 5000, 'KES', 367000, 3500, 7000, 'modelled', null, 0.035, 73.31882260),
  ('BB', 'BBD', 12000, 'KES', 780000, 8000, 18000, 'modelled', null, 0.035, 65.01432950),
  ('BD', 'BDT', 250000, 'KES', 260000, 150000, 350000, 'modelled', null, 0.035, 1.04096093),
  ('BE', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('BF', 'XOF', 1000000, 'KES', 219000, 650000, 1500000, 'modelled', null, 0.035, 0.21861058),
  ('BG', 'EUR', 3000, 'KES', 430000, 2000, 4000, 'modelled', null, 0.035, 143.42086953),
  ('BH', 'BHD', 1200, 'KES', 415000, 800, 1800, 'modelled', null, 0.035, 345.82090160),
  ('BI', 'USD', 1200, 'KES', 156000, 700, 1700, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (34% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('BJ', 'XOF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('BM', 'BMD', 7500, 'KES', 975000, 5000, 10000, 'modelled', null, 0.035, 130.02865900),
  ('BN', 'BND', 4500, 'KES', 454000, 3000, 6500, 'modelled', null, 0.035, 100.96419667),
  ('BO', 'BOB', 28000, 'KES', 311000, 18000, 40000, 'modelled', null, 0.035, 11.11453906),
  ('BR', 'BRL', 18000, 'KES', 413000, 12000, 25000, 'modelled', null, 0.035, 22.95883294),
  ('BS', 'BSD', 5500, 'KES', 715000, 3500, 7500, 'modelled', null, 0.035, 130.02865900),
  ('BT', 'BTN', 180000, 'KES', 248000, 120000, 250000, 'modelled', null, 0.035, 1.37745237),
  ('BW', 'BWP', 35000, 'KES', 326000, 22000, 50000, 'modelled', null, 0.035, 9.31820259),
  ('BY', 'BYN', 7000, 'KES', 303000, 4500, 10000, 'modelled', null, 0.035, 43.34037259),
  ('BZ', 'BZD', 6500, 'KES', 423000, 4000, 9000, 'modelled', null, 0.035, 65.01432950),
  ('CA', 'CAD', 8000, 'KES', 729000, 5000, 12000, 'modelled', null, 0.035, 91.14475644),
  ('CD', 'CDF', 4500000, 'KES', 254000, 3000000, 6500000, 'modelled', null, 0.035, 0.05647264),
  ('CF', 'XAF', 1000000, 'KES', 219000, 650000, 1500000, 'modelled', null, 0.035, 0.21861058),
  ('CG', 'XAF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('CH', 'CHF', 5500, 'KES', 852000, 3500, 7500, 'modelled', null, 0.035, 154.96076067),
  ('CI', 'XOF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('CL', 'CLP', 3500000, 'KES', 457000, 2200000, 5000000, 'modelled', null, 0.035, 0.13063276),
  ('CM', 'XAF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('CN', 'CNY', 22000, 'KES', 428000, 15000, 30000, 'modelled', null, 0.035, 19.47003451),
  ('CO', 'COP', 8500000, 'KES', 333000, 5500000, 12000000, 'modelled', null, 0.035, 0.03920499),
  ('CR', 'CRC', 1800000, 'KES', 520000, 1200000, 2500000, 'modelled', null, 0.035, 0.28913565),
  ('CU', 'CUP', 75000, 'KES', 406000, 50000, 100000, 'modelled_weak', 'Income data is from 2020; Local price level estimated from income; Stripe, Paystack and similar processors do not operate here; price is indicative only', 0.035, 5.41786079),
  ('CV', 'CVE', 280000, 'KES', 364000, 180000, 400000, 'modelled', null, 0.035, 1.30049555),
  ('CW', 'XCG', 7500, 'KES', 545000, 5000, 10000, 'modelled', null, 0.035, 72.64170894),
  ('CY', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('CZ', 'CZK', 90000, 'KES', 529000, 60000, 120000, 'modelled', null, 0.035, 5.87530812),
  ('DE', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('DJ', 'DJF', 450000, 'KES', 329000, 300000, 650000, 'modelled', null, 0.035, 0.73164488),
  ('DK', 'DKK', 40000, 'KES', 769000, 25000, 55000, 'modelled', null, 0.035, 19.22067568),
  ('DM', 'XCD', 8500, 'KES', 409000, 5500, 12000, 'modelled', null, 0.035, 48.15876259),
  ('DO', 'DOP', 180000, 'KES', 385000, 120000, 250000, 'modelled', null, 0.035, 2.13747422),
  ('DZ', 'DZD', 300000, 'KES', 285000, 200000, 400000, 'modelled', null, 0.035, 0.94941399),
  ('EC', 'USD', 2800, 'KES', 364000, 1800, 4000, 'modelled', null, 0.035, 130.02865900),
  ('EE', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('EG', 'EGP', 85000, 'KES', 206000, 55000, 120000, 'modelled', null, 0.035, 2.41953221),
  ('ER', 'ERN', 22000, 'KES', 191000, 15000, 30000, 'modelled_weak', 'Income data is from 2011; Local price level estimated from income', 0.035, 8.66857727),
  ('ES', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('ET', 'ETB', 280000, 'KES', 225000, 180000, 400000, 'modelled', null, 0.035, 0.80471404),
  ('FI', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('FJ', 'FJD', 6000, 'KES', 344000, 4000, 8500, 'modelled', null, 0.035, 57.34015281),
  ('FM', 'USD', 4000, 'KES', 520000, 2500, 5500, 'modelled', null, 0.035, 130.02865900),
  ('FO', 'DKK', 40000, 'KES', 769000, 25000, 55000, 'modelled', null, 0.035, 19.22067568),
  ('FR', 'EUR', 4500, 'KES', 645000, 3000, 6500, 'modelled', null, 0.035, 143.42086953),
  ('GA', 'XAF', 1500000, 'KES', 328000, 1000000, 2200000, 'modelled', null, 0.035, 0.21861058),
  ('GB', 'GBP', 4000, 'KES', 687000, 2500, 5500, 'researched', 'Set by hand from market research (pricing workbook, "Start here" sheet)', 0.025, 171.86736218),
  ('GD', 'XCD', 9500, 'KES', 458000, 6000, 12000, 'modelled', null, 0.035, 48.15876259),
  ('GE', 'GEL', 6500, 'KES', 326000, 4000, 9000, 'modelled', null, 0.035, 50.13628628),
  ('GG', 'GBP', 4000, 'KES', 687000, 2500, 5500, 'modelled_weak', 'Local price level estimated from income', 0.035, 171.86736218),
  ('GH', 'GHS', 25000, 'KES', 277000, 15000, 35000, 'modelled', null, 0.035, 11.09541438),
  ('GI', 'GIP', 4000, 'KES', 687000, 2500, 5500, 'modelled_weak', 'No income data; priced like United Kingdom', 0.035, 171.84260440),
  ('GL', 'DKK', 35000, 'KES', 673000, 22000, 50000, 'modelled', null, 0.035, 19.22067568),
  ('GM', 'GMD', 120000, 'KES', 209000, 80000, 180000, 'modelled', null, 0.035, 1.73805521),
  ('GN', 'GNF', 18000000, 'KES', 265000, 12000000, 25000000, 'modelled', null, 0.035, 0.01472348),
  ('GQ', 'XAF', 1500000, 'KES', 328000, 1000000, 2200000, 'modelled', null, 0.035, 0.21861058),
  ('GR', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('GT', 'GTQ', 20000, 'KES', 340000, 12000, 28000, 'modelled', null, 0.035, 16.99238138),
  ('GU', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled_weak', 'Income data is from 2022; Local price level estimated from income', 0.035, 130.02865900),
  ('GW', 'XOF', 1000000, 'KES', 219000, 650000, 1500000, 'modelled', null, 0.035, 0.21861058),
  ('GY', 'GYD', 650000, 'KES', 404000, 400000, 900000, 'modelled', null, 0.035, 0.62138734),
  ('HK', 'HKD', 40000, 'KES', 663000, 25000, 55000, 'modelled', null, 0.035, 16.57362741),
  ('HN', 'HNL', 70000, 'KES', 338000, 45000, 100000, 'modelled', null, 0.035, 4.82964091),
  ('HR', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('HT', 'USD', 2700, 'KES', 351000, 1700, 3800, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (29% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('HU', 'HUF', 1200000, 'KES', 472000, 800000, 1800000, 'modelled', null, 0.035, 0.39296732),
  ('ID', 'IDR', 40000000, 'KES', 285000, 25000000, 55000000, 'modelled', null, 0.035, 0.00713585),
  ('IE', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('IL', 'ILS', 18000, 'KES', 729000, 12000, 25000, 'modelled', null, 0.035, 40.49518400),
  ('IM', 'GBP', 4000, 'KES', 687000, 2500, 5500, 'modelled_weak', 'Local price level estimated from income', 0.035, 171.86736218),
  ('IN', 'INR', 180000, 'KES', 248000, 120000, 250000, 'modelled', null, 0.035, 1.37742769),
  ('IQ', 'IQD', 4000000, 'KES', 344000, 2500000, 5500000, 'modelled', null, 0.035, 0.08588360),
  ('IR', 'USD', 2100, 'KES', 273000, 1300, 3000, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (42% in 2025): price in US dollars or re-check monthly; Stripe, Paystack and similar processors do not operate here; price is indicative only', 0.035, 130.02865900),
  ('IS', 'ISK', 800000, 'KES', 843000, 500000, 1200000, 'modelled', null, 0.035, 1.05327251),
  ('IT', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('JE', 'GBP', 4000, 'KES', 687000, 2500, 5500, 'modelled_weak', 'Local price level estimated from income', 0.035, 171.86736218),
  ('JM', 'JMD', 550000, 'KES', 451000, 350000, 750000, 'modelled', null, 0.035, 0.81922132),
  ('JO', 'JOD', 1800, 'KES', 330000, 1200, 2500, 'modelled', null, 0.035, 183.39726234),
  ('JP', 'JPY', 700000, 'KES', 570000, 450000, 1000000, 'modelled', null, 0.035, 0.81377612),
  ('KE', 'KES', 260000, 'KES', 260000, 150000, 350000, 'researched', 'Set by hand from market research (pricing workbook, "Start here" sheet)', 0.025, 1.00000000),
  ('KG', 'KGS', 180000, 'KES', 268000, 120000, 250000, 'modelled', null, 0.035, 1.48634680),
  ('KH', 'KHR', 8500000, 'KES', 272000, 5500000, 12000000, 'modelled', null, 0.035, 0.03199436),
  ('KI', 'AUD', 4500, 'KES', 397000, 3000, 6500, 'modelled', null, 0.035, 88.11661018),
  ('KM', 'KMF', 1000000, 'KES', 291000, 650000, 1500000, 'modelled', null, 0.035, 0.29148078),
  ('KN', 'XCD', 12000, 'KES', 578000, 8000, 18000, 'modelled', null, 0.035, 48.15876259),
  ('KP', 'USD', 1500, 'KES', 195000, 1000, 2200, 'modelled_weak', 'No reliable income data; priced like a typical low-income country; Local price level estimated from income; No live rate for KPW; priced in US dollars; Stripe, Paystack and similar processors do not operate here; price is indicative only', 0.035, 130.02865900),
  ('KR', 'KRW', 5500000, 'KES', 535000, 3500000, 7500000, 'modelled', null, 0.035, 0.09733328),
  ('KW', 'KWD', 1500, 'KES', 628000, 1000, 2200, 'modelled', null, 0.035, 418.39320615),
  ('KY', 'KYD', 5500, 'KES', 858000, 3500, 7500, 'modelled', null, 0.035, 156.03445321),
  ('KZ', 'KZT', 1200000, 'KES', 350000, 800000, 1800000, 'modelled', null, 0.035, 0.29183457),
  ('LA', 'LAK', 35000000, 'KES', 203000, 22000000, 50000000, 'modelled', null, 0.035, 0.00580386),
  ('LB', 'LBP', 180000000, 'KES', 262000, 120000000, 250000000, 'modelled', null, 0.035, 0.00145283),
  ('LC', 'XCD', 9000, 'KES', 433000, 6000, 12000, 'modelled', null, 0.035, 48.15876259),
  ('LI', 'CHF', 6500, 'KES', 1007000, 4000, 9000, 'modelled', null, 0.035, 154.96076067),
  ('LK', 'LKR', 700000, 'KES', 274000, 450000, 1000000, 'modelled', null, 0.035, 0.39089623),
  ('LR', 'LRD', 350000, 'KES', 267000, 220000, 500000, 'modelled', null, 0.035, 0.76334759),
  ('LS', 'LSL', 30000, 'KES', 230000, 20000, 40000, 'modelled', null, 0.035, 7.67781919),
  ('LT', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('LU', 'EUR', 5500, 'KES', 789000, 3500, 7500, 'modelled', null, 0.035, 143.42086953),
  ('LV', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('LY', 'LYD', 18000, 'KES', 363000, 12000, 25000, 'modelled', null, 0.035, 20.17523434),
  ('MA', 'MAD', 25000, 'KES', 328000, 15000, 35000, 'modelled', null, 0.035, 13.10435784),
  ('MC', 'EUR', 7000, 'KES', 1004000, 4500, 10000, 'modelled_weak', 'Local price level estimated from income', 0.035, 143.42086953),
  ('MD', 'MDL', 50000, 'KES', 357000, 35000, 70000, 'modelled', null, 0.035, 7.13715858),
  ('ME', 'EUR', 2800, 'KES', 402000, 1800, 4000, 'modelled', null, 0.035, 143.42086953),
  ('MF', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled_weak', 'Income data is from 2021; Local price level estimated from income', 0.035, 143.42086953),
  ('MG', 'MGA', 7000000, 'KES', 198000, 4500000, 10000000, 'modelled', null, 0.035, 0.02828183),
  ('MH', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled', null, 0.035, 130.02865900),
  ('MK', 'MKD', 150000, 'KES', 355000, 100000, 220000, 'modelled', null, 0.035, 2.36994838),
  ('ML', 'XOF', 1000000, 'KES', 219000, 650000, 1500000, 'modelled', null, 0.035, 0.21861058),
  ('MM', 'USD', 1700, 'KES', 221000, 1000, 2400, 'modelled', 'Priced in US dollars, as the sheet advises. Unstable currency and no recent inflation data: price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('MN', 'MNT', 9000000, 'KES', 324000, 6000000, 12000000, 'modelled', null, 0.035, 0.03601883),
  ('MO', 'MOP', 35000, 'KES', 563000, 22000, 50000, 'modelled', null, 0.035, 16.09084361),
  ('MP', 'USD', 4000, 'KES', 520000, 2500, 5500, 'modelled_weak', 'Income data is from 2022; Local price level estimated from income', 0.035, 130.02865900),
  ('MR', 'MRU', 80000, 'KES', 256000, 50000, 120000, 'modelled', null, 0.035, 3.19612270),
  ('MT', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('MU', 'MUR', 150000, 'KES', 409000, 100000, 220000, 'modelled', null, 0.035, 2.72766290),
  ('MV', 'MVR', 50000, 'KES', 421000, 35000, 70000, 'modelled', null, 0.035, 8.42224076),
  ('MW', 'USD', 1600, 'KES', 208000, 1000, 2300, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (28% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('MX', 'MXN', 65000, 'KES', 456000, 40000, 90000, 'modelled', null, 0.035, 7.01155363),
  ('MY', 'MYR', 10000, 'KES', 318000, 6500, 15000, 'modelled', null, 0.035, 31.81049114),
  ('MZ', 'MZN', 120000, 'KES', 245000, 80000, 180000, 'modelled', null, 0.035, 2.04285815),
  ('NA', 'NAD', 40000, 'KES', 307000, 25000, 55000, 'modelled', null, 0.035, 7.67781919),
  ('NC', 'XPF', 450000, 'KES', 541000, 300000, 650000, 'modelled_weak', 'Local price level estimated from income', 0.035, 1.20168221),
  ('NE', 'XOF', 1000000, 'KES', 219000, 650000, 1500000, 'modelled', null, 0.035, 0.21861058),
  ('NG', 'USD', 1300, 'KES', 169000, 900, 1800, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (23% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('NI', 'NIO', 80000, 'KES', 282000, 50000, 120000, 'modelled', null, 0.035, 3.52954660),
  ('NL', 'EUR', 5000, 'KES', 717000, 3500, 7000, 'modelled', null, 0.035, 143.42086953),
  ('NO', 'NOK', 60000, 'KES', 815000, 40000, 85000, 'modelled', null, 0.035, 13.59012794),
  ('NP', 'NPR', 250000, 'KES', 215000, 150000, 350000, 'modelled', null, 0.035, 0.86090773),
  ('NR', 'AUD', 7500, 'KES', 661000, 5000, 10000, 'modelled', null, 0.035, 88.11661018),
  ('NZ', 'NZD', 9500, 'KES', 683000, 6000, 12000, 'modelled', null, 0.035, 71.86913580),
  ('OM', 'OMR', 1500, 'KES', 507000, 1000, 2200, 'modelled', null, 0.035, 338.17860477),
  ('PA', 'USD', 3500, 'KES', 455000, 2200, 5000, 'modelled', null, 0.035, 130.02865900),
  ('PE', 'PEN', 10000, 'KES', 381000, 6500, 15000, 'modelled', null, 0.035, 38.13936720),
  ('PF', 'XPF', 450000, 'KES', 541000, 300000, 650000, 'modelled_weak', 'Local price level estimated from income', 0.035, 1.20168221),
  ('PG', 'PGK', 12000, 'KES', 342000, 8000, 18000, 'modelled', null, 0.035, 28.45909349),
  ('PH', 'PHP', 150000, 'KES', 305000, 100000, 220000, 'modelled', null, 0.035, 2.03453461),
  ('PK', 'PKR', 450000, 'KES', 211000, 300000, 650000, 'modelled', null, 0.035, 0.46956697),
  ('PL', 'PLN', 15000, 'KES', 488000, 10000, 22000, 'modelled', null, 0.035, 32.54083638),
  ('PR', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled', null, 0.035, 130.02865900),
  ('PS', 'ILS', 9500, 'KES', 385000, 6000, 12000, 'modelled', null, 0.035, 40.49518400),
  ('PT', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('PW', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled', null, 0.035, 130.02865900),
  ('PY', 'PYG', 15000000, 'KES', 315000, 10000000, 22000000, 'modelled', null, 0.035, 0.02096899),
  ('QA', 'QAR', 18000, 'KES', 643000, 12000, 25000, 'modelled', null, 0.035, 35.72215907),
  ('RO', 'RON', 15000, 'KES', 403000, 10000, 22000, 'modelled', null, 0.035, 26.86256710),
  ('RS', 'RSD', 350000, 'KES', 427000, 220000, 500000, 'modelled', null, 0.035, 1.22061334),
  ('RU', 'RUB', 220000, 'KES', 346000, 150000, 300000, 'modelled', 'Stripe, Paystack and similar processors do not operate here; price is indicative only', 0.035, 1.57479168),
  ('RW', 'RWF', 2500000, 'KES', 220000, 1500000, 3500000, 'modelled', null, 0.035, 0.08795300),
  ('SA', 'SAR', 15000, 'KES', 520000, 10000, 22000, 'modelled', null, 0.035, 34.67430907),
  ('SB', 'SBD', 25000, 'KES', 407000, 15000, 35000, 'modelled', null, 0.035, 16.26213422),
  ('SC', 'SCR', 55000, 'KES', 489000, 35000, 75000, 'modelled', null, 0.035, 8.89526540),
  ('SD', 'USD', 2000, 'KES', 260000, 1300, 2600, 'modelled', 'Priced in US dollars, as the sheet advises. Unstable currency and no recent inflation data: price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('SE', 'SEK', 55000, 'KES', 710000, 35000, 75000, 'modelled', null, 0.035, 12.91152461),
  ('SG', 'SGD', 6500, 'KES', 656000, 4000, 9000, 'modelled', null, 0.035, 100.98285844),
  ('SI', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', null, 0.035, 143.42086953),
  ('SK', 'EUR', 3500, 'KES', 502000, 2200, 5000, 'modelled', null, 0.035, 143.42086953),
  ('SL', 'SLE', 35000, 'KES', 197000, 22000, 50000, 'modelled', null, 0.035, 5.63743171),
  ('SM', 'EUR', 4500, 'KES', 645000, 3000, 6500, 'modelled', null, 0.035, 143.42086953),
  ('SN', 'XOF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('SO', 'SOS', 1000000, 'KES', 227000, 650000, 1500000, 'modelled', null, 0.035, 0.22736020),
  ('SR', 'SRD', 85000, 'KES', 294000, 55000, 120000, 'modelled', null, 0.035, 3.46193815),
  ('SS', 'USD', 1600, 'KES', 208000, 1000, 2100, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (91% in 2024): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('ST', 'STN', 65000, 'KES', 380000, 40000, 90000, 'modelled', null, 0.035, 5.85302622),
  ('SV', 'USD', 2500, 'KES', 325000, 1500, 3500, 'modelled', null, 0.035, 130.02865900),
  ('SX', 'XCG', 8500, 'KES', 617000, 5500, 12000, 'modelled', null, 0.035, 72.64170894),
  ('SY', 'USD', 1500, 'KES', 195000, 1000, 2100, 'modelled_weak', 'Priced in US dollars, as the sheet advises. Income data is from 2022; Local price level estimated from income; Unstable currency and no recent inflation data: price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('SZ', 'SZL', 40000, 'KES', 307000, 25000, 55000, 'modelled', null, 0.035, 7.67781919),
  ('TC', 'USD', 5500, 'KES', 715000, 3500, 7500, 'modelled', null, 0.035, 130.02865900),
  ('TD', 'XAF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('TG', 'XOF', 1200000, 'KES', 262000, 800000, 1800000, 'modelled', null, 0.035, 0.21861058),
  ('TH', 'THB', 80000, 'KES', 307000, 50000, 120000, 'modelled', null, 0.035, 3.83611218),
  ('TJ', 'TJS', 15000, 'KES', 212000, 10000, 22000, 'modelled', null, 0.035, 14.11913456),
  ('TL', 'USD', 1800, 'KES', 234000, 1200, 2500, 'modelled', null, 0.035, 130.02865900),
  ('TM', 'TMT', 7500, 'KES', 279000, 5000, 10000, 'modelled', null, 0.035, 37.14432761),
  ('TN', 'TND', 6500, 'KES', 281000, 4000, 9000, 'modelled', null, 0.035, 43.23761715),
  ('TO', 'TOP', 9000, 'KES', 489000, 6000, 12000, 'modelled', null, 0.035, 54.28181121),
  ('TR', 'USD', 3000, 'KES', 390000, 2000, 4400, 'modelled', 'Priced in US dollars, as the sheet advises. High inflation (35% in 2025): price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('TT', 'TTD', 25000, 'KES', 478000, 15000, 35000, 'modelled', null, 0.035, 19.13747836),
  ('TV', 'AUD', 6500, 'KES', 573000, 4000, 9000, 'modelled', null, 0.035, 88.11661018),
  ('TW', 'TWD', 120000, 'KES', 474000, 80000, 180000, 'modelled', null, 0.035, 3.94991707),
  ('TZ', 'TZS', 4000000, 'KES', 197000, 2500000, 5500000, 'researched_thin', 'Set by hand from market research (pricing workbook, "Start here" sheet)', 0.04, 0.04925222),
  ('UA', 'UAH', 100000, 'KES', 286000, 65000, 150000, 'modelled', null, 0.035, 2.86163480),
  ('UG', 'UGX', 7500000, 'KES', 239000, 5000000, 10000000, 'modelled', null, 0.035, 0.03191290),
  ('US', 'USD', 6500, 'KES', 845000, 4500, 9000, 'researched', 'Set by hand from market research (pricing workbook, "Start here" sheet)', 0.036, 130.02865900),
  ('UY', 'UYU', 180000, 'KES', 576000, 120000, 250000, 'modelled', null, 0.035, 3.19922526),
  ('UZ', 'UZS', 25000000, 'KES', 273000, 15000000, 35000000, 'modelled', null, 0.035, 0.01090949),
  ('VA', 'EUR', 4000, 'KES', 574000, 2500, 5500, 'modelled', 'Priced as Italy', 0.035, 143.42086953),
  ('VC', 'XCD', 9000, 'KES', 433000, 6000, 12000, 'modelled', null, 0.035, 48.15876259),
  ('VE', 'USD', 2400, 'KES', 312000, 1600, 3300, 'modelled', 'Priced in US dollars, as the sheet advises. Unstable currency and no recent inflation data: price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('VG', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled_weak', 'No income data; priced like US Virgin Islands; Local price level estimated from income', 0.035, 130.02865900),
  ('VI', 'USD', 4500, 'KES', 585000, 3000, 6500, 'modelled_weak', 'Income data is from 2022; Local price level estimated from income', 0.035, 130.02865900),
  ('VN', 'VND', 55000000, 'KES', 278000, 35000000, 75000000, 'modelled', null, 0.035, 0.00505638),
  ('VU', 'VUV', 450000, 'KES', 487000, 300000, 650000, 'modelled', null, 0.035, 1.08266760),
  ('WS', 'WST', 9000, 'KES', 423000, 6000, 12000, 'modelled', null, 0.035, 46.99349789),
  ('XK', 'EUR', 2500, 'KES', 359000, 1500, 3500, 'modelled', null, 0.035, 143.42086953),
  ('YE', 'USD', 1500, 'KES', 195000, 900, 2100, 'modelled', 'Priced in US dollars, as the sheet advises. Unstable currency and no recent inflation data: price in US dollars or re-check monthly', 0.035, 130.02865900),
  ('ZA', 'ZAR', 45000, 'KES', 346000, 30000, 65000, 'modelled', null, 0.035, 7.67858408),
  ('ZM', 'ZMW', 35000, 'KES', 220000, 22000, 50000, 'modelled', null, 0.035, 6.29949569),
  ('ZW', 'USD', 2500, 'KES', 325000, 1500, 3500, 'modelled', null, 0.035, 130.02865900)
) as v(code, currency, price_minor, charge_currency, charge_minor,
       concession_minor, upper_minor, basis, note, fee_rate, kes_per_unit)
on conflict (country_code) do update
set currency = excluded.currency, price_minor = excluded.price_minor,
    charge_currency = excluded.charge_currency, charge_minor = excluded.charge_minor,
    concession_minor = excluded.concession_minor, upper_minor = excluded.upper_minor,
    basis = excluded.basis, note = excluded.note, payment_fee_rate = excluded.payment_fee_rate,
    kes_per_unit = excluded.kes_per_unit, updated_by = excluded.updated_by, updated_at = now()
where p.basis is distinct from 'set_by_admin';

update public.therapy_prices set kes_per_unit = 130.0287
 where country_code = '*' and kes_per_unit is null and currency = 'USD';

-- As in 0031, and marks the row as an admin's, so the sheet never
-- overwrites it.
create or replace function public.admin_set_therapy_price(
  p_country text,
  p_currency text,
  p_price_minor integer,
  p_charge_minor integer,
  p_charge_currency text default 'KES'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := upper(trim(coalesce(p_country, '')));
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if v_code <> '*' and public.country_code_of(v_code) is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  insert into public.therapy_prices (country_code, currency, price_minor, charge_currency, charge_minor, basis, updated_by)
  values (v_code, upper(trim(p_currency)), p_price_minor,
          upper(trim(coalesce(p_charge_currency, 'KES'))), p_charge_minor, 'set_by_admin', public.current_user_email())
  on conflict (country_code) do update
  set currency = excluded.currency, price_minor = excluded.price_minor,
      charge_currency = excluded.charge_currency, charge_minor = excluded.charge_minor,
      basis = 'set_by_admin', updated_by = excluded.updated_by, updated_at = now();
end;
$$;

-- ── 3. The client's country ──────────────────────────────────────────

alter table public.therapy_client_countries
  add column if not exists source text check (source in ('store', 'sim', 'region', 'client', 'admin')),
  add column if not exists store_country text,
  add column if not exists sim_country text,
  add column if not exists region_country text,
  add column if not exists platform text check (length(platform) <= 20),
  add column if not exists detected_at timestamptz;

update public.therapy_client_countries
   set source = case when set_by = 'client' then 'client' else 'admin' end
 where source is null;

-- Whether a therapist holds a current licence in a country.
create table if not exists public.therapist_licences (
  id uuid primary key default gen_random_uuid(),
  therapist_id uuid not null references public.therapists (id) on delete cascade,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  number text check (length(number) <= 80),
  issuer text check (length(issuer) <= 160),
  expires_on date,
  document_id uuid references public.therapist_documents (id) on delete set null,
  added_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (therapist_id, country_code)
);
alter table public.therapist_licences enable row level security;
-- No policies: read through the functions below.
create index if not exists therapist_licences_country_idx
  on public.therapist_licences (country_code);

-- How many active therapists hold a current licence in a country.
create or replace function public.therapists_licensed_in(p_country text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct l.therapist_id)::integer
  from public.therapist_licences l
  join public.therapists t on t.id = l.therapist_id
  where l.country_code = p_country
    and t.active
    and (l.expires_on is null or l.expires_on >= current_date);
$$;

-- What the signed-in person would pay, for the app to show. As in 0031,
-- plus where the country came from, the country's name, the price as
-- text, and how many therapists are licensed there. can_change is for
-- older builds, which show a country list: false once a country has been
-- detected or set by the care team.
create or replace function public.therapy_price_quote()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_source text;
  v_locked boolean;
  p public.therapy_prices;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select c.country_code, c.source into v_country, v_source
    from public.therapy_client_countries c where c.user_id = auth.uid();
  v_locked := public.therapy_country_locked(auth.uid());
  p := public.therapy_price_for(v_country);
  return jsonb_build_object(
    'country', v_country,
    'country_name', (select c.name from public.countries c where c.code = v_country),
    'source', v_source,
    'locked', v_locked,
    'can_change', not v_locked and coalesce(v_source, 'client') = 'client',
    'currency', p.currency,
    'price_minor', p.price_minor,
    'charge_currency', p.charge_currency,
    'charge_minor', p.charge_minor,
    'price_label', public.therapy_price_label(p.price_minor, p.currency),
    'charge_label', public.therapy_price_label(p.charge_minor, p.charge_currency),
    'licensed_therapists', case when v_country is null then 0 else public.therapists_licensed_in(v_country) end,
    'priced_countries', (
      select coalesce(jsonb_agg(x.country_code order by x.country_code), '[]')
      from public.therapy_prices x where x.country_code <> '*'
    )
  );
end;
$$;

-- The app reports what the phone knows; the first one recognised wins: the
-- store account's country, then the SIM's, then the region setting. The
-- country only moves while the person hasn't paid for a session and the
-- care team hasn't set it. What was reported is kept either way, so the
-- care team can see it.
create or replace function public.therapy_detect_country(
  p_store text default null,
  p_sim text default null,
  p_region text default null,
  p_platform text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store text := public.country_code_of(p_store);
  v_sim text := public.country_code_of(p_sim);
  v_region text := public.country_code_of(p_region);
  v_pick text := coalesce(public.country_code_of(p_store), public.country_code_of(p_sim), public.country_code_of(p_region));
  v_source text := case
    when public.country_code_of(p_store) is not null then 'store'
    when public.country_code_of(p_sim) is not null then 'sim'
    when public.country_code_of(p_region) is not null then 'region'
  end;
  v_platform text := nullif(left(lower(trim(coalesce(p_platform, ''))), 20), '');
  cur public.therapy_client_countries%rowtype;
  v_move boolean;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;

  insert into public.therapy_client_countries (
    user_id, country_code, set_by, source, store_country, sim_country, region_country, platform, detected_at)
  select auth.uid(), v_pick, 'detected', v_source, v_store, v_sim, v_region, v_platform, now()
  where v_pick is not null
  on conflict (user_id) do nothing;
  if found then
    return public.therapy_price_quote();
  end if;

  select * into cur from public.therapy_client_countries c where c.user_id = auth.uid() for update;
  if not found then
    -- Nothing recognised and nothing on file: the price for everywhere else.
    return public.therapy_price_quote();
  end if;

  v_move := v_pick is not null
            and cur.source is distinct from 'admin'
            and not public.therapy_country_locked(auth.uid());
  update public.therapy_client_countries c
     set store_country = v_store, sim_country = v_sim, region_country = v_region,
         platform = coalesce(v_platform, c.platform), detected_at = now(),
         country_code = case when v_move then v_pick else c.country_code end,
         source = case when v_move then v_source else c.source end,
         set_by = case when v_move then 'detected' else c.set_by end,
         updated_at = case when v_move and v_pick is distinct from c.country_code then now() else c.updated_at end
   where c.user_id = auth.uid();
  return public.therapy_price_quote();
end;
$$;

-- As in 0031, for older app builds that show a country list: allowed only
-- until a country has been detected or set by the care team.
create or replace function public.therapy_set_country(p_country text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_country);
  v_current text;
  v_source text;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  if v_code is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  select c.country_code, c.source into v_current, v_source
    from public.therapy_client_countries c where c.user_id = auth.uid();
  if v_current is distinct from v_code then
    if public.therapy_country_locked(auth.uid()) then
      raise exception 'Your country is set from your first session. Reply to any of our emails if it has changed.'
        using errcode = 'P0001';
    end if;
    if coalesce(v_source, 'client') <> 'client' then
      raise exception 'Your country comes from your App Store or Google Play account. If it’s wrong, reply to any of our emails.'
        using errcode = 'P0001';
    end if;
  end if;
  insert into public.therapy_client_countries (user_id, country_code, set_by, source)
  values (auth.uid(), v_code, 'client', 'client')
  on conflict (user_id) do update
  set country_code = excluded.country_code, set_by = 'client', source = 'client', updated_at = now();
  return public.therapy_price_quote();
end;
$$;

-- As in 0031, and marked as the care team's, so detection leaves it alone.
create or replace function public.admin_set_client_country(p_email text, p_country text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_code text := public.country_code_of(p_country);
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if v_code is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  select u.id into v_user from auth.users u where lower(u.email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account uses that email.' using errcode = 'P0002';
  end if;
  insert into public.therapy_client_countries (user_id, country_code, set_by, source)
  values (v_user, v_code, public.current_user_email(), 'admin')
  on conflict (user_id) do update
  set country_code = excluded.country_code, set_by = excluded.set_by, source = 'admin', updated_at = now();
end;
$$;

-- What the app reported for a client, for support.
create or replace function public.admin_client_country(p_email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'country_code', c.country_code, 'source', c.source, 'set_by', c.set_by,
    'store_country', c.store_country, 'sim_country', c.sim_country,
    'region_country', c.region_country, 'platform', c.platform,
    'detected_at', c.detected_at, 'updated_at', c.updated_at,
    'locked', public.therapy_country_locked(c.user_id)
  ) into result
  from public.therapy_client_countries c
  join auth.users u on u.id = c.user_id
  where lower(u.email) = lower(trim(p_email));
  return result;
end;
$$;

-- ── 4. Pay: a share of each session's price ──────────────────────────

-- Keep in step with the therapist agreement (section 4 and Schedule 1).
create or replace function public.therapist_share()
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 0.80::numeric;
$$;

alter table public.therapy_requests
  add column if not exists therapist_share numeric(4, 3) check (therapist_share between 0 and 1);

-- As in 0031, and stamps the therapist's share as it stands today.
create or replace function public.therapy_requests_price()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.therapy_prices;
begin
  select c.country_code into new.pricing_country
    from public.therapy_client_countries c where c.user_id = new.user_id;
  p := public.therapy_price_for(new.pricing_country);
  new.price_cents := p.price_minor;
  new.currency := p.currency;
  new.charge_minor := p.charge_minor;
  new.charge_currency := p.charge_currency;
  new.therapist_share := public.therapist_share();
  return new;
end;
$$;

-- The fee for a session: its share of the session's price, in the
-- session's currency. Sessions from before prices were stamped (price 0)
-- use today's price for their country.
create or replace function public.therapy_session_fee(r public.therapy_requests)
returns table (fee_minor integer, currency text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p public.therapy_prices;
begin
  if coalesce(r.price_cents, 0) > 0 then
    fee_minor := round(r.price_cents * coalesce(r.therapist_share, public.therapist_share()));
    currency := upper(coalesce(r.currency, 'USD'));
  else
    p := public.therapy_price_for(r.pricing_country);
    fee_minor := round(p.price_minor * coalesce(r.therapist_share, public.therapist_share()));
    currency := p.currency;
  end if;
  return next;
end;
$$;

-- Writes the fee on a session as it's completed. A therapist no-show is
-- never completed (0016), so it never earns.
create or replace function public.therapy_requests_therapist_fee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  f record;
begin
  if new.status = 'completed' and old.status is distinct from 'completed'
     and new.therapist_id is not null and new.therapist_fee_minor is null then
    select * into f from public.therapy_session_fee(new);
    new.therapist_fee_minor := f.fee_minor;
    new.therapist_fee_currency := f.currency;
  end if;
  return new;
end;
$$;

-- Fills in the fee on completed sessions that have none and haven't been
-- paid out.
create or replace function public.therapist_fill_missing_fees()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.therapy_requests r
     set therapist_fee_minor = f.fee_minor,
         therapist_fee_currency = f.currency
    from public.therapy_requests s
    cross join lateral public.therapy_session_fee(s) f
   where s.id = r.id
     and r.status = 'completed'
     and r.therapist_id is not null
     and r.therapist_fee_minor is null
     and r.payout_id is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

select public.therapist_fill_missing_fees();

-- There are no fees to set any more: older admin pages get a plain answer.
create or replace function public.admin_set_therapist_rate(
  p_country text,
  p_currency text,
  p_fee_minor integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  raise exception using errcode = '22023', message =
    'Therapists are paid ' || round(public.therapist_share() * 100)
    || '% of each session’s price now, so there’s no fee to set. Change the client price instead.';
end;
$$;

-- What a therapist earns per session with a client in a country, so an
-- applicant can see it before signing. Same shape as in 0031, plus the
-- client's price and the share.
create or replace function public.therapist_fee_for_country(p_country text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_country);
  p public.therapy_prices;
begin
  if public.current_user_email() is null then
    raise exception 'Confirm your email address first.' using errcode = '42501';
  end if;
  p := public.therapy_price_for(v_code);
  return jsonb_build_object(
    'country_code', coalesce(v_code, '*'),
    'currency', p.currency,
    'fee_minor', round(p.price_minor * public.therapist_share()),
    'price_minor', p.price_minor,
    'share', public.therapist_share()
  );
end;
$$;

-- ── 5. Licences in more than one country ─────────────────────────────

-- A therapist's main licence (therapists.country_code and
-- licence_expires_on) always has a row, with the number and issuer from
-- their application when there is one.
create or replace function public.therapist_sync_primary_licence(p_therapist uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_country text;
  v_expires date;
  v_number text;
  v_issuer text;
begin
  select t.country_code, t.licence_expires_on into v_country, v_expires
    from public.therapists t where t.id = p_therapist;
  if v_country is null then
    return;
  end if;
  select a.licence_number, a.licence_body into v_number, v_issuer
    from public.therapist_applications a
   where a.therapist_id = p_therapist and a.status = 'approved'
   order by a.updated_at desc
   limit 1;
  insert into public.therapist_licences as l (therapist_id, country_code, number, issuer, expires_on, added_by)
  values (p_therapist, v_country, left(v_number, 80), left(v_issuer, 160), v_expires, 'Main licence')
  on conflict (therapist_id, country_code) do update
  set expires_on = coalesce(excluded.expires_on, l.expires_on),
      number = coalesce(l.number, excluded.number),
      issuer = coalesce(l.issuer, excluded.issuer),
      updated_at = now();
end;
$$;

create or replace function public.therapists_primary_licence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.country_code is not null
     and (tg_op = 'INSERT'
          or new.country_code is distinct from old.country_code
          or new.licence_expires_on is distinct from old.licence_expires_on) then
    perform public.therapist_sync_primary_licence(new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists therapists_primary_licence on public.therapists;
create trigger therapists_primary_licence
  after insert or update of country_code, licence_expires_on on public.therapists
  for each row execute function public.therapists_primary_licence();

do $$
declare
  t record;
begin
  for t in select id from public.therapists where country_code is not null loop
    perform public.therapist_sync_primary_licence(t.id);
  end loop;
end;
$$;

-- A licence document says which country issued it.
alter table public.therapist_documents
  add column if not exists country_code text check (country_code ~ '^[A-Z]{2}$');

-- As in 0033, plus the country for a licence: the therapist's main country
-- unless they say otherwise. A newer upload replaces one still waiting for
-- the same kind (and, for a licence, the same country).
drop function if exists public.therapist_submit_document(text, text, date, text, text);
create or replace function public.therapist_submit_document(
  p_kind text,
  p_path text,
  p_expires_on date,
  p_number text default null,
  p_issuer text default null,
  p_country text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_id uuid;
  v_name text;
  v_email text;
  v_primary text;
  v_country text;
  v_what text := case p_kind when 'licence' then 'licence' else 'insurance certificate' end;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('licence', 'insurance') then
    raise exception 'Choose what the document is.' using errcode = '22023';
  end if;
  if not public.kyc_file_ok(p_path) then
    raise exception 'Upload the document from this page.' using errcode = '22023';
  end if;
  if p_expires_on is null or p_expires_on <= current_date then
    raise exception 'Enter the date it expires. It has to be in the future.' using errcode = '22023';
  end if;
  if nullif(trim(coalesce(p_country, '')), '') is not null and public.country_code_of(p_country) is null then
    raise exception 'Choose the country that issued it.' using errcode = '22023';
  end if;
  if (select count(*) from public.therapist_documents d
       where d.therapist_id = me and d.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'You’ve sent several documents today. Message the care team if something’s wrong.'
      using errcode = '22023';
  end if;

  select t.full_name, ta.email, t.country_code into v_name, v_email, v_primary
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = me;
  if p_kind = 'licence' then
    v_country := coalesce(public.country_code_of(p_country), v_primary);
    if v_country is null then
      raise exception 'Choose the country that issued it.' using errcode = '22023';
    end if;
  end if;

  update public.therapist_documents d
     set status = 'rejected', review_note = 'Replaced by a newer upload.', reviewed_at = now()
   where d.therapist_id = me and d.kind = p_kind and d.status = 'pending'
     and (p_kind <> 'licence' or d.country_code is not distinct from v_country
          or (d.country_code is null and v_country = v_primary));

  insert into public.therapist_documents (therapist_id, kind, path, number, issuer, expires_on, country_code)
  values (me, p_kind, p_path,
          nullif(left(trim(coalesce(p_number, '')), 80), ''),
          nullif(left(trim(coalesce(p_issuer, '')), 160), ''),
          p_expires_on, v_country)
  returning id into v_id;

  perform public.therapist_site_email(
    public.care_team_email(),
    v_email,
    'To check: ' || v_what || ' from ' || coalesce(v_name, 'a therapist'),
    'A ' || v_what || ' to check',
    coalesce(v_name, 'A therapist') || ' uploaded a ' || v_what || ' from their workspace.'
      || case when v_country is not null and v_country is distinct from v_primary
              then ' It’s for a country they aren’t licensed in yet, so accepting it lets them see clients there.'
              else '' end,
    'What they sent',
    jsonb_build_array(
      jsonb_build_array('Country', (select c.name from public.countries c where c.code = v_country)),
      jsonb_build_array('Number', nullif(trim(coalesce(p_number, '')), '')),
      jsonb_build_array('Issued by', nullif(trim(coalesce(p_issuer, '')), '')),
      jsonb_build_array('Expires', to_char(p_expires_on, 'FMDD Mon YYYY'))
    ),
    'Open it on the admin page, under Therapy → Documents, check it with whoever issued it, then accept it or send it back.',
    null,
    'therapist-document/' || v_id
  );
  return v_id;
end;
$$;

-- As in 0033, plus the document's country and the therapist's main one.
create or replace function public.admin_list_therapist_documents(p_status text default 'pending')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'therapist_id', d.therapist_id, 'full_name', t.full_name, 'email', ta.email,
    'kind', d.kind, 'path', d.path, 'number', d.number, 'issuer', d.issuer,
    'expires_on', d.expires_on, 'status', d.status, 'review_note', d.review_note,
    'reviewed_by', d.reviewed_by, 'reviewed_at', d.reviewed_at, 'created_at', d.created_at,
    'country_code', coalesce(d.country_code, case when d.kind = 'licence' then t.country_code end),
    'main_country_code', t.country_code,
    'current_licence_expires_on', coalesce(
      (select l.expires_on from public.therapist_licences l
        where l.therapist_id = d.therapist_id and l.country_code = coalesce(d.country_code, t.country_code)),
      t.licence_expires_on),
    'current_insurance_expires_on', t.insurance_expires_on
  ) order by d.created_at desc), '[]'::jsonb)
  into result
  from public.therapist_documents d
  join public.therapists t on t.id = d.therapist_id
  left join public.therapist_accounts ta on ta.therapist_id = d.therapist_id
  where p_status is null or d.status = p_status;
  return result;
end;
$$;

-- As in 0033 (what the workspace loads in one go), plus each document's
-- country, so a licence for another country isn't mistaken for a renewal.
create or replace function public.therapist_workspace()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'availability', (
      select jsonb_build_object(
        'timezone', a.timezone, 'hours', a.hours, 'max_per_day', a.max_per_day,
        'notice_hours', a.notice_hours, 'taking_new_clients', a.taking_new_clients,
        'updated_at', a.updated_at)
      from public.therapist_availability a where a.therapist_id = me),
    'time_off', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'starts_on', o.starts_on, 'ends_on', o.ends_on, 'note', o.note)
        order by o.starts_on)
      from public.therapist_time_off o
      where o.therapist_id = me and o.ends_on >= current_date - 31), '[]'::jsonb),
    'payout', (
      select jsonb_build_object(
        'method', p.method, 'account_name', p.account_name,
        'summary', public.therapist_payout_summary(p.method, p.details),
        'updated_at', p.updated_at)
      from public.therapist_payout_details p where p.therapist_id = me),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'kind', d.kind, 'number', d.number, 'issuer', d.issuer,
        'expires_on', d.expires_on, 'status', d.status, 'review_note', d.review_note,
        'created_at', d.created_at, 'reviewed_at', d.reviewed_at,
        'country_code', coalesce(d.country_code, case when d.kind = 'licence'
          then (select t.country_code from public.therapists t where t.id = me) end))
        order by d.created_at desc)
      from (
        select * from public.therapist_documents x
        where x.therapist_id = me order by x.created_at desc limit 20
      ) d), '[]'::jsonb),
    'insurance_expires_on', (
      select t.insurance_expires_on from public.therapists t where t.id = me),
    -- From three ratings up, as clients see it, so no one rating shows.
    'rating', (
      select jsonb_build_object('average', round(avg(rt.rating)::numeric, 1), 'count', count(*))
      from public.therapy_ratings rt
      join public.therapy_requests r on r.id = rt.request_id
      where rt.author_role = 'client' and r.therapist_id = me
      having count(*) >= 3),
    'state', coalesce((
      select s.state from public.therapist_site_state s where s.therapist_id = me), '{}'::jsonb),
    'server_time', now()
  );
end;
$$;


-- As in 0033. Accepting a licence records it for its country; for the
-- therapist's main country (or if they have none yet) it also moves the
-- expiry date the booking rules check.
create or replace function public.admin_review_therapist_document(
  p_id uuid,
  p_accept boolean,
  p_note text default null,
  p_expires_on date default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  doc public.therapist_documents%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note, '')), 500), '');
  v_expires date;
  v_name text;
  v_email text;
  v_what text;
  v_primary text;
  v_country text;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into doc from public.therapist_documents d where d.id = p_id for update;
  if not found then
    raise exception 'That document no longer exists.' using errcode = 'P0002';
  end if;
  if doc.status <> 'pending' then
    raise exception 'That document has already been checked.' using errcode = '22023';
  end if;
  if not coalesce(p_accept, false) and v_note is null then
    raise exception 'Say what’s wrong with it, so they can put it right.' using errcode = '22023';
  end if;
  v_expires := coalesce(p_expires_on, doc.expires_on);
  v_what := case doc.kind when 'licence' then 'licence' else 'insurance certificate' end;
  if coalesce(p_accept, false) and (v_expires is null or v_expires <= current_date) then
    raise exception 'Enter the date it expires. It has to be in the future, or send it back instead.'
      using errcode = '22023';
  end if;

  select t.full_name, ta.email, t.country_code into v_name, v_email, v_primary
    from public.therapists t
    left join public.therapist_accounts ta on ta.therapist_id = t.id
   where t.id = doc.therapist_id;
  v_country := case when doc.kind = 'licence' then coalesce(doc.country_code, v_primary) end;

  update public.therapist_documents
     set status = case when coalesce(p_accept, false) then 'accepted' else 'rejected' end,
         review_note = v_note, expires_on = v_expires,
         reviewed_by = public.current_user_email(), reviewed_at = now()
   where id = p_id;
  if coalesce(p_accept, false) then
    if doc.kind = 'licence' then
      if v_primary is null or v_country is null or v_country = v_primary then
        update public.therapists
           set licence_expires_on = v_expires,
               country_code = coalesce(country_code, v_country),
               updated_at = now()
         where id = doc.therapist_id;
      end if;
      if v_country is not null then
        insert into public.therapist_licences as l (
          therapist_id, country_code, number, issuer, expires_on, document_id, added_by)
        values (doc.therapist_id, v_country, doc.number, doc.issuer, v_expires, doc.id, public.current_user_email())
        on conflict (therapist_id, country_code) do update
        set number = coalesce(excluded.number, l.number),
            issuer = coalesce(excluded.issuer, l.issuer),
            expires_on = excluded.expires_on,
            document_id = excluded.document_id,
            added_by = excluded.added_by,
            updated_at = now();
      end if;
    else
      update public.therapists set insurance_expires_on = v_expires, updated_at = now()
       where id = doc.therapist_id;
    end if;
  end if;

  perform public.therapist_site_email(
    v_email,
    public.care_team_email(),
    case when coalesce(p_accept, false) then 'We’ve accepted your ' || v_what
         else 'About the ' || v_what || ' you sent' end,
    case when coalesce(p_accept, false) then 'Your ' || v_what || ' is accepted'
         else 'Your ' || v_what || ' needs another look' end,
    'Hi ' || split_part(coalesce(v_name, ''), ' ', 1) || ', '
      || case when coalesce(p_accept, false)
           then 'the care team has checked the ' || v_what || ' you uploaded and accepted it.'
           else 'the care team couldn’t accept the ' || v_what || ' you uploaded.' end,
    case when coalesce(p_accept, false) then 'On your record' else 'What they said' end,
    jsonb_build_array(
      jsonb_build_array('Country', (select c.name from public.countries c where c.code = v_country)),
      jsonb_build_array('Expires', case when coalesce(p_accept, false)
        then to_char(v_expires, 'FMDD Mon YYYY') end),
      jsonb_build_array('Note', v_note)
    ),
    case when coalesce(p_accept, false) then 'It shows in your workspace, under Settings:'
         else 'Upload a new one in your workspace, under Settings:' end,
    public.therapist_site_url() || '/settings/documents',
    'therapist-document/' || p_id || '/reviewed'
  );
end;
$$;

-- One therapist's licences, each with the client price there and what
-- they earn from it.
create or replace function public.therapist_licence_rows(p_therapist uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.id,
    'country_code', l.country_code,
    'country_name', c.name,
    'number', l.number,
    'issuer', l.issuer,
    'expires_on', l.expires_on,
    'current', l.expires_on is null or l.expires_on >= current_date,
    'main', l.country_code = t.country_code,
    'currency', (public.therapy_price_for(l.country_code)).currency,
    'price_minor', (public.therapy_price_for(l.country_code)).price_minor,
    'fee_minor', round((public.therapy_price_for(l.country_code)).price_minor * public.therapist_share())
  ) order by l.country_code = t.country_code desc, c.name), '[]'::jsonb)
  from public.therapist_licences l
  join public.therapists t on t.id = l.therapist_id
  left join public.countries c on c.code = l.country_code
  where l.therapist_id = p_therapist;
$$;

create or replace function public.therapist_list_licences()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  return public.therapist_licence_rows(me);
end;
$$;

create or replace function public.admin_list_therapist_licences()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.id, 'therapist_id', l.therapist_id, 'full_name', t.full_name,
    'country_code', l.country_code, 'country_name', c.name,
    'number', l.number, 'issuer', l.issuer, 'expires_on', l.expires_on,
    'current', l.expires_on is null or l.expires_on >= current_date,
    'main', l.country_code = t.country_code, 'active', t.active,
    'document_id', l.document_id, 'added_by', l.added_by, 'updated_at', l.updated_at
  ) order by t.full_name, l.country_code = t.country_code desc, c.name), '[]'::jsonb)
  into result
  from public.therapist_licences l
  join public.therapists t on t.id = l.therapist_id
  left join public.countries c on c.code = l.country_code;
  return result;
end;
$$;

-- For a licence the care team has checked some other way (say, for a
-- therapist added by invite). The main country's also moves the expiry
-- date the booking rules check.
create or replace function public.admin_save_therapist_licence(
  p_therapist_id uuid,
  p_country text,
  p_expires_on date,
  p_number text default null,
  p_issuer text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := public.country_code_of(p_country);
  v_primary text;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  if v_code is null then
    raise exception 'Choose a country.' using errcode = '22023';
  end if;
  if p_expires_on is null or p_expires_on <= current_date then
    raise exception 'Enter the date it expires. It has to be in the future.' using errcode = '22023';
  end if;
  select t.country_code into v_primary from public.therapists t where t.id = p_therapist_id;
  if not found then
    raise exception 'That therapist no longer exists.' using errcode = 'P0002';
  end if;
  if v_primary is null or v_primary = v_code then
    update public.therapists
       set country_code = v_code, licence_expires_on = p_expires_on, updated_at = now()
     where id = p_therapist_id;
  end if;
  insert into public.therapist_licences as l (therapist_id, country_code, number, issuer, expires_on, added_by)
  values (p_therapist_id, v_code,
          nullif(left(trim(coalesce(p_number, '')), 80), ''),
          nullif(left(trim(coalesce(p_issuer, '')), 160), ''),
          p_expires_on, public.current_user_email())
  on conflict (therapist_id, country_code) do update
  set number = coalesce(excluded.number, l.number),
      issuer = coalesce(excluded.issuer, l.issuer),
      expires_on = excluded.expires_on,
      added_by = excluded.added_by,
      updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.admin_remove_therapist_licence(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  l public.therapist_licences%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  select * into l from public.therapist_licences x where x.id = p_id;
  if not found then
    raise exception 'That licence is no longer on their record.' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.therapists t where t.id = l.therapist_id and t.country_code = l.country_code) then
    raise exception 'That’s their main licence. Change their country first, or pause them.' using errcode = '22023';
  end if;
  delete from public.therapist_licences where id = p_id;
end;
$$;

-- ── 6. What the earnings page shows ──────────────────────────────────

-- As in 0031, plus the share, a row for each licence (the client price
-- there and what they earn from it), and each session's client country.
-- 'rate' is what they earn with a client in their main country, for the
-- site's older pages.
create or replace function public.therapist_earnings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_therapist_id();
  v_country text;
  p public.therapy_prices;
begin
  if me is null then
    raise exception 'Therapists only' using errcode = '42501';
  end if;
  select t.country_code into v_country from public.therapists t where t.id = me;
  p := public.therapy_price_for(v_country);
  return jsonb_build_object(
    'country_code', v_country,
    'share', public.therapist_share(),
    'rate', case when v_country is null then null else jsonb_build_object(
      'currency', p.currency,
      'fee_minor', round(p.price_minor * public.therapist_share()),
      'country_code', v_country) end,
    'rates', public.therapist_licence_rows(me),
    'owed', (
      select coalesce(jsonb_agg(jsonb_build_object('currency', x.cur, 'amount_minor', x.amount, 'sessions', x.n)), '[]')
      from (
        select r.therapist_fee_currency cur, sum(r.therapist_fee_minor) amount, count(*) n
        from public.therapy_requests r
        where r.therapist_id = me and r.status = 'completed'
          and r.therapist_fee_minor is not null and r.payout_id is null
        group by 1
      ) x
    ),
    'unpriced_sessions', (
      select count(*) from public.therapy_requests r
      where r.therapist_id = me and r.status = 'completed' and r.therapist_fee_minor is null
    ),
    'sessions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'scheduled_at', s.scheduled_at, 'completed_at', s.completed_at,
        'close_reason', s.close_reason, 'fee_minor', s.therapist_fee_minor,
        'currency', s.therapist_fee_currency, 'payout_id', s.payout_id,
        'client_country', s.pricing_country,
        'price_minor', s.price_cents, 'price_currency', s.currency
      ) order by s.completed_at desc), '[]')
      from (
        select * from public.therapy_requests r
        where r.therapist_id = me and r.status = 'completed'
        order by r.completed_at desc
        limit 200
      ) s
    ),
    'payouts', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p2.id, 'currency', p2.currency, 'amount_minor', p2.amount_minor,
        'sessions', p2.session_count, 'method', p2.method, 'reference', p2.reference,
        'paid_at', p2.paid_at
      ) order by p2.paid_at desc), '[]')
      from public.therapist_payouts p2 where p2.therapist_id = me
    )
  );
end;
$$;

-- ── 7. For admins ────────────────────────────────────────────────────

-- As in 0031, plus each price's country name, local currency, what a
-- therapist earns from it and how many therapists are licensed there.
create or replace function public.admin_list_rates()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'share', public.therapist_share(),
    'prices', (
      select coalesce(jsonb_agg(to_jsonb(p) || jsonb_build_object(
          'name', case when p.country_code = '*' then 'Everywhere else' else c.name end,
          'local_currency', c.currency,
          'therapist_fee_minor', round(p.price_minor * public.therapist_share()),
          'licensed_therapists', case when p.country_code = '*' then null
                                      else public.therapists_licensed_in(p.country_code) end
        ) order by p.country_code = '*' desc, c.name), '[]')
      from public.therapy_prices p
      left join public.countries c on c.code = p.country_code
    ),
    'countries', (
      select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name, 'currency', c.currency)
        order by c.name), '[]')
      from public.countries c
    ),
    -- No longer used for pay; kept so older admin pages still load.
    'therapist_rates', (select coalesce(jsonb_agg(to_jsonb(r) order by r.country_code = '*' desc, r.country_code), '[]')
                        from public.therapist_rates r)
  );
end;
$$;

-- As in 0016, plus the client's pricing country, what Paystack charged and
-- the therapist's fee. The return type changes, so it's dropped first.
drop function if exists public.admin_list_therapy_requests();
create function public.admin_list_therapy_requests()
returns table (
  id uuid,
  created_at timestamptz,
  status text,
  topic text,
  availability text[],
  note text,
  is_free_session boolean,
  scheduled_at timestamptz,
  duration_minutes smallint,
  price_cents integer,
  currency text,
  payment_status text,
  paid_at timestamptz,
  refunded_at timestamptz,
  therapist_id uuid,
  therapist_name text,
  client_id uuid,
  client_name text,
  client_email text,
  client_summary text,
  completed_at timestamptz,
  close_reason text,
  client_joined_at timestamptz,
  therapist_joined_at timestamptz,
  client_rating smallint,
  client_comment text,
  therapist_rating smallint,
  therapist_comment text,
  therapist_flags text[],
  pricing_country text,
  charge_minor integer,
  charge_currency text,
  therapist_fee_minor integer,
  therapist_fee_currency text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = '42501';
  end if;
  return query
  select r.id, r.created_at, r.status, r.topic, r.availability, r.note,
         r.is_free_session, r.scheduled_at, r.duration_minutes,
         r.price_cents, r.currency, r.payment_status, r.paid_at,
         r.refunded_at,
         r.therapist_id, t.full_name,
         r.user_id,
         nullif(trim(coalesce(u.raw_user_meta_data ->> 'full_name',
                              u.raw_user_meta_data ->> 'name', '')), ''),
         u.email::text,
         r.client_summary, r.completed_at,
         r.close_reason, r.client_joined_at, r.therapist_joined_at,
         cr.rating, cr.comment, tr.rating, tr.comment, tr.flags,
         coalesce(r.pricing_country, cc.country_code),
         r.charge_minor, r.charge_currency,
         r.therapist_fee_minor, r.therapist_fee_currency
  from public.therapy_requests r
  left join auth.users u on u.id = r.user_id
  left join public.therapists t on t.id = r.therapist_id
  left join public.therapy_client_countries cc on cc.user_id = r.user_id
  left join public.therapy_ratings cr
    on cr.request_id = r.id and cr.author_role = 'client'
  left join public.therapy_ratings tr
    on tr.request_id = r.id and tr.author_role = 'therapist'
  order by r.created_at desc
  limit 500;
end;
$$;

-- ── 8. The agreement, version of 17 November 2026 ────────────────────

-- Keep in step with AGREEMENT_VERSION in the therapist site
-- (src/lib/agreement.ts). Changing it asks everyone to sign again.
create or replace function public.therapist_agreement_version()
returns text
language sql
immutable
set search_path = ''
as $$
  select '2026-11-17';
$$;

-- As in 0033, with this version's news.
create or replace function public.notify_agreement_changed()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  sent integer := 0;
begin
  for r in
    select t.id, t.full_name, ta.email
    from public.therapists t
    join public.therapist_accounts ta on ta.therapist_id = t.id
    where t.active and public.therapist_accepted_agreement(ta.email) is null
  loop
    perform public.therapist_site_email(
      r.email,
      public.care_team_email(),
      'Please sign the updated therapist agreement',
      'How you’re paid is changing',
      'Hi ' || split_part(coalesce(r.full_name, ''), ' ', 1)
        || ', from now on you earn ' || round(public.therapist_share() * 100)
        || '% of the price of each session you complete. Prices are set for the country your client lives in, so what you earn depends on where they are. Your Earnings page shows it for each country you’re licensed in.',
      'What to do',
      jsonb_build_array(
        jsonb_build_array('1', 'Sign in to your workspace'),
        jsonb_build_array('2', 'Read the agreement and sign it at the bottom'),
        jsonb_build_array('Until then', 'We can’t book new sessions with you. Sessions already booked aren’t affected.')
      ),
      'Read and sign it here:',
      public.therapist_site_url() || '/agreement',
      'therapist-agreement/' || public.therapist_agreement_version() || '/' || md5(r.email)
    );
    sent := sent + 1;
  end loop;
  return sent;
end;
$$;

-- ── Who may call what ────────────────────────────────────────────────

revoke execute on function public.country_code_of(text) from public, anon, authenticated;
revoke execute on function public.therapists_licensed_in(text) from public, anon, authenticated;
revoke execute on function public.therapy_session_fee(public.therapy_requests) from public, anon, authenticated;
revoke execute on function public.therapist_sync_primary_licence(uuid) from public, anon, authenticated;
revoke execute on function public.therapist_licence_rows(uuid) from public, anon, authenticated;
revoke execute on function public.therapists_primary_licence() from public, anon, authenticated;
revoke execute on function public.therapist_fill_missing_fees() from public, anon, authenticated;
revoke execute on function public.notify_agreement_changed() from public, anon, authenticated;

revoke execute on function public.therapist_share() from public, anon;
revoke execute on function public.therapy_price_quote() from public, anon;
revoke execute on function public.therapy_detect_country(text, text, text, text) from public, anon;
revoke execute on function public.therapy_set_country(text) from public, anon;
revoke execute on function public.therapist_fee_for_country(text) from public, anon;
revoke execute on function public.therapist_submit_document(text, text, date, text, text, text) from public, anon;
revoke execute on function public.therapist_list_licences() from public, anon;
revoke execute on function public.therapist_workspace() from public, anon;
revoke execute on function public.therapist_earnings() from public, anon;
revoke execute on function public.admin_set_therapy_price(text, text, integer, integer, text) from public, anon;
revoke execute on function public.admin_set_client_country(text, text) from public, anon;
revoke execute on function public.admin_client_country(text) from public, anon;
revoke execute on function public.admin_set_therapist_rate(text, text, integer) from public, anon;
revoke execute on function public.admin_list_therapist_documents(text) from public, anon;
revoke execute on function public.admin_review_therapist_document(uuid, boolean, text, date) from public, anon;
revoke execute on function public.admin_list_therapist_licences() from public, anon;
revoke execute on function public.admin_save_therapist_licence(uuid, text, date, text, text) from public, anon;
revoke execute on function public.admin_remove_therapist_licence(uuid) from public, anon;
revoke execute on function public.admin_list_rates() from public, anon;
revoke execute on function public.admin_list_therapy_requests() from public, anon;

grant execute on function public.therapist_share() to authenticated;
grant execute on function public.therapy_price_quote() to authenticated;
grant execute on function public.therapy_detect_country(text, text, text, text) to authenticated;
grant execute on function public.therapy_set_country(text) to authenticated;
grant execute on function public.therapist_fee_for_country(text) to authenticated;
grant execute on function public.therapist_submit_document(text, text, date, text, text, text) to authenticated;
grant execute on function public.therapist_list_licences() to authenticated;
grant execute on function public.therapist_workspace() to authenticated;
grant execute on function public.therapist_earnings() to authenticated;
grant execute on function public.admin_set_therapy_price(text, text, integer, integer, text) to authenticated;
grant execute on function public.admin_set_client_country(text, text) to authenticated;
grant execute on function public.admin_client_country(text) to authenticated;
grant execute on function public.admin_set_therapist_rate(text, text, integer) to authenticated;
grant execute on function public.admin_list_therapist_documents(text) to authenticated;
grant execute on function public.admin_review_therapist_document(uuid, boolean, text, date) to authenticated;
grant execute on function public.admin_list_therapist_licences() to authenticated;
grant execute on function public.admin_save_therapist_licence(uuid, text, date, text, text) to authenticated;
grant execute on function public.admin_remove_therapist_licence(uuid) to authenticated;
grant execute on function public.admin_list_rates() to authenticated;
grant execute on function public.admin_list_therapy_requests() to authenticated;

commit;

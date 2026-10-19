-- =============================================================================
-- KOMPLETNY SKRYPT PRZYGOTOWAWCZY BIGQUERY (WSZYSTKIE SCENARIUSZE WARSZTATOWE)
-- Tworzy dataset `dak_workshop_demo` oraz 9 tabel źródłowych obsługujących:
--   • Moduł 2 & Use Case 5 (Narodziny Encji): G1 -> G2 -> G3, schema-mapping, Dataform
--   • Use Case 1 (Strażnik Zabezpieczeń): Rejestr zabezpieczeń banku vs. zrzut z eKW
--   • Use Case 2 (Klient na Celowniku): Historia MiFID (delty D/D) + Sygnały Doradcy 360°
--   • Moduł 3 & Use Case 3 (Sieć pod Lupą): Geolokalizacja placówek i transakcji POS (GeoSQL)
--   • Moduł 3 & Use Case 4 (Anonimowy Bohater): Dane wrażliwe PII w kolumnach i tekście (AI.GENERATE)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS `dak_workshop_demo`
OPTIONS (
  description = 'Dataset demonstracyjny na warsztat Google Cloud Data Agent Kit (DAK) - wszystkie 5 Use Caseow'
);

-- =============================================================================
-- CZĘŚĆ A: TABELE POD MODUŁ 2, USE CASE 1 (Strażnik Zabezpieczeń) i USE CASE 5 (Narodziny Encji)
-- =============================================================================

-- 1. Warstwa G1: Kartoteka Klientów (g1_core_clients)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_core_clients` (
  cif_no INT64 OPTIONS(description='Numeryczny identyfikator klienta w systemie centralnym (CIF)'),
  pelna_nazwa STRING OPTIONS(description='Imię i nazwisko klienta lub nazwa firmy'),
  pesel_nip STRING OPTIONS(description='PESEL dla osoby fizycznej lub NIP dla firmy (dane PII)'),
  segment_kod STRING OPTIONS(description='Kod segmentu klienta: retail, affluent, sme, corporate'),
  oddzial_macierzysty STRING OPTIONS(description='Kod placówki prowadzącej klienta'),
  email_kontaktowy STRING OPTIONS(description='Adres e-mail klienta (PII)'),
  notatka_doradcy STRING OPTIONS(description='Ostatnia notatka doradcy ze spotkania MiFID (zawiera dane wrażliwe PII w tekście)')
) OPTIONS (
  description = 'Warstwa G1: Surowa kartoteka klientów z systemu centralnego'
);

INSERT INTO `dak_workshop_demo.g1_core_clients` VALUES
  (104582, 'Janina Kowalska', '84051209876', ' affluent ', 'WAW-012', 'j.kowalska84@example.pl', 'Klientka Janina Kowalska (tel. 602-111-222, zam. ul. Puławska 14/8 Warszawa) planuje nadpłatę kredytu hipotecznego z wolnych środków 120 tys. PLN.'),
  (104583, 'Marek Nowak', '79112304512', 'retail', 'KRK-004', 'marek.nowak@example.pl', 'Klient Marek Nowak (PESEL 79112304512) zgłosił chęć przeniesienia lokaty 85 000 PLN do innego banku; brak aktualnej ankiety MiFID.'),
  (209910, 'TechBud Sp. z o.o.', '5252410099', 'SME', 'POZ-002', 'biuro@techbud.example.pl', 'Prezes Adam Wiśniewski (tel. 501-998-776) pytał o zwolnienie części zabezpieczenia na działce w Poznaniu.'),
  (308811, ' Piotr Zieliński ', '90021401122', 'Retail', 'RAD-001', 'p.zielinski@example.pl', 'Klient Piotr Zieliński (ul. Żeromskiego 5, Radom) na co dzień pracuje przy Rondzie Daszyńskiego w Warszawie i tam wykonuje 90% transakcji kartą.'),
  (405519, 'Anna Wiśniewska', '88090155443', 'affluent', 'WAW-012', 'a.wisniewska@example.pl', 'Klientka Anna Wiśniewska otrzymała wpływ 350 000 PLN ze sprzedaży nieruchomości; rozpoczęła wniosek o fundusz inwestycyjny w aplikacji mobilnej, ale go porzuciła.');

-- 2. Warstwa G2: Umowy Kredytowe (g2_credit_agreements) - TABELA KOTWICZĄCA
CREATE OR REPLACE TABLE `dak_workshop_demo.g2_credit_agreements` (
  agreement_id STRING NOT NULL OPTIONS(description='Unikalny numer umowy kredytowej'),
  customer_id STRING NOT NULL OPTIONS(description='8-znakowy identyfikator klienta z wiodącymi zerami (np. 00104582)'),
  product_category STRING OPTIONS(description='Kategoria produktu kredytowego'),
  contract_start_dt STRING OPTIONS(description='Data uruchomienia kredytu w formacie YYYY-MM-DD'),
  current_balance_orig NUMERIC(18,2) OPTIONS(description='Aktualne saldo zadłużenia w walucie umowy'),
  currency_iso STRING OPTIONS(description='Waluta umowy kredytowej (np. pln, eur)'),
  fx_rate_to_pln NUMERIC(10,4) OPTIONS(description='Kurs przeliczeniowy waluty umowy do PLN')
) OPTIONS (
  description = 'Warstwa G2: Aktywne umowy kredytowe i ekspozycja bilansowa'
);

INSERT INTO `dak_workshop_demo.g2_credit_agreements` VALUES
  ('KRED-2022-0091', '00104582', 'HIPOTEKA_MIESZKANIOWA', '2022-06-15', 420000.00, 'pln', 1.0000),
  ('KRED-2021-0144', '00104583', 'HIPOTEKA_MIESZKANIOWA', '2021-03-10', 610000.00, 'PLN', 1.0000),
  ('KRED-2023-0880', '00209910', 'KREDYT_INWESTYCYJNY', '2023-11-02', 200000.00, 'eur', 4.3000),
  ('KRED-2024-0312', '00308811', 'POZYCZKA_GOTOWKOWA', '2024-02-20', 45000.00, 'PLN', 1.0000),
  ('KRED-2023-0519', '00405519', 'HIPOTEKA_MIESZKANIOWA', '2023-05-19', 510000.00, 'PLN', 1.0000);

-- 3. Warstwa G1: Wewnętrzny Rejestr Zabezpieczeń Banku (g1_collateral_registry)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_collateral_registry` (
  collateral_id STRING NOT NULL OPTIONS(description='ID zabezpieczenia w systemie bankowym'),
  loan_agreement_ref STRING NOT NULL OPTIONS(description='Referencja do umowy kredytowej (agreement_id)'),
  owner_bank_id INT64 OPTIONS(description='Numeryczny CIF właściciela zabezpieczenia'),
  nr_ksiegi_wieczystej STRING OPTIONS(description='Numer Księgi Wieczystej w rejestrze banku'),
  operat_wartosc_pln NUMERIC(18,2) OPTIONS(description='Wartość rynkowa nieruchomości z operatu szacunkowego w PLN'),
  data_operatu_txt STRING OPTIONS(description='Data wykonania operatu szacunkowego w formacie DD.MM.YYYY'),
  hipoteka_bank_pln NUMERIC(18,2) OPTIONS(description='Kwota hipoteki wymagana wg umowy kredytowej w PLN'),
  udzial_wlasnosci_bank STRING OPTIONS(description='Wymagany udział właściciela wg umowy zabezpieczenia np. 1/1'),
  powierzchnia_operat_m2 NUMERIC(10,2) OPTIONS(description='Powierzchnia użytkowa/gruntu wg operatu szacunkowego w m2'),
  status_zabezpieczenia STRING OPTIONS(description='Status zabezpieczenia w systemie bankowym: AKTYWNE, W_REJESTRACJI, ZWOLNIONE')
) OPTIONS (
  description = 'Warstwa G1: Wewnętrzny rejestr zabezpieczeń rzeczowych i nieruchomości'
);

INSERT INTO `dak_workshop_demo.g1_collateral_registry` VALUES
  ('ZAB-001', 'KRED-2022-0091', 104582, 'WA1M/00123456/7', 750000.00, '12.05.2022', 630000.00, '1/1', 68.50, 'AKTYWNE'),
  ('ZAB-002', 'KRED-2021-0144', 104583, 'KR1P/00987654/2', 680000.00, '20.02.2021', 915000.00, '1/1', 62.00, 'AKTYWNE'),
  ('ZAB-003', 'KRED-2023-0880', 209910, 'PO1P/00456123/9', 950000.00, '15.10.2023', 1290000.00, '1/1', 1250.00, 'AKTYWNE'),
  ('ZAB-004', 'KRED-2023-0880', 209910, 'PO1P/00456124/6', 450000.00, '18.10.2023', 450000.00, '1/1', 620.00, 'W_REJESTRACJI'),
  ('ZAB-005', 'KRED-2023-0519', 405519, 'WA1M/00554433/1', 890000.00, '10.05.2023', 765000.00, '1/1', 81.00, 'AKTYWNE');

-- 4. Warstwa G1: Zrzut z Centralnej Bazy Zabezpieczeń / eKW (g1_ekw_land_register_dump)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_ekw_land_register_dump` (
  ekw_identifier STRING NOT NULL OPTIONS(description='Numer elektronicznej Księgi Wieczystej z Centralnej Bazy Zabezpieczeń'),
  dzial_ii_wlasciciel STRING OPTIONS(description='Właściciel wpisany w Dziale II eKW'),
  dzial_ii_udzial_txt STRING OPTIONS(description='Udział właściciela jako ułamek tekstowy np. 1/1 lub 1/2'),
  powierzchnia_m2 NUMERIC(10,2) OPTIONS(description='Powierzchnia nieruchomości w m2 wg Działu I-O eKW'),
  dzial_iv_status STRING OPTIONS(description='Status wpisu hipoteki w Dziale IV: WPISANA, WZMIANKA, BRAK_WPISU'),
  hipoteka_kwota_raw STRING OPTIONS(description='Surowy tekst kwoty hipoteki z eKW np. 630 000,00 PLN'),
  hipoteka_waluta STRING OPTIONS(description='Waluta hipoteki w Dziale IV eKW')
) OPTIONS (
  description = 'Warstwa G1: Zrzut danych z elektronicznych Ksiąg Wieczystych (eKW / Centralna Baza Zabezpieczeń)'
);

INSERT INTO `dak_workshop_demo.g1_ekw_land_register_dump` VALUES
  ('WA1M/00123456/7', 'JANINA KOWALSKA', '1/1', 68.50, 'WPISANA', '630 000,00 PLN', 'PLN'),
  ('KR1P/00987654/2', 'MAREK NOWAK, ANNA NOWAK', '1/2', 54.20, 'WPISANA', '610 000,00 PLN', 'PLN'),
  ('PO1P/00456123/9', 'TECHBUD SPÓŁKA Z OGRANICZONĄ ODPOWIEDZIALNOŚCIĄ', '1/1', 1250.00, 'WPISANA', '1 290 000,00 PLN', 'PLN'),
  ('PO1P/00456124/6', 'TECHBUD SPÓŁKA Z OGRANICZONĄ ODPOWIEDZIALNOŚCIĄ', '1/1', 620.00, 'BRAK_WPISU', 'NULL', 'BRAK'),
  ('WA1M/00554433/1', 'ANNA KOWALCZYK', '1/1', 81.00, 'WZMIANKA', '765 000,00 PLN', 'PLN');


-- =============================================================================
-- CZĘŚĆ B: TABELE POD USE CASE 2 („Klient na Celowniku” – MiFID & Kokpit Doradcy 360°)
-- =============================================================================

-- 5. Historia wskaźników kontrolnych MiFID w podziale na oddziały i dni (do liczenia delt D/D)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_mifid_compliance_history` (
  snapshot_date DATE NOT NULL OPTIONS(description='Data migawki dziennej MiFID'),
  branch_code STRING NOT NULL OPTIONS(description='Kod oddziału / jednostki banku'),
  region_name STRING OPTIONS(description='Makroregion sieci sprzedaży'),
  total_investment_clients INT64 OPTIONS(description='Liczba klientów inwestycyjnych objętych wymogami MiFID'),
  valid_mifid_questionnaires INT64 OPTIONS(description='Liczba klientów z ważną ankietą adekwatności MiFID'),
  missing_advisor_notes_cnt INT64 OPTIONS(description='Liczba spotkań inwestycyjnych bez uzupełnionej notatki doradcy'),
  orders_in_branch_cnt INT64 OPTIONS(description='Liczba zleceń inwestycyjnych złożonych w oddziale'),
  orders_in_digital_cnt INT64 OPTIONS(description='Liczba zleceń inwestycyjnych złożonych w aplikacji mobilnej / serwisie www'),
  compliance_breach_alerts INT64 OPTIONS(description='Liczba alertów niezgodności regulacyjnej MiFID')
) OPTIONS (
  description = 'Warstwa G1: Dzienne metryki kontrolne MiFID w podziale na jednostki (do analizy trendów i delt D/D)'
);

INSERT INTO `dak_workshop_demo.g1_mifid_compliance_history` VALUES
  ('2026-10-13', 'WAW-012', 'Region Centralny', 450, 420, 8, 18, 64, 1),
  ('2026-10-14', 'WAW-012', 'Region Centralny', 452, 425, 5, 20, 71, 0),
  ('2026-10-15', 'WAW-012', 'Region Centralny', 455, 432, 3, 22, 85, 0),
  ('2026-10-13', 'KRK-004', 'Region Południowy', 310, 260, 19, 25, 22, 4),
  ('2026-10-14', 'KRK-004', 'Region Południowy', 310, 255, 24, 24, 19, 6),
  ('2026-10-15', 'KRK-004', 'Region Południowy', 312, 248, 31, 28, 17, 9),
  ('2026-10-13', 'POZ-002', 'Region Zachodni', 280, 268, 4, 14, 49, 1),
  ('2026-10-14', 'POZ-002', 'Region Zachodni', 281, 270, 4, 15, 52, 1),
  ('2026-10-15', 'POZ-002', 'Region Zachodni', 282, 273, 2, 16, 58, 0);

-- 6. Portfel produktów i sygnały sprzedażowe dla doradcy (Next-Best-Action)
CREATE OR REPLACE TABLE `dak_workshop_demo.g2_customer_portfolio_and_signals` (
  cif_no INT64 NOT NULL OPTIONS(description='Identyfikator klienta (CIF)'),
  branch_code STRING OPTIONS(description='Oddział prowadzący'),
  advisor_ldap STRING OPTIONS(description='Przypisany doradca klienta'),
  mifid_questionnaire_status STRING OPTIONS(description='Status ankiety MiFID: AKTUALNA, WYGASA_W_30_DNI, BRAK, PRZETERMINOWANA'),
  last_contact_date DATE OPTIONS(description='Data ostatniego kontaktu doradcy z klientem'),
  free_cash_on_ror_pln NUMERIC(18,2) OPTIONS(description='Wolne środki leżące na nieoprocentowanym ROR powyżej 30 dni (PLN)'),
  maturing_deposit_30d_pln NUMERIC(18,2) OPTIONS(description='Kwota lokat kończących się w ciągu najbliższych 30 dni (PLN)'),
  maturing_deposit_date DATE OPTIONS(description='Data zapadalności najbliższej lokaty'),
  external_outflow_30d_pln NUMERIC(18,2) OPTIONS(description='Suma przelewów wychodzących na rachunki własne w innych bankach w ostatnich 30 dniach'),
  recent_large_inflow_pln NUMERIC(18,2) OPTIONS(description='Jednorazowy duży wpływ środków w ostatnich 14 dniach (PLN)'),
  abandoned_process_type STRING OPTIONS(description='Niedokończony proces zakupowy w aplikacji mobilnej/www')
) OPTIONS (
  description = 'Warstwa G2: Portfel klienta i sygnały leadowe dla doradcy (wolne środki, zapadające lokaty, odpływy, porzucone wnioski)'
);

INSERT INTO `dak_workshop_demo.g2_customer_portfolio_and_signals` VALUES
  (104582, 'WAW-012', 'doradca_waw_1', 'AKTUALNA', '2026-09-10', 145000.00, 200000.00, '2026-10-28', 0.00, 0.00, 'BRAK'),
  (104583, 'KRK-004', 'doradca_krk_2', 'PRZETERMINOWANA', '2026-04-12', 18000.00, 85000.00, '2026-10-22', 65000.00, 0.00, 'LOKATA_PROMOCYJNA'),
  (209910, 'POZ-002', 'doradca_poz_1', 'AKTUALNA', '2026-10-05', 490000.00, 0.00, NULL, 120000.00, 310000.00, 'GWARANCJA_BANKOWA'),
  (308811, 'RAD-001', 'doradca_rad_1', 'BRAK', '2025-11-20', 62000.00, 50000.00, '2026-11-05', 40000.00, 0.00, 'KONTO_OSZCZEDNOSCIOWE'),
  (405519, 'WAW-012', 'doradca_waw_1', 'WYGASA_W_30_DNI', '2026-08-19', 365000.00, 150000.00, '2026-10-25', 15000.00, 350000.00, 'FUNDUSZ_INWESTYCYJNY_GLOBAL');


-- =============================================================================
-- CZĘŚĆ C: TABELE POD MODUŁ 3 & USE CASE 3 („Sieć pod Lupą” – GeoSQL i Optymalizacja Placówek)
-- =============================================================================

-- 7. Lokalizacje i parametry placówek banku (g1_bank_branches_geo)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_bank_branches_geo` (
  branch_code STRING NOT NULL OPTIONS(description='Kod oddziału banku'),
  branch_name STRING OPTIONS(description='Nazwa placówki'),
  city STRING OPTIONS(description='Miasto'),
  branch_format STRING OPTIONS(description='Format placówki: FLAGSHIP, STANDARD, EXPRESS_MALL'),
  latitude FLOAT64 OPTIONS(description='Szerokość geograficzna oddziału (WGS84)'),
  longitude FLOAT64 OPTIONS(description='Długość geograficzna oddziału (WGS84)'),
  advisor_fte_count INT64 OPTIONS(description='Liczba etatów doradców (FTE) w placówce'),
  monthly_footfall_visits INT64 OPTIONS(description='Średnia miesięczna liczba wizyt klientów w placówce'),
  monthly_lease_cost_pln NUMERIC(12,2) OPTIONS(description='Miesięczny koszt najmu i utrzymania placówki w PLN')
) OPTIONS (
  description = 'Warstwa G1: Sieć placówek bankowych z współrzędnymi geograficznymi i obsadą doradców'
);

INSERT INTO `dak_workshop_demo.g1_bank_branches_geo` VALUES
  ('WAW-012', 'Oddział Warszawa Rondo Daszyńskiego (Centrum Biznesowe)', 'Warszawa', 'FLAGSHIP', 52.2302, 20.9841, 14, 4200, 68000.00),
  ('WAW-019', 'Oddział Warszawa Mokotów Puławska', 'Warszawa', 'STANDARD', 52.1935, 21.0245, 7, 1850, 39000.00),
  ('RAD-001', 'Oddział Radom Żeromskiego', 'Radom', 'STANDARD', 51.4027, 21.1471, 8, 1100, 28000.00),
  ('KRK-004', 'Oddział Kraków Rynek Główny', 'Kraków', 'FLAGSHIP', 50.0619, 19.9368, 11, 3100, 54000.00),
  ('POZ-002', 'Oddział Poznań Centrum Handlowe', 'Poznań', 'EXPRESS_MALL', 52.4014, 16.9272, 5, 2750, 42000.00);

-- 8. Geolokalizacja dziennych transakcji kartowych/BLIK klientów (g1_client_card_transactions_geo)
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_client_card_transactions_geo` (
  tx_id STRING NOT NULL OPTIONS(description='ID transakcji kartowej / BLIK'),
  cif_no INT64 NOT NULL OPTIONS(description='Identyfikator klienta (CIF)'),
  assigned_home_branch STRING OPTIONS(description='Aktualnie przypisany oddział macierzysty wg adresu zamieszkania'),
  tx_timestamp TIMESTAMP OPTIONS(description='Czas wykonania transakcji w terminalu POS'),
  merchant_category STRING OPTIONS(description='Kategoria punktu usługowego (LUNCH_CAFE, GROCERY, OFFICE_PARKING, SHOPPING_MALL)'),
  pos_latitude FLOAT64 OPTIONS(description='Szerokość geograficzna terminala POS'),
  pos_longitude FLOAT64 OPTIONS(description='Długość geograficzna terminala POS'),
  tx_amount_pln NUMERIC(10,2) OPTIONS(description='Kwota transakcji w PLN')
) OPTIONS (
  description = 'Warstwa G1: Transakcje bezgotówkowe w terminalach POS z geolokalizacją (do wyznaczania centrum aktywności dziennej klienta)'
);

INSERT INTO `dak_workshop_demo.g1_client_card_transactions_geo` VALUES
  ('TX-9001', 308811, 'RAD-001', TIMESTAMP '2026-10-12 08:45:00+00', 'LUNCH_CAFE', 52.2308, 20.9850, 24.50),
  ('TX-9002', 308811, 'RAD-001', TIMESTAMP '2026-10-12 13:15:00+00', 'LUNCH_CAFE', 52.2299, 20.9835, 48.00),
  ('TX-9003', 308811, 'RAD-001', TIMESTAMP '2026-10-13 09:05:00+00', 'OFFICE_PARKING', 52.2304, 20.9844, 35.00),
  ('TX-9004', 308811, 'RAD-001', TIMESTAMP '2026-10-14 16:40:00+00', 'GROCERY', 52.2312, 20.9860, 142.80),
  ('TX-9005', 104582, 'WAW-012', TIMESTAMP '2026-10-12 10:20:00+00', 'LUNCH_CAFE', 52.1940, 21.0250, 32.00),
  ('TX-9006', 104582, 'WAW-012', TIMESTAMP '2026-10-13 14:10:00+00', 'GROCERY', 52.1931, 21.0239, 215.40),
  ('TX-9007', 104582, 'WAW-012', TIMESTAMP '2026-10-14 12:30:00+00', 'SHOPPING_MALL', 52.1938, 21.0248, 390.00),
  ('TX-9008', 405519, 'WAW-012', TIMESTAMP '2026-10-13 11:00:00+00', 'LUNCH_CAFE', 52.2301, 20.9839, 55.00),
  ('TX-9009', 405519, 'WAW-012', TIMESTAMP '2026-10-14 15:20:00+00', 'SHOPPING_MALL', 52.2305, 20.9847, 480.00);


-- =============================================================================
-- CZĘŚĆ D: TABELA POD MODUŁ 3 & USE CASE 4 („Anonimowy Bohater” – Detekcja i Anonimizacja PII)
-- =============================================================================

-- 9. Surowe zgłoszenia i interakcje CRM zawierające dane wrażliwe PII w kolumnach i tekście
CREATE OR REPLACE TABLE `dak_workshop_demo.g1_raw_crm_interactions_pii` (
  interaction_id STRING NOT NULL OPTIONS(description='Unikalny identyfikator zgłoszenia CRM'),
  created_at TIMESTAMP OPTIONS(description='Data i czas rejestracji zgłoszenia'),
  cif_no INT64 OPTIONS(description='Identyfikator klienta (klucz obcy do zachowania spójności po pseudonimizacji)'),
  imie_i_nazwisko STRING OPTIONS(description='Imię i nazwisko klienta'),
  pesel STRING OPTIONS(description='Numer PESEL klienta'),
  nr_dowodu_osobistego STRING OPTIONS(description='Seria i numer dowodu osobistego'),
  iban_rachunku STRING OPTIONS(description='Pełny numer rachunku bankowego IBAN'),
  telefon_komorkowy STRING OPTIONS(description='Numer telefonu komórkowego'),
  email STRING OPTIONS(description='Adres poczty elektronicznej'),
  adres_korespondencyjny STRING OPTIONS(description='Pełny adres zamieszkania / korespondencyjny'),
  kategoria_sprawy STRING OPTIONS(description='Kategoria biznesowa zgłoszenia (bez PII)'),
  tresc_zgloszenia_free_text STRING OPTIONS(description='Swobodny opis sprawy lub transkrypcja rozmowy zawierająca nieustrukturyzowane dane osobowe i wrażliwe')
) OPTIONS (
  description = 'Warstwa G1: Zgłoszenia i notatki CRM wymagające automatycznej detekcji PII i anonimizacji'
);

INSERT INTO `dak_workshop_demo.g1_raw_crm_interactions_pii` VALUES
  (
    'CRM-2026-001',
    TIMESTAMP '2026-10-14 09:30:00+00',
    104582,
    'Janina Kowalska',
    '84051209876',
    'ABC123456',
    'PL61124010371111001099887766',
    '+48 602 111 222',
    'j.kowalska84@example.pl',
    'ul. Puławska 14 m. 8, 02-512 Warszawa',
    'DYSPOZYCJA_NADPLATY_HIPOTEKI',
    'Klientka Janina Kowalska (PESEL 84051209876, dowód ABC123456) zadzwoniła z numeru 602-111-222 i poprosiła o przeksięgowanie kwoty 120 000 PLN z jej rachunku PL61124010371111001099887766 na poczet nadpłaty kredytu mieszkaniowego na nieruchomości przy ul. Puławskiej 14/8 w Warszawie. Wspomniała też, że jej mąż Tomasz Kowalski (PESEL 82010154321) przebywa obecnie w szpitalu MSWiA.'
  ),
  (
    'CRM-2026-002',
    TIMESTAMP '2026-10-14 11:15:00+00',
    104583,
    'Marek Nowak',
    '79112304512',
    'DEF987654',
    'PL44124045331111000011223344',
    '+48 505 333 444',
    'marek.nowak@example.pl',
    'ul. Karmelicka 22/4, 31-128 Kraków',
    'REKLAMACJA_PRZELEWU',
    'Pan Marek Nowak zamieszkały w Krakowie przy ul. Karmelickiej 22/4 (e-mail: marek.nowak@example.pl, tel. 505333444) składa reklamację dotyczącą przelewu wychodzącego na kwotę 65 000 PLN z konta PL44124045331111000011223344 na rzecz odbiorcy Anna Nowak (ul. Długa 7, Wieliczka).'
  ),
  (
    'CRM-2026-003',
    TIMESTAMP '2026-10-15 08:20:00+00',
    308811,
    'Piotr Zieliński',
    '90021401122',
    'GHI456789',
    'PL12124057041111001055667788',
    '+48 790 888 999',
    'p.zielinski@example.pl',
    'ul. Żeromskiego 5/12, 26-600 Radom',
    'ZMIANA_DANYCH_KONTAKTOWYCH',
    'Klient Piotr Zieliński (PESEL: 90021401122, nowy dowód osobisty GHI456789) prosi o zmianę adresu do korespondencji z ul. Żeromskiego 5/12 w Radomiu na adres tymczasowy: ul. Towarowa 35 m. 44, 00-869 Warszawa oraz potwierdzenie SMS-em na numer +48 790 888 999.'
  );

/* =====================================================================
   INTERNATIONAL DEBT DATABASE (MySQL 8.0+)
   Tables : countries, indicators, debt_data (+ staging_debt)
   Source : country_metadata_cleaned.csv (134 rows: 120 countries,
            14 aggregates) -> loaded below as INSERT statements.
   Note   : debt values file not provided; section 4 is ready for it.
   Run    : mysql --default-character-set=utf8mb4 -u root -p < debt_analysis.sql
   ===================================================================== */


/* ---------------------------------------------------------------------
   1. CREATE DATABASE
   --------------------------------------------------------------------- */
DROP DATABASE IF EXISTS debt_db;
CREATE DATABASE debt_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE debt_db;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;   -- keeps names like Côte d'Ivoire intact; matches table collation


/* ---------------------------------------------------------------------
   2. RELATIONAL SCHEMA (PRIMARY KEYS + FOREIGN KEYS)
   --------------------------------------------------------------------- */

-- 2.1 Countries (dimension) - natural key = 3-letter code used in the data
CREATE TABLE countries (
    country_code          CHAR(3)      NOT NULL,
    country_name          VARCHAR(150) NOT NULL,
    country_long_name     VARCHAR(200) NULL,
    iso2_code             CHAR(2)      NULL,
    entity_type           ENUM('Country','Aggregate') NOT NULL,
    region                VARCHAR(60)  NULL,   -- NULL for aggregates
    income_group          VARCHAR(40)  NULL,   -- NULL for aggregates / not available
    lending_category      VARCHAR(20)  NULL,   -- IDA / IBRD / Blend
    is_hipc               TINYINT(1)   NOT NULL DEFAULT 0,
    currency_unit         VARCHAR(80)  NULL,
    debt_reporting_status VARCHAR(20)  NULL,   -- Actual / Estimate / Preliminary
    CONSTRAINT pk_countries     PRIMARY KEY (country_code),
    CONSTRAINT uq_country_name  UNIQUE (country_name),
    CONSTRAINT uq_iso2          UNIQUE (iso2_code),
    INDEX idx_region (region),
    INDEX idx_income (income_group)
) ENGINE=InnoDB;

-- 2.2 Indicators (dimension)
CREATE TABLE indicators (
    indicator_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    indicator_code  VARCHAR(60)  NOT NULL,
    indicator_name  VARCHAR(255) NOT NULL,
    CONSTRAINT pk_indicators     PRIMARY KEY (indicator_id),
    CONSTRAINT uq_indicator_code UNIQUE (indicator_code)
) ENGINE=InnoDB;

-- 2.3 Debt data (fact)
CREATE TABLE debt_data (
    debt_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    country_code  CHAR(3)         NOT NULL,
    indicator_id  INT UNSIGNED    NOT NULL,
    year          SMALLINT        NOT NULL,
    value         DECIMAL(20,2)   NULL,
    CONSTRAINT pk_debt_data PRIMARY KEY (debt_id),
    CONSTRAINT uq_debt_obs  UNIQUE (country_code, indicator_id, year),
    CONSTRAINT fk_debt_country
        FOREIGN KEY (country_code) REFERENCES countries (country_code)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_debt_indicator
        FOREIGN KEY (indicator_id) REFERENCES indicators (indicator_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_year CHECK (year BETWEEN 1960 AND 2100),
    INDEX idx_debt_year      (year),
    INDEX idx_debt_indicator (indicator_id, year)
) ENGINE=InnoDB;

-- 2.4 Staging table for the debt values file
CREATE TABLE staging_debt (
    country_code    CHAR(3),
    indicator_code  VARCHAR(60),
    indicator_name  VARCHAR(255),
    year            SMALLINT,
    value           DECIMAL(20,2)
) ENGINE=InnoDB;


/* ---------------------------------------------------------------------
   3. INSERT CLEANED DATA - COUNTRIES (from country_metadata_cleaned.csv)
      'Not applicable (aggregate)' and 'Not available' are stored as NULL.
   --------------------------------------------------------------------- */
INSERT INTO countries
  (country_code, country_name, country_long_name, iso2_code, entity_type, region,
   income_group, lending_category, is_hipc, currency_unit, debt_reporting_status)
VALUES
('EAP','East Asia & Pacific (excluding high income)','East Asia & Pacific (excluding high income)','4E','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('ECA','Europe & Central Asia (excluding high income)','Europe & Central Asia (excluding high income)','7E','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('IDX','IDA only','IDA only','XI','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('IDA','IDA total','IDA total','XG','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('LAC','Latin America & Caribbean (excluding high income)','Latin America & Caribbean (excluding high income)','XJ','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('LDC','Least developed countries: UN classification','Least developed countries: UN classification','XL','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('LMY','Low & middle income','Low & middle income','XO','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('LIC','Low income','Low income','XM','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('LMC','Lower middle income','Lower middle income','XN','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('MNA','Middle East, North Africa, Afghanistan & Pakistan (excluding high income)','Middle East, North Africa, Afghanistan & Pakistan (excluding high income)','XQ','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('MIC','Middle income','Middle income','XP','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('SAS','South Asia','South Asia','8S','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('SSA','Sub-Saharan Africa (excluding high income)','Sub-Saharan Africa (excluding high income)','ZF','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('UMC','Upper middle income','Upper middle income','XT','Aggregate',NULL,NULL,NULL,0,NULL,NULL),
('AFG','Afghanistan','Islamic State of Afghanistan','AF','Country','Middle East & North Africa','Low income','IDA',1,'Afghan afghani','Estimate'),
('ALB','Albania','Republic of Albania','AL','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Albanian lek','Actual'),
('DZA','Algeria','People''s Democratic Republic of Algeria','DZ','Country','Middle East & North Africa','Upper middle income','IBRD',0,'Algerian dinar','Actual'),
('AGO','Angola','People''s Republic of Angola','AO','Country','Sub-Saharan Africa','Lower middle income','IBRD',0,'Angolan kwanza','Actual'),
('ARG','Argentina','Argentine Republic','AR','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Argentine peso','Actual'),
('ARM','Armenia','Republic of Armenia','AM','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Armenian dram','Actual'),
('AZE','Azerbaijan','Republic of Azerbaijan','AZ','Country','Europe & Central Asia','Upper middle income','IBRD',0,'New Azeri manat','Actual'),
('BGD','Bangladesh','People''s Republic of Bangladesh','BD','Country','South Asia','Lower middle income','IDA',0,'Bangladeshi taka','Actual'),
('BLR','Belarus','Republic of Belarus','BY','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Belarusian rubel','Estimate'),
('BLZ','Belize','Belize','BZ','Country','Latin America & Caribbean','Upper middle income','Blend',0,'Belize dollar','Actual'),
('BEN','Benin','Republic of Benin','BJ','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'West African CFA franc','Actual'),
('BTN','Bhutan','Kingdom of Bhutan','BT','Country','South Asia','Lower middle income','IDA',0,'Bhutanese ngultrum','Actual'),
('BOL','Bolivia, Plurinational State of','Plurinational State of Bolivia','BO','Country','Latin America & Caribbean','Lower middle income','IBRD',1,'Bolivian Boliviano','Actual'),
('BIH','Bosnia and Herzegovina','Bosnia and Herzegovina','BA','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Bosnia and Herzegovina convertible mark','Actual'),
('BWA','Botswana','Republic of Botswana','BW','Country','Sub-Saharan Africa','Upper middle income','IBRD',0,'Botswana pula','Actual'),
('BRA','Brazil','Federative Republic of Brazil','BR','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Brazilian real','Actual'),
('BFA','Burkina Faso','Burkina Faso','BF','Country','Sub-Saharan Africa','Low income','IDA',1,'West African CFA franc','Actual'),
('BDI','Burundi','Republic of Burundi','BI','Country','Sub-Saharan Africa','Low income','IDA',1,'Burundi franc','Actual'),
('CPV','Cabo Verde','Republic of Cabo Verde','CV','Country','Sub-Saharan Africa','Upper middle income','Blend',0,'Cabo Verde escudo','Actual'),
('KHM','Cambodia','Kingdom of Cambodia','KH','Country','East Asia & Pacific','Lower middle income','IDA',0,'Cambodian riel','Actual'),
('CMR','Cameroon','Republic of Cameroon','CM','Country','Sub-Saharan Africa','Lower middle income','Blend',1,'Central African CFA franc','Actual'),
('CAF','Central African Republic','Central African Republic','CF','Country','Sub-Saharan Africa','Low income','IDA',1,'Central African CFA franc','Actual'),
('TCD','Chad','Republic of Chad','TD','Country','Sub-Saharan Africa','Low income','IDA',1,'Central African CFA franc','Preliminary'),
('CHN','China','People''s Republic of China','CN','Country','East Asia & Pacific','Upper middle income','IBRD',0,'Chinese yuan','Preliminary'),
('COL','Colombia','Republic of Colombia','CO','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Colombian peso','Actual'),
('COM','Comoros','Union of the Comoros','KM','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'Comorian franc','Actual'),
('COD','Congo, Democratic Republic of','Democratic Republic of the Congo','CD','Country','Sub-Saharan Africa','Low income','IDA',1,'Congolese franc','Actual'),
('COG','Congo, Republic of','Republic of Congo','CG','Country','Sub-Saharan Africa','Lower middle income','Blend',1,'Central African CFA franc','Actual'),
('CIV','Côte d''Ivoire','Republic of Côte d''Ivoire','CI','Country','Sub-Saharan Africa','Lower middle income','Blend',1,'West African CFA franc','Actual'),
('DJI','Djibouti','Republic of Djibouti','DJ','Country','Middle East & North Africa','Lower middle income','IDA',0,'Djibouti franc','Actual'),
('DMA','Dominica','Commonwealth of Dominica','DM','Country','Latin America & Caribbean','Upper middle income','Blend',0,'East Caribbean dollar','Actual'),
('DOM','Dominican Republic','Dominican Republic','DO','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Dominican peso','Actual'),
('ECU','Ecuador','Republic of Ecuador','EC','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'U.S. dollar','Preliminary'),
('EGY','Egypt, Arab Republic of','Arab Republic of Egypt','EG','Country','Middle East & North Africa','Lower middle income','IBRD',0,'Egyptian pound','Actual'),
('SLV','El Salvador','Republic of El Salvador','SV','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'U.S. dollar','Actual'),
('GNQ','Equatorial Guinea','Republic of Equatorial Guinea','GQ','Country','Sub-Saharan Africa','Upper middle income','IBRD',0,'Central African CFA franc','Actual'),
('ERI','Eritrea','State of Eritrea','ER','Country','Sub-Saharan Africa','Low income','IDA',1,'Eritrean nakfa','Estimate'),
('SWZ','Eswatini','Kingdom of Eswatini','SZ','Country','Sub-Saharan Africa','Lower middle income','Blend',0,'Swazi lilangeni','Actual'),
('ETH','Ethiopia','Federal Democratic Republic of Ethiopia','ET','Country','Sub-Saharan Africa',NULL,'IDA',1,'Ethiopian birr','Actual'),
('FJI','Fiji','Republic of Fiji','FJ','Country','East Asia & Pacific','Upper middle income','Blend',0,'Fijian dollar','Actual'),
('GAB','Gabon','Gabonese Republic','GA','Country','Sub-Saharan Africa','Upper middle income','IBRD',0,'Central African CFA franc','Actual'),
('GMB','Gambia, The','Republic of The Gambia','GM','Country','Sub-Saharan Africa','Low income','IDA',1,'Gambian dalasi','Actual'),
('GEO','Georgia','Georgia','GE','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Georgian lari','Actual'),
('GHA','Ghana','Republic of Ghana','GH','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'New Ghanaian cedi','Actual'),
('GRD','Grenada','Grenada','GD','Country','Latin America & Caribbean','Upper middle income','Blend',0,'East Caribbean dollar','Actual'),
('GTM','Guatemala','Republic of Guatemala','GT','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Guatemalan quetzal','Actual'),
('GIN','Guinea','Republic of Guinea','GN','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'Guinean franc','Actual'),
('GNB','Guinea-Bissau','Republic of Guinea-Bissau','GW','Country','Sub-Saharan Africa','Low income','IDA',1,'West African CFA franc','Actual'),
('GUY','Guyana','Co-operative Republic of Guyana','GY','Country','Latin America & Caribbean','High income','IDA',1,'Guyana dollar','Actual'),
('HTI','Haiti','Republic of Haiti','HT','Country','Latin America & Caribbean','Lower middle income','IDA',1,'Haitian gourde','Actual'),
('HND','Honduras','Republic of Honduras','HN','Country','Latin America & Caribbean','Lower middle income','IDA',1,'Honduran lempira','Actual'),
('IND','India','Republic of India','IN','Country','South Asia','Lower middle income','IBRD',0,'Indian rupee','Actual'),
('IDN','Indonesia','Republic of Indonesia','ID','Country','East Asia & Pacific','Upper middle income','IBRD',0,'Indonesian rupiah','Actual'),
('IRN','Iran, Islamic Republic of','Islamic Republic of Iran','IR','Country','Middle East & North Africa','Upper middle income','IBRD',0,'Iranian rial','Estimate'),
('IRQ','Iraq','Republic of Iraq','IQ','Country','Middle East & North Africa','Upper middle income','IBRD',0,'Iraqi dinar','Actual'),
('JAM','Jamaica','Jamaica','JM','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Jamaican dollar','Actual'),
('JOR','Jordan','Hashemite Kingdom of Jordan','JO','Country','Middle East & North Africa','Lower middle income','IBRD',0,'Jordanian dinar','Actual'),
('KAZ','Kazakhstan','Republic of Kazakhstan','KZ','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Kazakh tenge','Actual'),
('KEN','Kenya','Republic of Kenya','KE','Country','Sub-Saharan Africa','Lower middle income','Blend',0,'Kenyan shilling','Actual'),
('XKX','Kosovo','Republic of Kosovo','XK','Country','Europe & Central Asia','Upper middle income','IDA',0,'Euro','Actual'),
('KGZ','Kyrgyz Republic','Kyrgyz Republic','KG','Country','Europe & Central Asia','Lower middle income','IDA',1,'Kyrgyz som','Actual'),
('LAO','Lao PDR','Lao People''s Democratic Republic','LA','Country','East Asia & Pacific','Lower middle income','IDA',0,'Lao kip','Actual'),
('LBN','Lebanon','Lebanese Republic','LB','Country','Middle East & North Africa','Lower middle income','IBRD',0,'Lebanese pound','Estimate'),
('LSO','Lesotho','Kingdom of Lesotho','LS','Country','Sub-Saharan Africa','Lower middle income','IDA',0,'Lesotho loti','Actual'),
('LBR','Liberia','Republic of Liberia','LR','Country','Sub-Saharan Africa','Low income','IDA',1,'Liberian dollar','Actual'),
('MDG','Madagascar','Republic of Madagascar','MG','Country','Sub-Saharan Africa','Low income','IDA',1,'Malagasy ariary','Actual'),
('MWI','Malawi','Republic of Malawi','MW','Country','Sub-Saharan Africa','Low income','IDA',1,'Malawi kwacha','Actual'),
('MDV','Maldives','Republic of Maldives','MV','Country','South Asia','Upper middle income','IDA',0,'Maldivian rufiyaa','Actual'),
('MLI','Mali','Republic of Mali','ML','Country','Sub-Saharan Africa','Low income','IDA',1,'West African CFA franc','Actual'),
('MRT','Mauritania','Islamic Republic of Mauritania','MR','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'Mauritanian ouguiya','Actual'),
('MUS','Mauritius','Republic of Mauritius','MU','Country','Sub-Saharan Africa','Upper middle income','IBRD',0,'Mauritian rupee','Actual'),
('MEX','Mexico','United Mexican States','MX','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Mexican peso','Actual'),
('MDA','Moldova','Republic of Moldova','MD','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Moldovan leu','Actual'),
('MNG','Mongolia','Mongolia','MN','Country','East Asia & Pacific','Upper middle income','IBRD',0,'Mongolian tugrik','Actual'),
('MNE','Montenegro','Montenegro','ME','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Euro','Actual'),
('MAR','Morocco','Kingdom of Morocco','MA','Country','Middle East & North Africa','Lower middle income','IBRD',0,'Moroccan dirham','Actual'),
('MOZ','Mozambique','Republic of Mozambique','MZ','Country','Sub-Saharan Africa','Low income','IDA',1,'New Mozambican metical','Actual'),
('MMR','Myanmar','Republic of the Union of Myanmar','MM','Country','East Asia & Pacific','Lower middle income','IDA',0,'Myanmar kyat','Actual'),
('NPL','Nepal','Nepal','NP','Country','South Asia','Lower middle income','IDA',0,'Nepalese rupee','Actual'),
('NIC','Nicaragua','Republic of Nicaragua','NI','Country','Latin America & Caribbean','Lower middle income','IDA',1,'Nicaraguan gold cordoba','Actual'),
('NER','Niger','Republic of Niger','NE','Country','Sub-Saharan Africa','Low income','IDA',1,'West African CFA franc','Actual'),
('NGA','Nigeria','Federal Republic of Nigeria','NG','Country','Sub-Saharan Africa','Lower middle income','Blend',0,'Nigerian naira','Actual'),
('MKD','North Macedonia','Republic of North Macedonia','MK','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Macedonian denar','Actual'),
('PAK','Pakistan','Islamic Republic of Pakistan','PK','Country','Middle East & North Africa','Lower middle income','Blend',0,'Pakistani rupee','Actual'),
('PNG','Papua New Guinea','The Independent State of Papua New Guinea','PG','Country','East Asia & Pacific','Lower middle income','Blend',0,'Papua New Guinea kina','Actual'),
('PRY','Paraguay','Republic of Paraguay','PY','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Paraguayan guarani','Actual'),
('PER','Peru','Republic of Peru','PE','Country','Latin America & Caribbean','Upper middle income','IBRD',0,'Peruvian new sol','Actual'),
('PHL','Philippines','Republic of the Philippines','PH','Country','East Asia & Pacific','Lower middle income','IBRD',0,'Philippine peso','Actual'),
('RWA','Rwanda','Republic of Rwanda','RW','Country','Sub-Saharan Africa','Low income','IDA',1,'Rwandan franc','Actual'),
('WSM','Samoa','Independent State of Samoa','WS','Country','East Asia & Pacific','Upper middle income','IDA',0,'Samoan tala','Actual'),
('SEN','Senegal','Republic of Senegal','SN','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'West African CFA franc','Actual'),
('SRB','Serbia','Republic of Serbia','RS','Country','Europe & Central Asia','Upper middle income','IBRD',0,'New Serbian dinar','Actual'),
('SLE','Sierra Leone','Republic of Sierra Leone','SL','Country','Sub-Saharan Africa','Low income','IDA',1,'Sierra Leonean leone','Actual'),
('SLB','Solomon Islands','Solomon Islands','SB','Country','East Asia & Pacific','Lower middle income','IDA',0,'Solomon Islands dollar','Actual'),
('SOM','Somalia, Fed. Rep.','Federal Republic of Somalia','SO','Country','Sub-Saharan Africa','Low income','IDA',1,'Somali shilling','Actual'),
('ZAF','South Africa','Republic of South Africa','ZA','Country','Sub-Saharan Africa','Upper middle income','IBRD',0,'South African rand','Actual'),
('LKA','Sri Lanka','Democratic Socialist Republic of Sri Lanka','LK','Country','South Asia','Lower middle income','IDA',0,'Sri Lankan rupee','Actual'),
('LCA','St. Lucia','St. Lucia','LC','Country','Latin America & Caribbean','Upper middle income','Blend',0,'East Caribbean dollar','Actual'),
('VCT','St. Vincent and the Grenadines','St. Vincent and the Grenadines','VC','Country','Latin America & Caribbean','Upper middle income','Blend',0,'East Caribbean dollar','Actual'),
('SDN','Sudan','Republic of the Sudan','SD','Country','Sub-Saharan Africa','Low income','IDA',1,'Sudanese pound','Estimate'),
('SUR','Suriname','Republic of Suriname','SR','Country','Latin America & Caribbean','Upper middle income','Blend',0,'Suriname dollar','Actual'),
('SYR','Syrian Arab Republic','Syrian Arab Republic','SY','Country','Middle East & North Africa','Low income','IDA',0,'Syrian pound','Estimate'),
('STP','São Tomé and Principe','Democratic Republic of São Tomé and Principe','ST','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'São Tomé and Principe dobra','Actual'),
('TJK','Tajikistan','Republic of Tajikistan','TJ','Country','Europe & Central Asia','Lower middle income','IDA',0,'Tajik somoni','Actual'),
('TZA','Tanzania','United Republic of Tanzania','TZ','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'Tanzanian shilling','Actual'),
('THA','Thailand','Kingdom of Thailand','TH','Country','East Asia & Pacific','Upper middle income','IBRD',0,'Thai baht','Actual'),
('TLS','Timor-Leste','Democratic Republic of Timor-Leste','TL','Country','East Asia & Pacific','Lower middle income','Blend',0,'U.S. dollar','Actual'),
('TGO','Togo','Republic of Togo','TG','Country','Sub-Saharan Africa','Low income','IDA',1,'West African CFA franc','Actual'),
('TON','Tonga','Kingdom of Tonga','TO','Country','East Asia & Pacific','Upper middle income','IDA',0,'Tongan pa''anga','Actual'),
('TUN','Tunisia','Republic of Tunisia','TN','Country','Middle East & North Africa','Lower middle income','IBRD',0,'Tunisian dinar','Actual'),
('TKM','Turkmenistan','Turkmenistan','TM','Country','Europe & Central Asia','Upper middle income','IBRD',0,'New Turkmen manat','Actual'),
('TUR','Türkiye','Republic of Türkiye','TR','Country','Europe & Central Asia','Upper middle income','IBRD',0,'New Turkish lira','Actual'),
('UGA','Uganda','Republic of Uganda','UG','Country','Sub-Saharan Africa','Low income','IDA',1,'Ugandan shilling','Actual'),
('UKR','Ukraine','Ukraine','UA','Country','Europe & Central Asia','Upper middle income','IBRD',0,'Ukrainian hryvnia','Actual'),
('UZB','Uzbekistan','Republic of Uzbekistan','UZ','Country','Europe & Central Asia','Lower middle income','Blend',0,'Uzbek som','Actual'),
('VUT','Vanuatu','Republic of Vanuatu','VU','Country','East Asia & Pacific','Lower middle income','IDA',0,'Vanuatu vatu','Actual'),
('VNM','Viet Nam','Socialist Republic of Viet Nam','VN','Country','East Asia & Pacific','Lower middle income','IBRD',0,'Vietnamese dong','Actual'),
('YEM','Yemen, Republic of','Republic of Yemen','YE','Country','Middle East & North Africa','Low income','IDA',0,'Yemeni rial','Preliminary'),
('ZMB','Zambia','Republic of Zambia','ZM','Country','Sub-Saharan Africa','Lower middle income','IDA',1,'New Zambian kwacha','Actual'),
('ZWE','Zimbabwe','Republic of Zimbabwe','ZW','Country','Sub-Saharan Africa','Lower middle income','Blend',0,'Zimbabwean Zimbabwe Gold','Actual');


-- Verify
SELECT entity_type, COUNT(*) AS n FROM countries GROUP BY entity_type;   -- 120 / 14


/* ---------------------------------------------------------------------
   4. INSERT CLEANED DATA - INDICATORS + DEBT VALUES
      Expected CSV (long format, header row):
      country_code, indicator_code, indicator_name, year, value
   --------------------------------------------------------------------- */
-- OPTIONAL: bulk-load the debt CSV (LOAD DATA LOCAL is OFF by default -> error 3948).
-- To use it: run  SET GLOBAL local_infile = 1;  then connect with
--   mysql --local-infile=1 -u root -p debt_db
-- and un-comment the block below. Alternatives: debt_pipeline.py or
-- MySQL Workbench "Table Data Import Wizard" into staging_debt.
--
-- LOAD DATA LOCAL INFILE 'C:/data/cleaned_debt_data.csv'
-- INTO TABLE staging_debt
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS
-- (country_code, indicator_code, indicator_name, year, @value)
-- SET value = NULLIF(TRIM(@value), '');

-- The statements below are safe to run with an empty staging_debt (0 rows inserted).

INSERT INTO indicators (indicator_code, indicator_name)
SELECT indicator_code, MAX(indicator_name)
FROM staging_debt
WHERE indicator_code IS NOT NULL
GROUP BY indicator_code;

INSERT INTO debt_data (country_code, indicator_id, year, value)
SELECT s.country_code, i.indicator_id, s.year, s.value
FROM staging_debt s
JOIN indicators i ON i.indicator_code = s.indicator_code
JOIN countries  c ON c.country_code   = s.country_code;   -- drops codes missing from metadata

-- Rows rejected because the country code is not in the metadata (should be 0)
SELECT DISTINCT s.country_code
FROM staging_debt s
LEFT JOIN countries c ON c.country_code = s.country_code
WHERE c.country_code IS NULL;

-- DROP TABLE staging_debt;   -- once verified


/* ---------------------------------------------------------------------
   5. INTEGRITY CHECKS
   --------------------------------------------------------------------- */
SELECT 'countries' AS tbl, COUNT(*) AS row_count FROM countries
UNION ALL SELECT 'indicators', COUNT(*) FROM indicators
UNION ALL SELECT 'debt_data',  COUNT(*) FROM debt_data;

SELECT i.indicator_name, COUNT(*) AS total_rows,
       SUM(d.value IS NULL) AS null_values,
       ROUND(100 * AVG(d.value IS NULL), 2) AS null_pct
FROM debt_data d JOIN indicators i USING (indicator_id)
GROUP BY i.indicator_name
ORDER BY null_pct DESC;


/* ---------------------------------------------------------------------
   6. ANALYSIS QUERIES
   Set @indicator to your dataset's indicator code (keep the COLLATE clause,
   otherwise error 1267 'Illegal mix of collations').
   Aggregates are excluded with entity_type = 'Country' unless noted.
   --------------------------------------------------------------------- */
SET @indicator = 'DT.DOD.DECT.CD' COLLATE utf8mb4_unicode_ci;   -- e.g. total external debt stocks (current US$)

-- ---- A. Metadata-only queries (run immediately after section 3) ----

-- A1. Countries by region and income group
SELECT region, income_group, COUNT(*) AS countries
FROM countries
WHERE entity_type = 'Country'
GROUP BY region, income_group
ORDER BY region, countries DESC;

-- A2. HIPC countries by region
SELECT region, COUNT(*) AS hipc_countries
FROM countries
WHERE is_hipc = 1
GROUP BY region
ORDER BY hipc_countries DESC;

-- A3. Lending category vs debt reporting status
SELECT lending_category, debt_reporting_status, COUNT(*) AS countries
FROM countries
WHERE entity_type = 'Country'
GROUP BY lending_category, debt_reporting_status
ORDER BY lending_category, countries DESC;

-- A4. Countries sharing a currency (e.g. CFA franc, euro)
SELECT currency_unit, COUNT(*) AS countries, GROUP_CONCAT(country_name ORDER BY country_name SEPARATOR '; ') AS members
FROM countries
WHERE entity_type = 'Country'
GROUP BY currency_unit
HAVING COUNT(*) > 1
ORDER BY countries DESC;

-- ---- B. Debt analysis (run after section 4) ----

-- B1. Top 10 debtor countries, latest year
SELECT c.country_name, c.region, d.year, d.value AS total_debt
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator
  AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data)
  AND d.value IS NOT NULL
ORDER BY d.value DESC
LIMIT 10;

-- B2. Debt trend by year (countries only)
SELECT d.year, SUM(d.value) AS total_debt,
       COUNT(DISTINCT d.country_code) AS countries_reporting
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
GROUP BY d.year
ORDER BY d.year;

-- B3. Year-over-year growth per country
SELECT c.country_name, d.year, d.value,
       ROUND(100 * (d.value - LAG(d.value) OVER w)
                 / NULLIF(LAG(d.value) OVER w, 0), 2) AS yoy_growth_pct
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
WINDOW w AS (PARTITION BY d.country_code ORDER BY d.year)
ORDER BY c.country_name, d.year;

-- B4. Total and average debt by region (latest year)
SELECT c.region, COUNT(DISTINCT c.country_code) AS countries,
       ROUND(AVG(d.value), 2) AS avg_debt, SUM(d.value) AS total_debt
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data)
GROUP BY c.region
ORDER BY total_debt DESC;

-- B5. Average debt by income group (latest year)
SELECT COALESCE(c.income_group, 'Unclassified') AS income_group,
       COUNT(DISTINCT c.country_code) AS countries,
       ROUND(AVG(d.value), 2) AS avg_debt
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data)
GROUP BY c.income_group
ORDER BY avg_debt DESC;

-- B6. HIPC vs non-HIPC average debt by year
SELECT d.year, c.is_hipc, ROUND(AVG(d.value), 2) AS avg_debt
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
GROUP BY d.year, c.is_hipc
ORDER BY d.year, c.is_hipc;

-- B7. Debt by lending category (latest year)
SELECT c.lending_category, COUNT(DISTINCT c.country_code) AS countries,
       SUM(d.value) AS total_debt, ROUND(AVG(d.value), 2) AS avg_debt
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data)
GROUP BY c.lending_category
ORDER BY total_debt DESC;

-- B8. Share of total debt per country (latest year)
SELECT c.country_name, d.value,
       ROUND(100 * d.value / SUM(d.value) OVER (), 2) AS share_pct
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data) AND d.value IS NOT NULL
ORDER BY share_pct DESC;

-- B9. Rank within region (latest year)
SELECT c.region, c.country_name, d.value,
       RANK() OVER (PARTITION BY c.region ORDER BY d.value DESC) AS region_rank
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data) AND d.value IS NOT NULL
ORDER BY c.region, region_rank;

-- B10. Countries above the average (latest year)
SELECT c.country_name, d.value
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id)
WHERE i.indicator_code = @indicator AND c.entity_type = 'Country'
  AND d.year = (SELECT MAX(year) FROM debt_data)
  AND d.value > (SELECT AVG(d2.value)
                 FROM debt_data d2
                 JOIN countries  c2 USING (country_code)
                 JOIN indicators i2 USING (indicator_id)
                 WHERE i2.indicator_code = @indicator AND c2.entity_type = 'Country'
                   AND d2.year = (SELECT MAX(year) FROM debt_data))
ORDER BY d.value DESC;

-- B11. 10-year change per country
WITH w AS (
    SELECT d.country_code,
           MAX(CASE WHEN d.year = mx.y      THEN d.value END) AS latest,
           MAX(CASE WHEN d.year = mx.y - 10 THEN d.value END) AS decade_ago
    FROM debt_data d
    JOIN indicators i USING (indicator_id)
    CROSS JOIN (SELECT MAX(year) AS y FROM debt_data) mx
    WHERE i.indicator_code = @indicator
    GROUP BY d.country_code
)
SELECT c.country_name, w.decade_ago, w.latest,
       ROUND(100 * (w.latest - w.decade_ago) / NULLIF(w.decade_ago, 0), 2) AS change_pct
FROM w JOIN countries c USING (country_code)
WHERE c.entity_type = 'Country' AND w.latest IS NOT NULL AND w.decade_ago IS NOT NULL
ORDER BY change_pct DESC
LIMIT 15;

-- B12. Reusable view
CREATE OR REPLACE VIEW v_country_debt AS
SELECT c.country_code, c.country_name, c.region, c.income_group,
       c.lending_category, c.is_hipc, c.entity_type,
       i.indicator_code, i.indicator_name, d.year, d.value
FROM debt_data d
JOIN countries  c USING (country_code)
JOIN indicators i USING (indicator_id);

#debt_long

from urllib.parse import quote_plus
from sqlalchemy import create_engine, text

# ---- Change only the password ----
USER = "root"
PASSWORD = quote_plus("your_password")
HOST = "localhost"
DATABASE = "debt_db"
CSV_FILE = "Output/ids_debt_long.csv"
TABLE = "ids_debt_long"
# ----------------------------------

engine = create_engine(f"mysql+pymysql://{USER}:{PASSWORD}@{HOST}/{DATABASE}")

# 1. Create the table inside debt_db (skipped if it already exists)
with engine.begin() as conn:
    conn.execute(text(f"""
        CREATE TABLE IF NOT EXISTS {TABLE} (
            id INT AUTO_INCREMENT PRIMARY KEY,
            country_code VARCHAR(5) NOT NULL,
            indicator_code VARCHAR(30) NOT NULL,
            year INT NOT NULL,
            value DOUBLE
        )
    """))

# 2. Insert the CSV in batches
total = 0
for chunk in pd.read_csv(CSV_FILE, chunksize=50_000):
    chunk.to_sql(
        TABLE,
        con=engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=5_000,
    )
    total += len(chunk)
    print(f"Inserted {total:,} rows...")

print("Done!")

#indicator_lookup

/* =====================================================================
   INDICATOR LOOKUP TABLE (MySQL 8.0+)
   Source : ids_indicator_lookup_1.csv  (576 indicators)
   Safe to re-run: creates debt_db / indicators if missing and updates rows.
   If you use the full debt_analysis.sql, you do NOT need this file; it
   already includes these same inserts.
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS debt_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE debt_db;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

/* ---- Table (primary key = World Bank series code) ---- */
CREATE TABLE IF NOT EXISTS indicators (
    indicator_code     VARCHAR(30)  NOT NULL,
    indicator_name     VARCHAR(200) NOT NULL,
    unit               VARCHAR(30)  NULL,       -- current US$, %, years, ...
    is_debt_indicator  TINYINT(1)   NOT NULL DEFAULT 1,
    series_group       VARCHAR(12)  GENERATED ALWAYS AS
                       (SUBSTRING_INDEX(indicator_code, '.', 2)) STORED,
                       -- DT.DOD = debt stocks, DT.TDS = debt service, DT.NFL = net flows ...
    CONSTRAINT pk_indicators PRIMARY KEY (indicator_code),
    INDEX idx_series_group (series_group),
    INDEX idx_unit (unit)
) ENGINE=InnoDB;

/* ---- Insert lookup data ---- */
INSERT INTO indicators (indicator_code, indicator_name, unit, is_debt_indicator)
VALUES
('BM.GSR.TOTL.CD','Imports of goods, services and primary income (current US$)','current US$',0),
('BN.CAB.XOKA.CD','Current account balance (current US$)','current US$',0),
('BX.GRT.EXTA.CD.DT','Grants, excluding technical cooperation (current US$)','current US$',0),
('BX.GRT.TECH.CD.DT','Technical cooperation grants (current US$)','current US$',0),
('BX.GSR.TOTL.CD','Exports of goods, services and primary income (current US$)','current US$',0),
('BX.KLT.DINV.CD.DT','Foreign direct investment, net inflows in reporting economy (DRS, current US$)','current US$',0),
('BX.KLT.DREM.CD.DT','Primary income on FDI (current US$)','current US$',0),
('BX.PEF.TOTL.CD.DT','Portfolio investment, equity (DRS, current US$)','current US$',0),
('BX.TRF.PWKR.CD.DT','Personal transfers and compensation of employees, received (current US$)','current US$',0),
('DT.AMT.BLAT.CB.CD','CB, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLAT.CD','PPG, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLAT.GG.CD','GG, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLAT.OPS.CD','OPS, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLAT.PRVG.CD','PRVG, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLAT.PS.CD','PS, bilateral (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.CB.CD','CB, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.CD','PPG, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.GG.CD','GG, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.OPS.CD','OPS, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.PRVG.CD','PRVG, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.BLTC.PS.CD','PS, bilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.DECB.CD','Principal repayments on external debt, central bank (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.DEGG.CD','Principal repayments on external debt, general government sector (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.DEPS.CD','Principal repayments on external debt, public sector (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.DIMF.CD','IMF repurchases (AMT, current US$)','current US$',1),
('DT.AMT.DLTF.CD','Principal repayments on external debt, long-term + IMF (AMT, current US$)','current US$',1),
('DT.AMT.DLXF.CD','Principal repayments on external debt, long-term (AMT, current US$)','current US$',1),
('DT.AMT.DOPS.CD','Principal repayments on external debt, other public sector (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.DPNG.CD','Principal repayments on external debt, private nonguaranteed (PNG) (AMT, current US$)','current US$',1),
('DT.AMT.DPPG.CD','Principal repayments on external debt, public and publicly guaranteed (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.MIBR.CD','PPG, IBRD (AMT, current US$)','current US$',1),
('DT.AMT.MIDA.CD','PPG, IDA (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.CB.CD','CB, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.CD','PPG, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.GG.CD','GG, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.OPS.CD','OPS, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.PRVG.CD','PRVG, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLAT.PS.CD','PS, multilateral (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.CB.CD','CB, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.CD','PPG, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.GG.CD','GG, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.OPS.CD','OPS, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.PRVG.CD','PRVG, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.MLTC.PS.CD','PS, multilateral concessional (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.CB.CD','CB, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.CD','PPG, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.GG.CD','GG, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.OPS.CD','OPS, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.PRVG.CD','PRVG, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.OFFT.PS.CD','PS, official creditors (AMT, current US$)','current US$',1),
('DT.AMT.PBND.CB.CD','CB, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PBND.CD','PPG, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PBND.GG.CD','GG, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PBND.OPS.CD','OPS, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PBND.PRVG.CD','PRVG, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PBND.PS.CD','PS, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.CB.CD','CB, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.CD','PPG, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.GG.CD','GG, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.OPS.CD','OPS, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.PRVG.CD','PRVG, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PCBK.PS.CD','PS, commercial banks (AMT, current US$)','current US$',1),
('DT.AMT.PNGB.CD','PNG, bonds (AMT, current US$)','current US$',1),
('DT.AMT.PNGC.CD','PNG, commercial banks and other creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.CB.CD','CB, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.CD','PPG, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.GG.CD','GG, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.OPS.CD','OPS, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.PRVG.CD','PRVG, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PROP.PS.CD','PS, other private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRPG.CD','Principal repayments on external debt, private guaranteed by public sector (PPG) (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.CB.CD','CB, private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.CD','PPG, private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.GG.CD','GG, private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.OPS.CD','OPS, private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.PRVG.CD','PRVG, private creditors (AMT, current US$)','current US$',1),
('DT.AMT.PRVT.PS.CD','PS, private creditors (AMT, current US$)','current US$',1),
('DT.AXA.DLXF.CD','Principal arrears, long-term DOD','other',1),
('DT.AXA.OFFT.CD','Principal arrears, official creditors (current US$)','current US$',1),
('DT.AXA.PRVT.CD','Principal arrears, private creditors (current US$)','current US$',1),
('DT.AXF.DPPG.CD','Principal forgiven (current US$)','current US$',1),
('DT.AXR.DPPG.CD','Principal rescheduled (current US$)','current US$',1),
('DT.AXR.OFFT.CD','Principal rescheduled, official (current US$)','current US$',1),
('DT.AXR.PRVT.CD','Principal rescheduled, private (current US$)','current US$',1),
('DT.COM.BLAT.CD','Commitments, bilateral creditors (COM, current US$)','current US$',1),
('DT.COM.DPPG.CD','Commitments, public and publicly guaranteed (COM, current US$)','current US$',1),
('DT.COM.MIBR.CD','Commitments, IBRD (COM, current US$)','current US$',1),
('DT.COM.MIDA.CD','Commitments, IDA (COM, current US$)','current US$',1),
('DT.COM.MLAT.CD','Commitments, multilateral creditors (COM, current US$)','current US$',1),
('DT.COM.OFFT.CD','Commitments, official creditors (COM, current US$)','current US$',1),
('DT.COM.PRVT.CD','Commitments, private creditors (COM, current US$)','current US$',1),
('DT.CUR.DMAK.ZS','Currency composition of PPG debt, Deutsche mark (%)','%',1),
('DT.CUR.EURO.ZS','Currency composition of PPG debt, Euro (%)','%',1),
('DT.CUR.FFRC.ZS','Currency composition of PPG debt, French franc (%)','%',1),
('DT.CUR.JYEN.ZS','Currency composition of PPG debt, Japanese yen (%)','%',1),
('DT.CUR.MULC.ZS','Currency composition of PPG debt, Multiple currencies (%)','%',1),
('DT.CUR.OTHC.ZS','Currency composition of PPG debt, all other currencies (%)','%',1),
('DT.CUR.SDRW.ZS','Currency composition of PPG debt, SDR (%)','%',1),
('DT.CUR.SWFR.ZS','Currency composition of PPG debt, Swiss franc (%)','%',1),
('DT.CUR.UKPS.ZS','Currency composition of PPG debt, Pound sterling (%)','%',1),
('DT.CUR.USDL.ZS','Currency composition of PPG debt, U.S. dollars (%)','%',1),
('DT.DFR.DPPG.CD','Debt forgiveness or reduction (current US$)','current US$',1),
('DT.DIS.BLAT.CB.CD','CB, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLAT.CD','PPG, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLAT.GG.CD','GG, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLAT.OPS.CD','OPS, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLAT.PRVG.CD','PRVG, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLAT.PS.CD','PS, bilateral (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.CB.CD','CB, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.CD','PPG, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.GG.CD','GG, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.OPS.CD','OPS, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.PRVG.CD','PRVG, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.BLTC.PS.CD','PS, bilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.DECB.CD','Disbursements on external debt, central bank (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.DEGG.CD','Disbursements on external debt, general government sector (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.DEPS.CD','Disbursements on external debt, public sector (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.DIMF.CD','IMF purchases (DIS, current US$)','current US$',1),
('DT.DIS.DLTF.CD','Disbursements on external debt, long-term + IMF (DIS, current US$)','current US$',1),
('DT.DIS.DLXF.CD','Disbursements on external debt, long-term (DIS, current US$)','current US$',1),
('DT.DIS.DOPS.CD','Disbursements on external debt, other public sector (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.DPNG.CD','Disbursements on external debt, private nonguaranteed (PNG) (DIS, current US$)','current US$',1),
('DT.DIS.DPPG.CD','Disbursements on external debt, public and publicly guaranteed (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.IDAG.CD','IDA grants (current US$)','current US$',1),
('DT.DIS.MIBR.CD','PPG, IBRD (DIS, current US$)','current US$',1),
('DT.DIS.MIDA.CD','PPG, IDA (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.CB.CD','CB, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.CD','PPG, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.GG.CD','GG, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.OPS.CD','OPS, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.PRVG.CD','PRVG, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLAT.PS.CD','PS, multilateral (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.CB.CD','CB, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.CD','PPG, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.GG.CD','GG, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.OPS.CD','OPS, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.PRVG.CD','PRVG, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.MLTC.PS.CD','PS, multilateral concessional (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.CB.CD','CB, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.CD','PPG, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.GG.CD','GG, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.OPS.CD','OPS, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.PRVG.CD','PRVG, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.OFFT.PS.CD','PS, official creditors (DIS, current US$)','current US$',1),
('DT.DIS.PBND.CB.CD','CB, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PBND.CD','PPG, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PBND.GG.CD','GG, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PBND.OPS.CD','OPS, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PBND.PRVG.CD','PRVG, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PBND.PS.CD','PS, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.CB.CD','CB, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.CD','PPG, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.GG.CD','GG, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.OPS.CD','OPS, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.PRVG.CD','PRVG, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PCBK.PS.CD','PS, commercial banks (DIS, current US$)','current US$',1),
('DT.DIS.PNGB.CD','PNG, bonds (DIS, current US$)','current US$',1),
('DT.DIS.PNGC.CD','PNG, commercial banks and other creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.CB.CD','CB, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.CD','PPG, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.GG.CD','GG, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.OPS.CD','OPS, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.PRVG.CD','PRVG, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PROP.PS.CD','PS, other private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRPG.CD','Disbursements on external debt, private guaranteed by public sector (PPG) (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.CB.CD','CB, private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.CD','PPG, private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.GG.CD','GG, private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.OPS.CD','OPS, private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.PRVG.CD','PRVG, private creditors (DIS, current US$)','current US$',1),
('DT.DIS.PRVT.PS.CD','PS, private creditors (DIS, current US$)','current US$',1),
('DT.DOD.ALLC.CD','External debt stocks, concessional (DOD, current US$)','current US$',1),
('DT.DOD.ALLC.ZS','Concessional debt (% of total external debt)','%',1),
('DT.DOD.BLAT.CB.CD','CB, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLAT.CD','PPG, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLAT.GG.CD','GG, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLAT.OPS.CD','OPS, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLAT.PRVG.CD','PRVG, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLAT.PS.CD','PS, bilateral (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.CB.CD','CB, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.CD','PPG, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.GG.CD','GG, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.OPS.CD','OPS, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.PRVG.CD','PRVG, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.BLTC.PS.CD','PS, bilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.DECB.CD','External debt stocks, central bank (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.DECT.CD','External debt stocks, total (DOD, current US$)','current US$',1),
('DT.DOD.DECT.CD.CG','Total change in external debt stocks (current US$)','current US$',1),
('DT.DOD.DECT.EX.ZS','External debt stocks (% of exports of goods, services and primary income)','%',1),
('DT.DOD.DECT.GN.ZS','External debt stocks (% of GNI)','%',1),
('DT.DOD.DECT.PC.CD','Total external debt per capita (US$)','US$',1),
('DT.DOD.DEGG.CD','External debt stocks, general government sector (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.DEPS.CD','External debt stocks, public sector (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.DIMF.CD','Use of IMF credit and SDR allocations (DOD, current US$)','current US$',1),
('DT.DOD.DIMF.US.CD','Use of IMF credit (DOD, current US$)','current US$',1),
('DT.DOD.DLXF.CD','External debt stocks, long-term (DOD, current US$)','current US$',1),
('DT.DOD.DOPS.CD','External debt stocks, other public sector (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.DPNG.CD','External debt stocks, private nonguaranteed (PNG) (DOD, current US$)','current US$',1),
('DT.DOD.DPPG.CD','External debt stocks, public and publicly guaranteed (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.DSDR.CD','IMF SDR allocations (DOD, current US$)','current US$',1),
('DT.DOD.DSTC.CD','External debt stocks, short-term (DOD, current US$)','current US$',1),
('DT.DOD.DSTC.ZS','Short-term debt (% of total external debt)','%',1),
('DT.DOD.MDRI.CD','Debt forgiveness grants (current US$)','current US$',1),
('DT.DOD.MIBR.CD','PPG, IBRD (DOD, current US$)','current US$',1),
('DT.DOD.MIDA.CD','PPG, IDA (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.CB.CD','CB, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.CD','PPG, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.GG.CD','GG, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.OPS.CD','OPS, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.PRVG.CD','PRVG, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.PS.CD','PS, multilateral (DOD, current US$)','current US$',1),
('DT.DOD.MLAT.ZS','Multilateral debt (% of total external debt)','%',1),
('DT.DOD.MLTC.CB.CD','CB, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.MLTC.CD','PPG, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.MLTC.GG.CD','GG, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.MLTC.OPS.CD','OPS, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.MLTC.PRVG.CD','PRVG, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.MLTC.PS.CD','PS, multilateral concessional (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.CB.CD','CB, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.CD','PPG, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.GG.CD','GG, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.OPS.CD','OPS, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.PRVG.CD','PRVG, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.OFFT.PS.CD','PS, official creditors (DOD, current US$)','current US$',1),
('DT.DOD.PBND.CB.CD','CB, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PBND.CD','PPG, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PBND.GG.CD','GG, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PBND.OPS.CD','OPS, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PBND.PRVG.CD','PRVG, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PBND.PS.CD','PS, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.CB.CD','CB, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.CD','PPG, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.GG.CD','GG, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.OPS.CD','OPS, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.PRVG.CD','PRVG, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PCBK.PS.CD','PS, commercial banks (DOD, current US$)','current US$',1),
('DT.DOD.PNGB.CD','PNG, bonds (DOD, current US$)','current US$',1),
('DT.DOD.PNGC.CD','PNG, commercial banks and other creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.CB.CD','CB, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.CD','PPG, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.GG.CD','GG, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.OPS.CD','OPS, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.PRVG.CD','PRVG, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PROP.PS.CD','PS, other private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRPG.CD','External debt stocks, private guaranteed by public sector (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.PRVS.CD','External debt stocks, long-term private sector (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.CB.CD','CB, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.CD','PPG, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.GG.CD','GG, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.OPS.CD','OPS, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.PRVG.CD','PRVG, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PRVT.PS.CD','PS, private creditors (DOD, current US$)','current US$',1),
('DT.DOD.PUBS.CD','External debt stocks, long-term public sector (DOD, current US$)','current US$',1),
('DT.DOD.PVLX.CD','Present value of external debt (current US$)','current US$',1),
('DT.DOD.PVLX.EX.ZS','Present value of debt (% of exports of goods, services and primary income)','%',1),
('DT.DOD.PVLX.GN.ZS','Present value of debt (% of GNI)','%',1),
('DT.DOD.RSDL.CD','Residual, debt stock-flow reconciliation (current US$)','current US$',1),
('DT.DOD.VPPG.CD','External debt stocks, variable rate public and publicly guaranteed debt (PPG) (DOD, current US$)','current US$',1),
('DT.DOD.VTOT.CD','External debt stocks, variable rate (DOD, current US$)','current US$',1),
('DT.DSB.DPPG.CD','Debt buyback (current US$)','current US$',1),
('DT.DSF.DPPG.CD','Debt stock reduction (current US$)','current US$',1),
('DT.DXR.DPPG.CD','Debt stock rescheduled (current US$)','current US$',1),
('DT.GPA.DPPG','Average grace period on new external debt commitments (years)','years',1),
('DT.GPA.OFFT','Average grace period on new external debt commitments, official (years)','years',1),
('DT.GPA.PRVT','Average grace period on new external debt commitments, private (years)','years',1),
('DT.GRE.DPPG','Average grant element on new external debt commitments (%)','%',1),
('DT.GRE.OFFT','Average grant element on new external debt commitments, official (%)','%',1),
('DT.GRE.PRVT','Average grant element on new external debt commitments, private (%)','%',1),
('DT.INR.DPPG','Average interest on new external debt commitments (%)','%',1),
('DT.INR.OFFT','Average interest on new external debt commitments, official (%)','%',1),
('DT.INR.PRVT','Average interest on new external debt commitments, private (%)','%',1),
('DT.INT.BLAT.CB.CD','CB, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLAT.CD','PPG, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLAT.GG.CD','GG, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLAT.OPS.CD','OPS, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLAT.PRVG.CD','PRVG, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLAT.PS.CD','PS, bilateral (INT, current US$)','current US$',1),
('DT.INT.BLTC.CB.CD','CB, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.BLTC.CD','PPG, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.BLTC.GG.CD','GG, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.BLTC.OPS.CD','OPS, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.BLTC.PRVG.CD','PRVG, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.BLTC.PS.CD','PS, bilateral concessional (INT, current US$)','current US$',1),
('DT.INT.DECB.CD','Interest payments on external debt, central bank (PPG) (INT, current US$)','current US$',1),
('DT.INT.DECT.CD','Interest payments on external debt, total (INT, current US$)','current US$',1),
('DT.INT.DECT.EX.ZS','Interest payments on external debt (% of exports of goods, services and primary income)','%',1),
('DT.INT.DECT.GN.ZS','Interest payments on external debt (% of GNI)','%',1),
('DT.INT.DEGG.CD','Interest payments on external debt, general government sector (PPG) (INT, current US$)','current US$',1),
('DT.INT.DEPS.CD','Interest payments on external debt, public sector (PPG) (INT, current US$)','current US$',1),
('DT.INT.DIMF.CD','IMF credit and SDR allocations, charges (INT, current US$)','current US$',1),
('DT.INT.DIMF.US.CD','IMF credit, charges (INT, current US$)','current US$',1),
('DT.INT.DLXF.CD','Interest payments on external debt, long-term (INT, current US$)','current US$',1),
('DT.INT.DOPS.CD','Interest payments on external debt, other public sector (PPG) (INT, current US$)','current US$',1),
('DT.INT.DPNG.CD','Interest payments on external debt, private nonguaranteed (PNG) (INT, current US$)','current US$',1),
('DT.INT.DPPG.CD','Interest payments on external debt, public and publicly guaranteed (PPG) (INT, current US$)','current US$',1),
('DT.INT.DSDR.CD','IMF SDR allocations, charges (INT, current US$)','current US$',1),
('DT.INT.DSTC.CD','Interest payments on external debt, short-term (INT, current US$)','current US$',1),
('DT.INT.MIBR.CD','PPG, IBRD (INT, current US$)','current US$',1),
('DT.INT.MIDA.CD','PPG, IDA (INT, current US$)','current US$',1),
('DT.INT.MLAT.CB.CD','CB, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLAT.CD','PPG, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLAT.GG.CD','GG, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLAT.OPS.CD','OPS, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLAT.PRVG.CD','PRVG, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLAT.PS.CD','PS, multilateral (INT, current US$)','current US$',1),
('DT.INT.MLTC.CB.CD','CB, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.MLTC.CD','PPG, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.MLTC.GG.CD','GG, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.MLTC.OPS.CD','OPS, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.MLTC.PRVG.CD','PRVG, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.MLTC.PS.CD','PS, multilateral concessional (INT, current US$)','current US$',1),
('DT.INT.OFFT.CB.CD','CB, official creditors (INT, current US$)','current US$',1),
('DT.INT.OFFT.CD','PPG, official creditors (INT, current US$)','current US$',1),
('DT.INT.OFFT.GG.CD','GG, official creditors (INT, current US$)','current US$',1),
('DT.INT.OFFT.OPS.CD','OPS, official creditors (INT, current US$)','current US$',1),
('DT.INT.OFFT.PRVG.CD','PRVG, official creditors (INT, current US$)','current US$',1),
('DT.INT.OFFT.PS.CD','PS, official creditors (INT, current US$)','current US$',1),
('DT.INT.PBND.CB.CD','CB, bonds (INT, current US$)','current US$',1),
('DT.INT.PBND.CD','PPG, bonds (INT, current US$)','current US$',1),
('DT.INT.PBND.GG.CD','GG, bonds (INT, current US$)','current US$',1),
('DT.INT.PBND.OPS.CD','OPS, bonds (INT, current US$)','current US$',1),
('DT.INT.PBND.PRVG.CD','PRVG, bonds (INT, current US$)','current US$',1),
('DT.INT.PBND.PS.CD','PS, bonds (INT, current US$)','current US$',1),
('DT.INT.PCBK.CB.CD','CB, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PCBK.CD','PPG, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PCBK.GG.CD','GG, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PCBK.OPS.CD','OPS, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PCBK.PRVG.CD','PRVG, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PCBK.PS.CD','PS, commercial banks (INT, current US$)','current US$',1),
('DT.INT.PNGB.CD','PNG, bonds (INT, current US$)','current US$',1),
('DT.INT.PNGC.CD','PNG, commercial banks and other creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.CB.CD','CB, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.CD','PPG, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.GG.CD','GG, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.OPS.CD','OPS, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.PRVG.CD','PRVG, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PROP.PS.CD','PS, other private creditors (INT, current US$)','current US$',1),
('DT.INT.PRPG.CD','Interest payments on external debt, private guaranteed by public sector (PPG) (INT, current US$)','current US$',1),
('DT.INT.PRVT.CB.CD','CB, private creditors (INT, current US$)','current US$',1),
('DT.INT.PRVT.CD','PPG, private creditors (INT, current US$)','current US$',1),
('DT.INT.PRVT.GG.CD','GG, private creditors (INT, current US$)','current US$',1),
('DT.INT.PRVT.OPS.CD','OPS, private creditors (INT, current US$)','current US$',1),
('DT.INT.PRVT.PRVG.CD','PRVG, private creditors (INT, current US$)','current US$',1),
('DT.INT.PRVT.PS.CD','PS, private creditors (INT, current US$)','current US$',1),
('DT.INT.VPPG.CD','Interest payments on variable rate external debt, public and publicly guaranteed (PPG) (INT, current US$)','current US$',1),
('DT.INT.VTOT.CD','Interest payments on variable rate external debt, long-term (INT, current US$)','current US$',1),
('DT.IXA.DLXF.CD','Interest arrears, long-term DOD','other',1),
('DT.IXA.DPPG.CD.CG','Net change in interest arrears (current US$)','current US$',1),
('DT.IXA.OFFT.CD','Interest arrears, official creditors (current US$)','current US$',1),
('DT.IXA.PRVT.CD','Interest arrears, private creditors (current US$)','current US$',1),
('DT.IXF.DPPG.CD','Interest forgiven (current US$)','current US$',1),
('DT.IXR.DPPG.CD','Interest rescheduled (capitalized) (current US$)','current US$',1),
('DT.IXR.OFFT.CD','Interest rescheduled, official (current US$)','current US$',1),
('DT.IXR.PRVT.CD','Interest rescheduled, private (current US$)','current US$',1),
('DT.MAT.DPPG','Average maturity on new external debt commitments (years)','years',1),
('DT.MAT.OFFT','Average maturity on new external debt commitments, official (years)','years',1),
('DT.MAT.PRVT','Average maturity on new external debt commitments, private (years)','years',1),
('DT.NFL.BLAT.CB.CD','CB, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLAT.CD','Net financial flows, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLAT.GG.CD','GG, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLAT.OPS.CD','OPS, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLAT.PRVG.CD','PRVG, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLAT.PS.CD','PS, bilateral (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.CB.CD','CB, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.CD','PPG, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.GG.CD','GG, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.OPS.CD','OPS, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.PRVG.CD','PRVG, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.BLTC.PS.CD','PS, bilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.DECB.CD','Net flows on external debt, central bank (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.DECT.CD','Net flows on external debt, total (NFL, current US$)','current US$',1),
('DT.NFL.DEGG.CD','Net flows on external debt, general government sector (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.DEPS.CD','Net flows on external debt, public sector (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.DLXF.CD','Net flows on external debt, long-term (NFL, current US$)','current US$',1),
('DT.NFL.DOPS.CD','Net flows on external debt, other public sector (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.DPNG.CD','Net flows on external debt, private nonguaranteed (PNG) (NFL, current US$)','current US$',1),
('DT.NFL.DPPG.CD','Net flows on external debt, public and publicly guaranteed (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.DSTC.CD','Net flows on external debt, short-term (NFL, current US$)','current US$',1),
('DT.NFL.IMFC.CD','Net financial flows, IMF concessional (NFL, current US$)','current US$',1),
('DT.NFL.IMFN.CD','Net financial flows, IMF nonconcessional (NFL, current US$)','current US$',1),
('DT.NFL.MIBR.CD','Net financial flows, IBRD (NFL, current US$)','current US$',1),
('DT.NFL.MIDA.CD','Net financial flows, IDA (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.CB.CD','CB, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.CD','Net financial flows, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.GG.CD','GG, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.OPS.CD','OPS, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.PRVG.CD','PRVG, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLAT.PS.CD','PS, multilateral (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.CB.CD','CB, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.CD','PPG, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.GG.CD','GG, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.OPS.CD','OPS, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.PRVG.CD','PRVG, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MLTC.PS.CD','PS, multilateral concessional (NFL, current US$)','current US$',1),
('DT.NFL.MOTH.CD','Net financial flows, others (NFL, current US$)','current US$',1),
('DT.NFL.NIFC.CD','IFC, private nonguaranteed (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.CB.CD','CB, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.CD','PPG, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.GG.CD','GG, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.OPS.CD','OPS, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.PRVG.CD','PRVG, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.OFFT.PS.CD','PS, official creditors (NFL, current US$)','current US$',1),
('DT.NFL.PBND.CB.CD','CB, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PBND.CD','PPG, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PBND.GG.CD','GG, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PBND.OPS.CD','OPS, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PBND.PRVG.CD','PRVG, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PBND.PS.CD','PS, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.CB.CD','CB, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.CD','PPG, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.GG.CD','GG, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.OPS.CD','OPS, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.PRVG.CD','PRVG, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PCBK.PS.CD','PS, commercial banks (NFL, current US$)','current US$',1),
('DT.NFL.PNGB.CD','PNG, bonds (NFL, current US$)','current US$',1),
('DT.NFL.PNGC.CD','PNG, commercial banks and other creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.CB.CD','CB, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.CD','PPG, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.GG.CD','GG, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.OPS.CD','OPS, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.PRVG.CD','PRVG, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PROP.PS.CD','PS, other private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRPG.CD','Net flows on external debt, private guaranteed by public sector (PPG) (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.CB.CD','CB, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.CD','PPG, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.GG.CD','GG, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.OPS.CD','OPS, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.PRVG.CD','PRVG, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.PRVT.PS.CD','PS, private creditors (NFL, current US$)','current US$',1),
('DT.NFL.RDBC.CD','Net financial flows, RDB concessional (NFL, current US$)','current US$',1),
('DT.NFL.RDBN.CD','Net financial flows, RDB nonconcessional (NFL, current US$)','current US$',1),
('DT.NTR.BLAT.CB.CD','CB, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLAT.CD','PPG, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLAT.GG.CD','GG, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLAT.OPS.CD','OPS, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLAT.PRVG.CD','PRVG, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLAT.PS.CD','PS, bilateral (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.CB.CD','CB, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.CD','PPG, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.GG.CD','GG, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.OPS.CD','OPS, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.PRVG.CD','PRVG, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.BLTC.PS.CD','PS, bilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.DECB.CD','Net transfers on external debt, central bank (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.DECT.CD','Net transfers on external debt, total (NTR, current US$)','current US$',1),
('DT.NTR.DEGG.CD','Net transfers on external debt, general government sector (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.DEPS.CD','Net transfers on external debt, public sector (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.DLXF.CD','Net transfers on external debt, long-term (NTR, current US$)','current US$',1),
('DT.NTR.DOPS.CD','Net transfers on external debt, other public sector (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.DPNG.CD','Net transfers on external debt, private nonguaranteed (PNG) (NTR, current US$)','current US$',1),
('DT.NTR.DPPG.CD','Net transfers on external debt, public and publicly guaranteed (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.MIBR.CD','PPG, IBRD (NTR, current US$)','current US$',1),
('DT.NTR.MIDA.CD','PPG, IDA (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.CB.CD','CB, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.CD','PPG, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.GG.CD','GG, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.OPS.CD','OPS, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.PRVG.CD','PRVG, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLAT.PS.CD','PS, multilateral (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.CB.CD','CB, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.CD','PPG, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.GG.CD','GG, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.OPS.CD','OPS, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.PRVG.CD','PRVG, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.MLTC.PS.CD','PS, multilateral concessional (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.CB.CD','CB, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.CD','PPG, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.GG.CD','GG, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.OPS.CD','OPS, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.PRVG.CD','PRVG, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.OFFT.PS.CD','PS, official creditors (NTR, current US$)','current US$',1),
('DT.NTR.PBND.CB.CD','CB, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PBND.CD','PPG, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PBND.GG.CD','GG, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PBND.OPS.CD','OPS, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PBND.PRVG.CD','PRVG, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PBND.PS.CD','PS, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.CB.CD','CB, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.CD','PPG, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.GG.CD','GG, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.OPS.CD','OPS, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.PRVG.CD','PRVG, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PCBK.PS.CD','PS, commercial banks (NTR, current US$)','current US$',1),
('DT.NTR.PNGB.CD','PNG, bonds (NTR, current US$)','current US$',1),
('DT.NTR.PNGC.CD','PNG, commercial banks and other creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.CB.CD','CB, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.CD','PPG, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.GG.CD','GG, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.OPS.CD','OPS, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.PRVG.CD','PRVG, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PROP.PS.CD','PS, other private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRPG.CD','Net transfers on external debt, private guaranteed by public sector (PPG) (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.CB.CD','CB, private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.CD','PPG, private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.GG.CD','GG, private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.OPS.CD','OPS, private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.PRVG.CD','PRVG, private creditors (NTR, current US$)','current US$',1),
('DT.NTR.PRVT.PS.CD','PS, private creditors (NTR, current US$)','current US$',1),
('DT.TDS.BLAT.CB.CD','CB, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLAT.CD','PPG, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLAT.GG.CD','GG, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLAT.OPS.CD','OPS, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLAT.PRVG.CD','PRVG, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLAT.PS.CD','PS, bilateral (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.CB.CD','CB, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.CD','PPG, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.GG.CD','GG, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.OPS.CD','OPS, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.PRVG.CD','PRVG, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.BLTC.PS.CD','PS, bilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.DECB.CD','Debt service on external debt, central bank (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.DECT.CD','Debt service on external debt, total (TDS, current US$)','current US$',1),
('DT.TDS.DECT.EX.ZS','Total debt service (% of exports of goods, services and primary income)','%',1),
('DT.TDS.DEGG.CD','Debt service on external debt, general government sector (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.DEPS.CD','Debt service on external debt, public sector (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.DIMF.CD','IMF repurchases and charges (TDS, current US$)','current US$',1),
('DT.TDS.DLXF.CD','Debt service on external debt, long-term (TDS, current US$)','current US$',1),
('DT.TDS.DOPS.CD','Debt service on external debt, other public sector (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.DPNG.CD','Debt service on external debt, private nonguaranteed (PNG) (TDS, current US$)','current US$',1),
('DT.TDS.DPPG.CD','Debt service on external debt, public and publicly guaranteed (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.MIBR.CD','PPG, IBRD (TDS, current US$)','current US$',1),
('DT.TDS.MIDA.CD','PPG, IDA (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.CB.CD','CB, multilateral (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.CD','Multilateral debt service (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.GG.CD','GG, multilateral (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.OPS.CD','OPS, multilateral (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.PRVG.CD','PRVG, multilateral (TDS, current US$)','current US$',1),
('DT.TDS.MLAT.PS.CD','PS, multilateral (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.CB.CD','CB, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.CD','PPG, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.GG.CD','GG, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.OPS.CD','OPS, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.PRVG.CD','PRVG, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.MLTC.PS.CD','PS, multilateral concessional (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.CB.CD','CB, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.CD','PPG, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.GG.CD','GG, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.OPS.CD','OPS, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.PRVG.CD','PRVG, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.OFFT.PS.CD','PS, official creditors (TDS, current US$)','current US$',1),
('DT.TDS.PBND.CB.CD','CB, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PBND.CD','PPG, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PBND.GG.CD','GG, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PBND.OPS.CD','OPS, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PBND.PRVG.CD','PRVG, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PBND.PS.CD','PS, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.CB.CD','CB, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.CD','PPG, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.GG.CD','GG, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.OPS.CD','OPS, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.PRVG.CD','PRVG, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PCBK.PS.CD','PS, commercial banks (TDS, current US$)','current US$',1),
('DT.TDS.PNGB.CD','PNG, bonds (TDS, current US$)','current US$',1),
('DT.TDS.PNGC.CD','PNG, commercial banks and other creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.CB.CD','CB, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.CD','PPG, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.GG.CD','GG, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.OPS.CD','OPS, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.PRVG.CD','PRVG, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PROP.PS.CD','PS, other private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRPG.CD','Debt service on external debt, private guaranteed by public sector (PPG) (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.CB.CD','CB, private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.CD','PPG, private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.GG.CD','GG, private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.OPS.CD','OPS, private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.PRVG.CD','PRVG, private creditors (TDS, current US$)','current US$',1),
('DT.TDS.PRVT.PS.CD','PS, private creditors (TDS, current US$)','current US$',1),
('DT.TXR.DPPG.CD','Total amount of debt rescheduled (current US$)','current US$',1),
('DT.UND.DPPG.CD','Undisbursed external debt, total (UND, current US$)','current US$',1),
('DT.UND.OFFT.CD','Undisbursed external debt, official creditors (UND, current US$)','current US$',1),
('DT.UND.PRVT.CD','Undisbursed external debt, private creditors (UND, current US$)','current US$',1),
('FI.RES.TOTL.CD','Total reserves (includes gold, current US$)','current US$',0),
('FI.RES.TOTL.DT.ZS','Total reserves (% of total external debt)','%',0),
('FI.RES.TOTL.MO','Total reserves in months of imports','months of imports',0),
('NY.GNP.MKTP.CD','GNI (current US$)','current US$',0),
('SP.POP.TOTL','Population, total','other',0)
ON DUPLICATE KEY UPDATE
    indicator_name    = VALUES(indicator_name),
    unit              = VALUES(unit),
    is_debt_indicator = VALUES(is_debt_indicator);

/* ---- Verify ---- */
SELECT COUNT(*) AS indicators_loaded FROM indicators;                 -- expect 576
SELECT is_debt_indicator, COUNT(*) AS n FROM indicators GROUP BY is_debt_indicator;   -- 562 / 14

/* ---- Queries on the lookup data ---- */

-- 1. Indicators by unit and debt flag
SELECT unit, is_debt_indicator, COUNT(*) AS indicators
FROM indicators
GROUP BY unit, is_debt_indicator
ORDER BY indicators DESC;

-- 2. Indicator families (series prefix)
SELECT series_group,
       CASE series_group
            WHEN 'DT.DOD' THEN 'Debt stocks'
            WHEN 'DT.TDS' THEN 'Debt service'
            WHEN 'DT.INT' THEN 'Interest payments'
            WHEN 'DT.AMT' THEN 'Principal repayments'
            WHEN 'DT.DIS' THEN 'Disbursements'
            WHEN 'DT.NFL' THEN 'Net flows'
            WHEN 'DT.NTR' THEN 'Net transfers'
            ELSE 'Other' END AS meaning,
       COUNT(*) AS indicators,
       MIN(indicator_name) AS example
FROM indicators
GROUP BY series_group
ORDER BY indicators DESC;

-- 3. Search indicators by keyword (edit the pattern)
SELECT indicator_code, indicator_name, unit
FROM indicators
WHERE indicator_name LIKE '%multilateral%' AND unit = 'current US$'
ORDER BY indicator_code;

-- 4. Non-debt indicators (is_debt_indicator = 0)
SELECT indicator_code, indicator_name, unit
FROM indicators
WHERE is_debt_indicator = 0
ORDER BY indicator_code;

-- 5. Look up one indicator by code
SELECT * FROM indicators WHERE indicator_code = 'DT.DOD.DECT.CD';
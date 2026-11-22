/* =====================================================================
   CROSS-VERIFY THE 3 DATASETS (countries, indicators, debt_data)
   Run in MySQL Workbench after debt_analysis.sql + the debt CSV import.
   Select a query (or the whole file) and press Ctrl+Shift+Enter.
   "EXPECTED" values come from the original CSV files.
   ===================================================================== */
USE debt_db;
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;


/* ---------------------------------------------------------------------
   1. ROW COUNTS: tables vs CSV files
   --------------------------------------------------------------------- */
SELECT 'countries'  AS table_name, COUNT(*) AS rows_in_db, 134     AS expected_from_csv FROM countries
UNION ALL
SELECT 'indicators',               COUNT(*),               576     FROM indicators
UNION ALL
SELECT 'debt_data',                COUNT(*),               1302241 FROM debt_data;
-- every row must match its expected number


/* ---------------------------------------------------------------------
   2. ORPHAN CHECKS: every debt row must point to a real country + indicator
      (all three results should be 0)
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS debt_rows_without_country
FROM debt_data d
LEFT JOIN countries c ON c.country_code = d.country_code
WHERE c.country_code IS NULL;

SELECT COUNT(*) AS debt_rows_without_indicator
FROM debt_data d
LEFT JOIN indicators i ON i.indicator_code = d.indicator_code
WHERE i.indicator_code IS NULL;

SELECT COUNT(*) AS duplicate_country_indicator_year
FROM (SELECT country_code, indicator_code, year
      FROM debt_data
      GROUP BY country_code, indicator_code, year
      HAVING COUNT(*) > 1) x;


/* ---------------------------------------------------------------------
   3. COVERAGE: which master records have / lack debt data
   --------------------------------------------------------------------- */
-- 3a. Distinct codes actually used in debt_data
SELECT COUNT(DISTINCT country_code)   AS countries_with_data,    -- expected 134
       COUNT(DISTINCT indicator_code) AS indicators_with_data    -- expected 562
FROM debt_data;

-- 3b. Countries with NO debt data (expected 0 rows)
SELECT c.country_code, c.country_name
FROM countries c
LEFT JOIN debt_data d ON d.country_code = c.country_code
WHERE d.debt_id IS NULL;

-- 3c. Indicators with NO debt data (expected 14 rows, all is_debt_indicator = 0)
SELECT i.indicator_code, i.indicator_name, i.is_debt_indicator
FROM indicators i
LEFT JOIN debt_data d ON d.indicator_code = i.indicator_code
WHERE d.debt_id IS NULL
ORDER BY i.indicator_code;

-- 3d. Debt-flagged indicators missing data (expected 0)
SELECT COUNT(*) AS debt_indicators_without_data
FROM indicators i
WHERE i.is_debt_indicator = 1
  AND NOT EXISTS (SELECT 1 FROM debt_data d WHERE d.indicator_code = i.indicator_code);


/* ---------------------------------------------------------------------
   4. VALUE CHECKS on debt_data vs the CSV
   --------------------------------------------------------------------- */
SELECT MIN(year)                  AS min_year,        -- expected 2000
       MAX(year)                  AS max_year,        -- expected 2032
       COUNT(DISTINCT year)       AS distinct_years,  -- expected 33
       SUM(value IS NULL)         AS null_values,     -- expected 0
       SUM(value < 0)             AS negative_values, -- expected 129524 (CSV has 129530; 6 tiny values round to 0 at 4 decimals)
       SUM(value = 0)             AS zero_values,     -- expected 159504 (CSV has 159496; +8 from that same rounding)
       ROUND(SUM(value), 0)       AS total_of_all_values  -- expected about 8055917952623726
FROM debt_data;

-- Actual vs projected rows (2025-2032 are scheduled future payments)
SELECT CASE WHEN year <= 2024 THEN 'Actual (2000-2024)' ELSE 'Projected (2025-2032)' END AS period,
       COUNT(*) AS rows_in_db           -- expected 1204130 / 98111
FROM debt_data
GROUP BY period;


/* ---------------------------------------------------------------------
   5. METADATA CHECKS on countries and indicators
   --------------------------------------------------------------------- */
SELECT entity_type, COUNT(*) AS n            -- expected Country 120, Aggregate 14
FROM countries GROUP BY entity_type;

SELECT SUM(is_hipc) AS hipc_countries       -- expected 40
FROM countries;

SELECT is_debt_indicator, COUNT(*) AS n      -- expected 0 -> 14, 1 -> 562
FROM indicators GROUP BY is_debt_indicator;

-- Missing region / income group (expected: Country 0 / 1 [Ethiopia has no income group]; Aggregate 14 / 14)
SELECT entity_type, SUM(region IS NULL) AS no_region, SUM(income_group IS NULL) AS no_income_group
FROM countries GROUP BY entity_type;


/* ---------------------------------------------------------------------
   6. PRIMARY + FOREIGN KEYS exist
   --------------------------------------------------------------------- */
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'debt_db'
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')
ORDER BY table_name, constraint_type;

SELECT table_name, column_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'debt_db' AND referenced_table_name IS NOT NULL;
-- expected: debt_data.country_code -> countries, debt_data.indicator_code -> indicators


/* ---------------------------------------------------------------------
   7. RECONCILIATION: do the numbers make sense across tables?
   --------------------------------------------------------------------- */
-- 7a. Rows per country type (aggregates vs real countries)
SELECT c.entity_type, COUNT(*) AS debt_rows, COUNT(DISTINCT c.country_code) AS entities
FROM debt_data d JOIN countries c USING (country_code)
GROUP BY c.entity_type;

-- 7b. Rows per indicator family; the families should add up to the total
SELECT i.series_group, COUNT(*) AS debt_rows
FROM debt_data d JOIN indicators i USING (indicator_code)
GROUP BY i.series_group
ORDER BY debt_rows DESC;

-- 7c. Total debt stock 2024: sum of the 120 countries vs the aggregate rows
--     (verified: 120 countries = 8,939,920,662,152, matching the 'Low & middle income' (LMY) aggregate of 8.94 trillion)
SELECT c.entity_type, c.country_code, c.country_name, d.value AS debt_stock_2024
FROM debt_data d JOIN countries c USING (country_code)
WHERE d.indicator_code = 'DT.DOD.DECT.CD' AND d.year = 2024
  AND (c.entity_type = 'Aggregate' OR c.country_code = 'LMY')
ORDER BY d.value DESC;

SELECT ROUND(SUM(d.value), 0) AS sum_of_120_countries_2024
FROM debt_data d JOIN countries c USING (country_code)
WHERE d.indicator_code = 'DT.DOD.DECT.CD' AND d.year = 2024 AND c.entity_type = 'Country';

-- 7d. Coverage of the main indicator by year
SELECT d.year, COUNT(DISTINCT d.country_code) AS countries_reporting   -- 127 in 2000 rising to 134 from 2019 (later joiners)
FROM debt_data d
WHERE d.indicator_code = 'DT.DOD.DECT.CD'
GROUP BY d.year
ORDER BY d.year;

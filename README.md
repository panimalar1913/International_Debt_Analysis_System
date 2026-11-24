# International Debt Analysis System

An interactive data-analysis project for exploring World Bank International Debt Statistics (IDS). The system cleans and transforms country debt data, performs statistical and trend analysis, stores the processed data in MySQL, and presents the results through a Streamlit dashboard.

## Features

- Clean and standardize World Bank country, series, and debt datasets
- Export cleaned data in wide and long formats
- Load countries, indicators, and debt observations into MySQL
- Explore debt indicators and countries through interactive filters
- Compare top debtors and total debt by indicator
- View historical debt trends and country-year heatmaps
- Inspect debt distributions and filtered source data
- Generate static charts and statistical output files

## Dashboard

Run the main dashboard with:

```powershell
streamlit run app.py
```

The dashboard provides:

- Country-wise debt rankings and historical trends
- Indicator-wise comparisons
- A filtered data preview
- Year and country selection
- Total countries, indicators, and selected-year debt KPIs

## Project Structure

```text
International_Debt Analysis System/
|-- app.py                  # Streamlit interactive dashboard
|-- Analysis.py             # Statistical analysis and chart generation
|-- Audit.py                # Quick dataset audit and schema inspection
|-- clean.py                # Data cleaning and transformation pipeline
|-- debt_analysis.ipynb     # Exploratory notebook
|-- requirements.txt        # Python dependencies
|-- data/
|   |-- IDS_ALLCountries_Data.csv
|   |-- IDS_CountryMetaData.csv
|   |-- IDS_SeriesMetaData.csv
|   |-- IDS_FootNoteMetaData.csv
|   `-- Country-Series - Metadata.csv
|-- Output/                 # Cleaned CSV files and analysis results
|-- debt_output/            # Additional generated charts and summaries
|-- sql/
|   |-- load_debt.py        # Create MySQL tables and load processed CSV files
|   |-- schema.sql          # Database verification/schema notes
|   `-- cross_verify.sql    # MySQL row-count and integrity checks
`-- .streamlit/
    `-- secrets.toml        # Local Streamlit MySQL connection settings
```

## Requirements

- Python 3.10 or newer
- MySQL Server
- pip or another Python package manager

Main Python packages:

- Streamlit
- pandas
- NumPy
- Matplotlib
- Seaborn
- SciPy
- SQLAlchemy
- PyMySQL

Install dependencies:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

If PowerShell blocks virtual-environment activation, enable it for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Data Setup

Place the source World Bank CSV files in the `data/` directory. The main source files used by the project are:

- `IDS_ALLCountries_Data.csv`
- `IDS_CountryMetaData.csv`
- `IDS_SeriesMetaData.csv`
- `Country-Series - Metadata.csv`

Run the cleaning script:

```powershell
python clean.py
```

The script creates cleaned files in `Output/`, including:

- `ids_cleaned_wide.csv`
- `ids_debt_long.csv`
- `ids_indicator_lookup.csv`
- `country_metadata_cleaned.csv`
- `country_series_cleaned.csv`
- `country_series_debt_only.csv`

The cleaning script has machine-specific path defaults. Review the `BASE` and output-path definitions before running it on a different computer.

## MySQL Setup

The project expects a local database named `debt_db` with a MySQL account that can create and replace tables.

Default local settings:

```text
host: localhost
port: 3306
database: debt_db
username: root
password: root
```
  
Configure Streamlit in `.streamlit/secrets.toml`:

```toml
[connections.mysql]
dialect = "mysql"
driver = "pymysql"
host = "localhost"
port = 3306
database = "debt_db"
username = "root"
password = "root"
```

For a real deployment, replace the credentials and keep `secrets.toml` outside source control or use the platform's secret manager.

Update the same connection values in `sql/load_debt.py`, then load the processed data:

```powershell
python sql/load_debt.py
```

This script creates or replaces the following tables:

- `countries`
- `indicators`
- `ids_debt_long`

The dashboard reads these tables and expects the debt table to contain `country_code`, `indicator_code`, `year`, and `value` columns.

## Run the Analysis

Use the notebook for interactive exploration:

```powershell
jupyter notebook debt_analysis.ipynb
```

Generate statistical summaries and charts using `Analysis.py`:

```powershell
python Analysis.py
```

The analysis script can be redirected with environment variables:

```powershell
$env:IDS_OUT="C:\International_Debt Analysis System\Output"
$env:IDS_WIDE="$env:IDS_OUT\ids_cleaned_wide.csv"
$env:IDS_META="$env:IDS_OUT\country_metadata_cleaned.csv"
python Analysis.py
```

Generated charts and CSV summaries are written below `Output/analysis/` by default.

## Verify the Database

Run `sql/cross_verify.sql` in MySQL Workbench or another SQL client after loading the data. It includes checks for:

- Expected table row counts
- Missing country or indicator relationships
- Duplicate country-indicator-year records
- Year and value coverage
- Metadata and category distributions
- Primary and foreign-key relationships

## Data Notes

- World Bank IDS values may be stored as missing values, zeroes, estimates, or scheduled future payments rather than all-year actual observations.
- The project uses 2024 as the latest-analysis year in `Analysis.py`.
- In `clean.py`, years 2025-2032 are retained in the source processing and may represent projected or scheduled debt-service information.
- Country metadata is used to distinguish real countries from aggregate entities and to group countries by region or income category.
- Debt values are commonly expressed in current US dollars or as percentages of GNI, exports, or total debt. Check the selected indicator's unit before comparing values.

## Troubleshooting

### Streamlit cannot connect to MySQL

- Confirm that MySQL Server is running.
- Confirm database `debt_db` exists.
- Verify host, port, username, and password in `.streamlit/secrets.toml`.
- Make sure the PyMySQL package is installed.

### Missing or empty dashboard filters

- Run `python sql/load_debt.py` after cleaning the CSV files.
- Confirm that `countries`, `indicators`, and `ids_debt_long` exist.
- Check that the processed CSV files are in a location recognized by `load_debt.py`.

### Encoding or CSV parsing errors

The source files can use Windows-1252 or Latin-1 encoding rather than UTF-8. The cleaning scripts use `cp1252` or `Latin-1` where required.

## Source

The datasets are based on World Bank International Debt Statistics exports. Always refer to the World Bank metadata and documentation for current definitions and reporting limitations.
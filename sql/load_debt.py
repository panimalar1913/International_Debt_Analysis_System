#countries

import os
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text

# ---- Edit these ----
USER = "root"
PASSWORD = "root"
HOST = "localhost"
DATABASE = "debt_db"
TABLE = "countries"
CSV_NAME = "country_metadata_cleaned.csv"
# --------------------

# Find the CSV: next to the script, in ./output, or in the current folder
BASE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
candidates = [
    os.path.join(BASE, CSV_NAME),
    os.path.join(BASE, "output", CSV_NAME),
    os.path.join(os.path.dirname(BASE), "output", CSV_NAME),
    os.path.join(os.getcwd(), CSV_NAME),
]
CSV_FILE = next((p for p in candidates if os.path.exists(p)), None)
if CSV_FILE is None:
    raise FileNotFoundError("CSV not found. Looked in:\n" + "\n".join(candidates))
print("Using CSV:", CSV_FILE)

# Check the CSV header before touching the database
expected = [
    "country_code", "country_name", "country_long_name", "iso2_code",
    "entity_type", "region", "income_group", "lending_category",
    "is_hipc", "currency_unit", "debt_reporting_status",
]
header = pd.read_csv(CSV_FILE, nrows=0).columns.tolist()
print("CSV columns:", header)
missing = [c for c in expected if c not in header]
if missing:
    raise ValueError(f"CSV is missing columns {missing}.")

pw = quote_plus(PASSWORD)

# 1. Create the database if it doesn't exist
server_engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/")
with server_engine.begin() as conn:
    conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{DATABASE}`"))

engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/{DATABASE}")

# 2. Recreate the table so reruns are clean
with engine.begin() as conn:
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
    conn.execute(text(f"DROP TABLE IF EXISTS `{TABLE}`"))
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
    conn.execute(text(f"""
        CREATE TABLE `{TABLE}` (
            country_code          VARCHAR(10)  NOT NULL PRIMARY KEY,
            country_name          VARCHAR(150) NOT NULL,
            country_long_name     VARCHAR(150) NOT NULL,
            iso2_code             VARCHAR(5)   NOT NULL,
            entity_type           VARCHAR(30)  NOT NULL,
            region                VARCHAR(60),
            income_group          VARCHAR(60),
            lending_category      VARCHAR(60),
            is_hipc               TINYINT(1)   NOT NULL DEFAULT 0,
            currency_unit         VARCHAR(80),
            debt_reporting_status VARCHAR(60),
            INDEX idx_region (region),
            INDEX idx_income_group (income_group)
        )
    """))

# 3. Load the data
df = pd.read_csv(CSV_FILE, usecols=expected, keep_default_na=False)
df = df[expected]
df["is_hipc"] = df["is_hipc"].astype(str).str.strip().str.lower().isin(["true", "1", "yes"]).astype(int)
df = df.drop_duplicates(subset=["country_code"])

df.to_sql(TABLE, con=engine, if_exists="append", index=False,
          method="multi", chunksize=500)
print(f"Inserted {len(df):,} rows...")

print("Done!")

#indicators

import os
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text

# ---- Edit these ----
USER = "root"
PASSWORD = "root"
HOST = "localhost"
DATABASE = "debt_db"
TABLE = "indicators"
CSV_NAME = "ids_indicator_lookup.csv"
# --------------------

# Find the CSV: next to the script, in ./output, or in the current folder
BASE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
candidates = [
    os.path.join(BASE, CSV_NAME),
    os.path.join(BASE, "output", CSV_NAME),
    os.path.join(os.path.dirname(BASE), "output", CSV_NAME),
    os.path.join(os.getcwd(), CSV_NAME),
]
CSV_FILE = next((p for p in candidates if os.path.exists(p)), None)
if CSV_FILE is None:
    raise FileNotFoundError("CSV not found. Looked in:\n" + "\n".join(candidates))
print("Using CSV:", CSV_FILE)

# Check the CSV header before touching the database
expected = ["indicator_code", "indicator", "unit", "is_debt_indicator"]
header = pd.read_csv(CSV_FILE, nrows=0).columns.tolist()
print("CSV columns:", header)
missing = [c for c in expected if c not in header]
if missing:
    raise ValueError(f"CSV is missing columns {missing}.")

pw = quote_plus(PASSWORD)

# 1. Create the database if it doesn't exist
server_engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/")
with server_engine.begin() as conn:
    conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{DATABASE}`"))

engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/{DATABASE}")

# 2. Recreate the table so reruns are clean
with engine.begin() as conn:
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
    conn.execute(text(f"DROP TABLE IF EXISTS `{TABLE}`"))
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
    conn.execute(text(f"""
        CREATE TABLE `{TABLE}` (
            indicator_code    VARCHAR(50)  NOT NULL PRIMARY KEY,
            indicator         VARCHAR(255) NOT NULL,
            unit              VARCHAR(50),
            is_debt_indicator TINYINT(1)   NOT NULL DEFAULT 0,
            INDEX idx_is_debt (is_debt_indicator)
        )
    """))

# 3. Load the data
df = pd.read_csv(CSV_FILE, usecols=expected, keep_default_na=False)
df = df[expected]
df["is_debt_indicator"] = (
    df["is_debt_indicator"].astype(str).str.strip().str.lower()
    .isin(["true", "1", "yes"]).astype(int)
)
df = df.drop_duplicates(subset=["indicator_code"])

df.to_sql(TABLE, con=engine, if_exists="append", index=False,
          method="multi", chunksize=500)
print(f"Inserted {len(df):,} rows...")

print("Done!")

#debt_db

import os
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text

# ---- Edit these ----
USER = "root"
PASSWORD = "root"
HOST = "localhost"
DATABASE = "debt_db"
TABLE = "ids_debt_long"
CSV_NAME = "ids_debt_long.csv"
# --------------------

# Find the CSV: next to the script, in ./output, or in ../output
BASE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
candidates = [
    os.path.join(BASE, CSV_NAME),
    os.path.join(BASE, "output", CSV_NAME),
    os.path.join(os.path.dirname(BASE), "output", CSV_NAME),
    os.path.join(os.getcwd(), CSV_NAME),
]
CSV_FILE = next((p for p in candidates if os.path.exists(p)), None)
if CSV_FILE is None:
    raise FileNotFoundError("CSV not found. Looked in:\n" + "\n".join(candidates))
print("Using CSV:", CSV_FILE)

# Check the CSV header before touching the database
header = pd.read_csv(CSV_FILE, nrows=0).columns.tolist()
print("CSV columns:", header)
expected = ["country_code", "indicator_code", "year", "value"]
missing = [c for c in expected if c not in header]
if missing:
    raise ValueError(f"CSV is missing columns {missing}. Rename them in the CSV or edit 'expected'.")

pw = quote_plus(PASSWORD)

# 1. Create the database if it doesn't exist
server_engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/")
with server_engine.begin() as conn:
    conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{DATABASE}`"))

engine = create_engine(f"mysql+pymysql://{USER}:{pw}@{HOST}/{DATABASE}")

# 2. Recreate the table so reruns are clean
with engine.begin() as conn:
    conn.execute(text(f"DROP TABLE IF EXISTS `{TABLE}`"))
    conn.execute(text(f"""
        CREATE TABLE `{TABLE}` (
            id INT AUTO_INCREMENT PRIMARY KEY,
            country_code VARCHAR(10) NOT NULL,
            indicator_code VARCHAR(50) NOT NULL,
            year INT NOT NULL,
            value DOUBLE,
            INDEX idx_lookup (country_code, indicator_code, year)
        )
    """))

# 3. Load in batches
total = 0
for chunk in pd.read_csv(CSV_FILE, usecols=expected, chunksize=50_000):
    chunk = chunk[expected]                      # fixes column order
    chunk = chunk.dropna(subset=["country_code", "indicator_code", "year"])
    chunk.to_sql(TABLE, con=engine, if_exists="append", index=False,
                 method="multi", chunksize=2_000)
    total += len(chunk)
    print(f"Inserted {total:,} rows...")

print("Done!") 
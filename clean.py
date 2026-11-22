import re
import pandas as pd
#dataset1
SRC = "data/Country-Series - Metadata.csv"
OUT = "Output/country_series_cleaned.csv"
OUT_DEBT = "Output/country_series_debt_only.csv"

# 1. Load (file is Windows-1252 encoded, not UTF-8)
df = pd.read_csv(SRC, encoding="cp1252", dtype=str)
print("Raw shape:", df.shape)

# 2. Standardize column names
df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

# 3. Missing values: blanks -> NaN, then report / drop rows missing key fields
df = df.replace(r"^\s*$", pd.NA, regex=True)
print("Nulls per column:\n", df.isna().sum())
df = df.dropna(subset=["country_code", "series_code"])
df["description"] = df["description"].fillna("No description available")

# 4. Split combined fields: "Afghanistan (AFG)" and "<name> (<code>)"
c = df["country_code"].str.extract(r"^(?P<country>.*?)\s*\((?P<country_code>[A-Z]{3})\)\s*$")
s = df["series_code"].str.extract(r"^(?P<indicator>.*?)\s*\((?P<indicator_code>[A-Z0-9.]+)\)\s*$")
df = df.assign(country=c["country"], country_code=c["country_code"],
               indicator=s["indicator"], indicator_code=s["indicator_code"])
df = df.dropna(subset=["country", "country_code", "indicator_code"])

# 5. Text cleaning: trim, collapse whitespace/newlines, fix encoding artefacts
def clean_text(x):
    x = re.sub(r"\s+", " ", str(x)).strip()
    return x.replace("\u2013", "-").replace("\u2019", "'")
for col in ["country", "indicator", "description"]:
    df[col] = df[col].map(clean_text)
df["country_code"] = df["country_code"].str.upper()
df["indicator_code"] = df["indicator_code"].str.upper()

# 6. Data type conversion
for col in ["country", "country_code", "indicator", "indicator_code"]:
    df[col] = df[col].astype("category")
df["description"] = df["description"].astype("string")

# 7. Flag debt indicators (World Bank external debt series = DT.DOD.*)
df["is_debt_indicator"] = df["indicator_code"].astype(str).str.startswith("DT.DOD")

# 8. Remove duplicates (exact + on the natural key)
before = len(df)
df = df.drop_duplicates().drop_duplicates(subset=["country_code", "indicator_code"])
print("Duplicates removed:", before - len(df))

# 9. Keep relevant columns, sort, save
cols = ["country", "country_code", "indicator", "indicator_code", "is_debt_indicator", "description"]
df = df[cols].sort_values(["country", "indicator_code"]).reset_index(drop=True)
df.to_csv(OUT, index=False, encoding="utf-8")
df[df["is_debt_indicator"]].to_csv(OUT_DEBT, index=False, encoding="utf-8")

print("Clean shape:", df.shape, "| countries:", df["country_code"].nunique())
print(df.dtypes)
print(df["indicator"].value_counts())

#dataset2
import re
import pandas as pd

SRC = "data/IDS_ALLCountries_Data.csv"
OUT_WIDE = "output/ids_cleaned_wide.csv"
OUT_DEBT_LONG = "output/ids_debt_long.csv"
OUT_LOOKUP = "output/ids_indicator_lookup.csv"

# 1. Load (file is Windows-1252 encoded; read everything as text first)
df = pd.read_csv(SRC, encoding="cp1252", dtype=str)
print("Raw shape:", df.shape)

# 2. Standardize column names
df.columns = [c.strip().lower().replace("-", "_").replace(" ", "_") for c in df.columns]
year_cols = [c for c in df.columns if c.isdigit()]

# 3. Remove footer / blank rows (no country or series code), e.g. the
#    "Data from database..." and "Last Updated..." lines at the bottom
df = df.dropna(subset=["country_code", "series_code"])
print("After removing blank/footer rows:", df.shape)

# 4. Text cleaning: trim, collapse whitespace (incl. non-breaking spaces)
def clean_text(x):
    return re.sub(r"\s+", " ", str(x).replace("\xa0", " ")).strip()

for c in ["country_name", "series_name"]:
    df[c] = df[c].map(clean_text)
df["country_code"] = df["country_code"].str.strip().str.upper()
df["series_code"] = df["series_code"].str.strip().str.upper()

# 5. Drop constant column (counterpart area is "World" for every row)
assert df["counterpart_area_code"].nunique() == 1
df = df.drop(columns=["counterpart_area_name", "counterpart_area_code"])

# 6. Data type conversion: year columns -> numeric (bad tokens like ".." -> NaN)
df[year_cols] = df[year_cols].apply(pd.to_numeric, errors="coerce")
df = df.rename(columns={"series_name": "indicator", "series_code": "indicator_code"})

# 7. Missing values: drop rows with no observation in any year
before = len(df)
df = df.dropna(subset=year_cols, how="all")
print("All-null rows removed:", before - len(df))

# 8. Duplicates (exact + natural key)
before = len(df)
df = df.drop_duplicates().drop_duplicates(subset=["country_code", "indicator_code"])
print("Duplicates removed:", before - len(df))

# 9. Add helper columns: unit and debt flag
def unit(name):
    n = name.lower()
    if "current us$" in n: return "current US$"
    if "(us$)" in n: return "US$"
    if "(%" in n or "% of" in n: return "%"
    if "(years)" in n: return "years"
    if "months of imports" in n: return "months of imports"
    return "other"

df["unit"] = df["indicator"].map(unit)
df["is_debt_indicator"] = df["indicator_code"].str.startswith("DT.")

# 10. Final types, column order, sort
for c in ["country_name", "country_code", "indicator", "indicator_code", "unit"]:
    df[c] = df[c].astype("category")
df = df[["country_name", "country_code", "indicator", "indicator_code",
         "unit", "is_debt_indicator"] + year_cols]
df = df.sort_values(["country_name", "indicator_code"]).reset_index(drop=True)

# 11. Save wide file (all indicators) and a tidy long file for debt indicators
df.to_csv(OUT_WIDE, index=False)

id_cols = ["country_name", "country_code", "indicator", "indicator_code", "unit"]
long = (df[df["is_debt_indicator"]]
        .melt(id_vars=id_cols, value_vars=year_cols, var_name="year", value_name="value")
        .dropna(subset=["value"]))
long["year"] = long["year"].astype(int)
long = long.sort_values(["country_code", "indicator_code", "year"])

# Slim long file: keep codes only; names/units live in a lookup table
(df[["indicator_code", "indicator", "unit", "is_debt_indicator"]]
   .drop_duplicates().sort_values("indicator_code")
   .to_csv(OUT_LOOKUP, index=False))
long = long[["country_code", "indicator_code", "year", "value"]]
long.to_csv(OUT_DEBT_LONG, index=False)

print("Clean wide shape:", df.shape, "| countries:", df["country_code"].nunique(),
      "| indicators:", df["indicator_code"].nunique())
print("Debt indicators:", df.loc[df.is_debt_indicator, "indicator_code"].nunique(),
      "| debt long rows:", len(long))
print(df.dtypes.head(8))

#dataset3

import os
from pathlib import Path
import pandas as pd

# ---- Paths: edit BASE / file names for your machine --------------------------
BASE = Path(r"C:\International_Debt Analysis System")
SRC = Path(os.environ.get("IDS_SRC", BASE / "data" / "IDS_CountryMetaData.csv"))
OUT_DIR = Path(os.environ.get("IDS_OUT", BASE / "outputs"))
OUT_DIR.mkdir(parents=True, exist_ok=True)          # fixes "non-existent directory"
OUT_FILE = OUT_DIR / "country_metadata_cleaned.csv"

# 1. Load (file is Windows-1252 encoded, not UTF-8); read as text first
df = pd.read_csv(SRC, encoding="cp1252", dtype=str)
print("Raw shape:", df.shape)

# 2. Standardize column names
df.columns = [c.strip().lower().replace("-", "_").replace(" ", "_") for c in df.columns]

# 3. Trim whitespace in every text column, blanks -> null
for c in df.columns:
    df[c] = df[c].str.replace(r"\s+", " ", regex=True).str.strip()
df = df.replace("", pd.NA)

# 4. Remove duplicates (exact rows, then on country code)
before = len(df)
df["code"] = df["code"].str.upper()
df = df.drop_duplicates().drop_duplicates(subset=["code"])
print("Duplicates removed:", before - len(df))

# 5. Filter relevant columns and rename
df = df.rename(columns={
    "code": "country_code", "short_name": "country_name", "long_name": "country_long_name",
    "2_alpha_code": "iso2_code", "external_debt_reporting_status": "debt_reporting_status",
})

# 6. Flag aggregates: regional / income-group rows (no region, lending category or currency)
df["entity_type"] = (df["region"].isna() & df["lending_category"].isna()
                     & df["currency_unit"].isna()).map({True: "Aggregate", False: "Country"})

# 7. Missing values
#    - "other_groups" only ever holds "HIPC", so null = not HIPC -> boolean flag
df["is_hipc"] = df["other_groups"].eq("HIPC")
cat_cols = ["income_group", "region", "lending_category", "currency_unit", "debt_reporting_status"]
is_agg = df["entity_type"].eq("Aggregate")
for c in cat_cols:
    df[c] = df[c].mask(is_agg & df[c].isna(), "Not applicable (aggregate)")
    df[c] = df[c].fillna("Not available")

# 8. Keep only columns relevant to debt analysis, set data types
keep = ["country_code", "country_name", "country_long_name", "iso2_code", "entity_type",
        "region", "income_group", "lending_category", "is_hipc", "currency_unit",
        "debt_reporting_status"]
df = df[keep].copy()
for c in keep:
    if c != "is_hipc":
        df[c] = df[c].astype("category")

df = df.sort_values(["entity_type", "country_name"]).reset_index(drop=True)
df.to_csv(OUT_FILE, index=False, encoding="utf-8")

print("Clean shape:", df.shape)
print(df["entity_type"].value_counts())
print("Countries with 'Not available' income group:",
      df.loc[(df.entity_type == "Country") & (df.income_group == "Not available"), "country_name"].tolist())
print(df.dtypes)

#dataset4
import os
import re
import numpy as np
import pandas as pd

def clean_debt_metadata(input_filepath, output_filepath):
    print("=" * 60)
    print("STARTING DATA CLEANING & STANDARDIZATION PIPELINE")
    print("=" * 60)

    # 1. File Existence & Loading Check
    if not os.path.exists(input_filepath):
        print(f"\n[ERROR] File not found: '{input_filepath}'")
        print(f"Current Working Directory: {os.getcwd()}")
        print("Please verify the filename or provide the absolute path.")
        return None

    print(f"\n1. Loading dataset from '{input_filepath}'...")
    try:
        # Using 'latin1' encoding to safely parse special characters/symbols
        df = pd.read_csv(input_filepath, encoding='latin1')
    except Exception as e:
        # Fallback encoding if latin1 encounters issues
        df = pd.read_csv(input_filepath, encoding='cp1252')
        
    print(f"   Original dataset shape: {df.shape}")

    # 2. Handle Missing Values (Null Data)
    print("\n2. Handling missing values...")
    # Replace blank or whitespace-only strings with NaN
    df.replace(r'^\s*$', np.nan, regex=True, inplace=True)
    
    initial_nulls = df.isnull().sum().to_dict()
    print(f"   Null counts per column before cleaning: {initial_nulls}")
    
    # Drop rows where critical identifier columns are completely missing
    critical_cols = [col for col in ['Country Code', 'Series Code', 'Time Code'] if col in df.columns]
    if critical_cols:
        df.dropna(subset=critical_cols, inplace=True)

    # 3. Remove Duplicate Records
    print("\n3. Removing duplicate records...")
    rows_before_dups = len(df)
    
    # Drop exact row duplicates
    df.drop_duplicates(inplace=True)
    
    # Drop duplicates based on core business/composite keys if present
    composite_keys = [c for c in ['Country Code', 'Series Code', 'Time Code'] if c in df.columns]
    if composite_keys:
        df.drop_duplicates(subset=composite_keys, inplace=True)
        
    duplicates_removed = rows_before_dups - len(df)
    print(f"   Total duplicate records removed: {duplicates_removed}")

    # 4. Perform Data Type Conversion & Feature Extraction
    print("\n4. Performing data type conversion and feature extraction...")
    # Standardize string formatting across all text columns
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].astype(str).str.strip()

    # Extract Year from Time Code (e.g., '2024 (YR2024)' -> 2024) and convert to nullable integer type
    if 'Time Code' in df.columns:
        df['Year'] = df['Time Code'].str.extract(r'(\d{4})')
        df['Year'] = pd.to_numeric(df['Year'], errors='coerce').astype('Int64')

    # Separate Country Name and ISO Code from Country Code field (e.g., 'Afghanistan (AFG)')
    if 'Country Code' in df.columns:
        df['Country_Name'] = df['Country Code'].str.replace(r'\s*\([A-Z]+\)', '', regex=True)
        df['ISO_Code'] = df['Country Code'].str.extract(r'\(([A-Z]+)\)')

    # Separate Indicator Name from Series Code
    if 'Series Code' in df.columns:
        df['Indicator_Name'] = df['Series Code'].str.replace(r'\s*\([A-Za-z0-9\._-]+\s*\)', '', regex=True)

    # 5. Filter Relevant Columns (Country, Indicators, Debt/Time Values, Descriptions)
    print("\n5. Filtering relevant columns...")
    target_columns = [
        'Type', 
        'Country_Name', 
        'ISO_Code', 
        'Indicator_Name', 
        'Series Code', 
        'Year', 
        'Time Code', 
        'Description'
    ]
    # Keep only columns that exist in the dataframe to prevent KeyError
    available_columns = [col for col in target_columns if col in df.columns]
    df_filtered = df[available_columns].copy()

    # 6. Save Cleaned Dataset
    print(f"\n6. Saving cleaned dataset to '{output_filepath}'...")
    df_filtered.to_csv(output_filepath, index=False, encoding='utf-8')
    print(f"   Final cleaned dataset shape: {df_filtered.shape}")
    print("=" * 60)
    print("PIPELINE COMPLETED SUCCESSFULLY!")
    print("=" * 60)

    return df_filtered

if __name__ == '__main__':
    # File paths (Note: If your file is named 'IDS_FootNoteMetaData_2.csv', update input_file below)
    input_file = 'C:\\International_Debt Analysis System\\data\\IDS_FootNoteMetaData.csv'
    output_file = 'C:\\International_Debt Analysis System\\data\\IDS_FootNoteMetaData_Cleaned.csv'

    # Run the complete cleaning pipeline
    cleaned_data = clean_debt_metadata(input_file, output_file)
    
    if cleaned_data is not None:
        print("\nPreview of Cleaned Dataset:")
        print(cleaned_data.head(3))

        #dataset5
        import os
import numpy as np
import pandas as pd

def clean_series_metadata(input_filepath, output_filepath):
    print("=" * 60)
    print("STARTING SERIES METADATA CLEANING & STANDARDIZATION PIPELINE")
    print("=" * 60)

    # 1. File Existence & Loading Check
    if not os.path.exists(input_filepath):
        print(f"\n[ERROR] File not found: '{input_filepath}'")
        print(f"Current Working Directory: {os.getcwd()}")
        print("Please verify the filename or provide the absolute path.")
        return None

    print(f"\n1. Loading dataset from '{input_filepath}'...")
    try:
        # Using 'latin1' encoding to safely parse special characters and symbols
        df = pd.read_csv(input_filepath, encoding='latin1')
    except Exception as e:
        df = pd.read_csv(input_filepath, encoding='cp1252')
        
    print(f"   Original dataset shape: {df.shape}")

    # 2. Handle Missing Values (Null Data)
    print("\n2. Handling missing values...")
    # Replace blank or whitespace-only strings with NaN
    df.replace(r'^\s*$', np.nan, regex=True, inplace=True)
    
    initial_nulls = df.isnull().sum().to_dict()
    print(f"   Null counts per column before cleaning:\n   {initial_nulls}")
    
    # Fill sparse textual metadata gaps where appropriate
    if 'Short definition' in df.columns:
        df['Short definition'] = df['Short definition'].fillna('Not Specified')
    if 'Dataset' in df.columns:
        df['Dataset'] = df['Dataset'].fillna('International Debt Statistics')

    # 3. Remove Duplicate Records
    print("\n3. Removing duplicate records...")
    rows_before_dups = len(df)
    
    # Drop exact row duplicates
    df.drop_duplicates(inplace=True)
    
    # Drop duplicate records based on the unique indicator Code
    if 'Code' in df.columns:
        df.drop_duplicates(subset=['Code'], inplace=True)
        
    duplicates_removed = rows_before_dups - len(df)
    print(f"   Total duplicate records removed: {duplicates_removed}")

    # 4. Perform Data Type Conversion & Text Standardization
    print("\n4. Performing data type conversion and text standardization...")
    # Standardize string formatting (strip leading/trailing whitespaces) across all text columns
    for col in df.select_dtypes(include=['object']).columns:
        df[col] = df[col].astype(str).str.strip()

    # 5. Filter Relevant Columns (Indicators, Definitions, Topics, Sources)
    print("\n5. Filtering relevant columns...")
    target_columns = [
        'Code', 
        'Indicator Name', 
        'Short definition', 
        'Long definition', 
        'Topic', 
        'Source', 
        'Periodicity', 
        'Aggregation method'
    ]
    # Keep only available columns to prevent KeyError
    available_columns = [col for col in target_columns if col in df.columns]
    df_filtered = df[available_columns].copy()

    # 6. Save Cleaned Dataset
    print(f"\n6. Saving cleaned dataset to '{output_filepath}'...")
    df_filtered.to_csv(output_filepath, index=False, encoding='utf-8')
    print(f"   Final cleaned dataset shape: {df_filtered.shape}")
    print("=" * 60)
    print("PIPELINE COMPLETED SUCCESSFULLY!")
    print("=" * 60)

    return df_filtered

if __name__ == '__main__':
    # File paths
    input_file = 'C:\\International_Debt Analysis System\\data\\IDS_SeriesMetaData.csv' 
    output_file = 'IDS_SeriesMetaData_Cleaned.csv'
    
    # Run the complete cleaning pipeline
    cleaned_data = clean_series_metadata(input_file, output_file)
    
    if cleaned_data is not None:
        print("\nPreview of Cleaned Dataset:")
        print(cleaned_data.head(3))

# Step 1: Import Pandas
import pandas as pd

# Step 2: Read the CSV file
df = pd.read_csv("data/IDS_CountryMetaData.csv", encoding="Latin-1")

# Step 3: Display the first 5 rows
print("FIRST 5 ROWS OF THE DATASET")
print(df.head())

# Step 4: Display the number of rows and columns
print("\nDATASET SIZE")
print(df.shape)

# Step 5: Display all column names
print("\nCOLUMN NAMES")
print(df.columns.tolist())

# Step 6: Display dataset information
print("\nDATASET INFORMATION")
df.info()
#dataset2
df = pd.read_csv("data/IDS_ALLCountries_Data.csv", encoding="Latin-1")

# Step 3: Display the first 5 rows
print("FIRST 5 ROWS OF THE DATASET")
print(df.head())

# Step 4: Display the number of rows and columns
print("\nDATASET SIZE")
print(df.shape)

# Step 5: Display all column names
print("\nCOLUMN NAMES")
print(df.columns.tolist())

# Step 6: Display dataset information
print("\nDATASET INFORMATION")
df.info()
#dataset3
df = pd.read_csv("data/IDS_CountryMetaData.csv", encoding="Latin-1")

# Step 3: Display the first 5 rows
print("FIRST 5 ROWS OF THE DATASET")
print(df.head())

# Step 4: Display the number of rows and columns
print("\nDATASET SIZE")
print(df.shape)

# Step 5: Display all column names
print("\nCOLUMN NAMES")
print(df.columns.tolist())

# Step 6: Display dataset information
print("\nDATASET INFORMATION")
df.info()
#dataset4
df = pd.read_csv("data/IDS_FootNoteMetaData.csv", encoding="Latin-1")

# Step 3: Display the first 5 rows
print("FIRST 5 ROWS OF THE DATASET")
print(df.head())

# Step 4: Display the number of rows and columns
print("\nDATASET SIZE")
print(df.shape)

# Step 5: Display all column names
print("\nCOLUMN NAMES")
print(df.columns.tolist())

# Step 6: Display dataset information
print("\nDATASET INFORMATION")
df.info()
#dataset5
df = pd.read_csv("data/IDS_SeriesMetaData.csv", encoding="Latin-1")

# Step 3: Display the first 5 rows
print("FIRST 5 ROWS OF THE DATASET")
print(df.head())

# Step 4: Display the number of rows and columns
print("\nDATASET SIZE")
print(df.shape)

# Step 5: Display all column names
print("\nCOLUMN NAMES")
print(df.columns.tolist())

# Step 6: Display dataset information
print("\nDATASET INFORMATION")
df.info()
df = pd.read_csv("Output/ids_debt_long.csv")
print(len(df))
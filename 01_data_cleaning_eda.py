"""
Project: Customer Analytics Pipeline (Python -> SQL -> Power BI -> AI)
Stage 1: Data Cleaning, Missing-Value Handling, EDA, Customer Behavior Features

Dataset: Online Retail II (UCI Machine Learning Repository)
Download: https://archive.ics.uci.edu/dataset/502/online+retail+ii

This script auto-detects whether you downloaded the .csv or the .xlsx
version, so you don't need to convert anything by hand -- just drop the
file you downloaded into data/raw/ and update RAW_PATH below if needed.

"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")  # write chart files without needing a display
import matplotlib.pyplot as plt
import os
import sys

# ---------------------------------------------------------------------------
# 0. CONFIG -- point this at whatever file you actually downloaded
#    (.csv or .xlsx both work; the loader below auto-detects the extension)
# ---------------------------------------------------------------------------
RAW_PATH = "online_retail_II.xlsx"   # <-- change to .csv if that's what you have

CLEAN_PATH = "data/clean/transactions_clean.csv"
CUSTOMER_FEATURES_PATH = "data/clean/customer_features.csv"
FIG_DIR = "reports/figures"

os.makedirs("data/clean", exist_ok=True)
os.makedirs(FIG_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# 1. LOAD (auto-detects .csv vs .xlsx, and the two-sheet xlsx layout)
# ---------------------------------------------------------------------------
if not os.path.exists(RAW_PATH):
    sys.exit(
        f"\n[ERROR] Could not find '{RAW_PATH}'.\n"
        f"Download the dataset from https://archive.ics.uci.edu/dataset/502/online+retail+ii\n"
        f"and place it at that path (or edit RAW_PATH at the top of this script "
        f"to match wherever you saved it).\n"
    )

ext = os.path.splitext(RAW_PATH)[1].lower()

if ext == ".csv":
    df = pd.read_csv(RAW_PATH, encoding="ISO-8859-1")

elif ext == ".xlsx":
    # The official UCI file ships as two sheets, one per year -- read
    # whichever sheets actually exist and stack them into one table.
    xls = pd.ExcelFile(RAW_PATH)
    sheets_to_read = [s for s in xls.sheet_names if "20" in s] or xls.sheet_names
    print(f"Reading sheets: {sheets_to_read}")
    df = pd.concat(
        [pd.read_excel(xls, sheet_name=s) for s in sheets_to_read],
        ignore_index=True,
    )

else:
    sys.exit(f"[ERROR] Unsupported file type '{ext}'. Use a .csv or .xlsx file.")

# Standardize column names (the file uses "Customer ID" / "Price" with spaces)
df.columns = [c.strip().replace(" ", "_") for c in df.columns]
rename_map = {
    "Invoice": "InvoiceNo",
    "Customer_ID": "CustomerID",
    "Price": "UnitPrice",
}
df = df.rename(columns={k: v for k, v in rename_map.items() if k in df.columns})

required_cols = {"InvoiceNo", "StockCode", "Quantity", "InvoiceDate",
                  "UnitPrice", "CustomerID", "Country"}
missing_cols = required_cols - set(df.columns)
if missing_cols:
    sys.exit(f"[ERROR] Expected columns not found after rename: {missing_cols}. "
              f"Actual columns: {list(df.columns)}")

print("Raw shape:", df.shape)

# ---------------------------------------------------------------------------
# 2. MISSING VALUE HANDLING (documented, not silently dropped)
# ---------------------------------------------------------------------------
missing_report = df.isna().sum().sort_values(ascending=False)
missing_pct = (missing_report / len(df) * 100).round(2)
print("\nMissing values:\n", pd.concat([missing_report, missing_pct], axis=1,
                                        keys=["count", "pct"]))

# CustomerID is missing for a meaningful share of rows (guest/unattributed
# transactions). Every downstream stage (RFM, cohorts, CLV) is customer-level,
# so these rows can't be attributed and are dropped -- count is logged, not lost.
n_before = len(df)
df = df.dropna(subset=["CustomerID"])
print(f"\nDropped {n_before - len(df)} rows with missing CustomerID "
      f"({(n_before - len(df)) / n_before:.1%} of raw data).")

# Description missing but CustomerID present -> keep row, fill with "UNKNOWN"
df["Description"] = df["Description"].fillna("UNKNOWN").astype(str).str.strip()

df["CustomerID"] = df["CustomerID"].astype(int).astype(str)

# ---------------------------------------------------------------------------
# 3. CLEANING: cancellations, invalid quantities/prices, duplicates
# ---------------------------------------------------------------------------
df["InvoiceDate"] = pd.to_datetime(df["InvoiceDate"])

df["IsCancelled"] = df["InvoiceNo"].astype(str).str.startswith("C")
cancellations = df[df["IsCancelled"]].copy()
df = df[~df["IsCancelled"]].copy()

before = len(df)
df = df[(df["Quantity"] > 0) & (df["UnitPrice"] > 0)]
print(f"Removed {before - len(df)} rows with non-positive quantity/price.")

before = len(df)
df = df.drop_duplicates()
print(f"Removed {before - len(df)} exact duplicate rows.")

# Outlier handling via IQR capping (winsorizing), not deletion
for col in ["Quantity", "UnitPrice"]:
    q1, q3 = df[col].quantile([0.25, 0.75])
    iqr = q3 - q1
    upper = q3 + 3 * iqr
    df[col] = np.where(df[col] > upper, upper, df[col])

df["TotalPrice"] = df["Quantity"] * df["UnitPrice"]

# ---------------------------------------------------------------------------
# THIS is the clean dataset CSV -- the actual fix for the "empty folder" issue.
# Everything above must succeed before this line is reached.
# ---------------------------------------------------------------------------
df.to_csv(CLEAN_PATH, index=False)
print(f"\n✅ Cleaned transaction data saved to {CLEAN_PATH} -- shape {df.shape}")

if not cancellations.empty:
    cancellations.to_csv("data/clean/cancellations.csv", index=False)
    print(f"✅ Cancelled orders saved separately to data/clean/cancellations.csv "
          f"-- shape {cancellations.shape}")

# ---------------------------------------------------------------------------
# 4. EXPLORATORY DATA ANALYSIS
# ---------------------------------------------------------------------------
monthly_revenue = df.set_index("InvoiceDate")["TotalPrice"].resample("ME").sum()
monthly_revenue.plot(title="Monthly Revenue", figsize=(10, 4))
plt.tight_layout()
plt.savefig(f"{FIG_DIR}/monthly_revenue.png")
plt.close()

top_countries = df.groupby("Country")["TotalPrice"].sum().sort_values(ascending=False).head(10)
top_products = df.groupby("Description")["TotalPrice"].sum().sort_values(ascending=False).head(10)

order_value = df.groupby("InvoiceNo")["TotalPrice"].sum()
order_value.plot(kind="hist", bins=50, title="Order Value Distribution", figsize=(8, 4))
plt.tight_layout()
plt.savefig(f"{FIG_DIR}/order_value_distribution.png")
plt.close()

print("\nTop 10 countries by revenue:\n", top_countries)
print("\nTop 10 products by revenue:\n", top_products)
print(f"\n✅ Charts saved to {FIG_DIR}/")

# ---------------------------------------------------------------------------
# 5. CUSTOMER BEHAVIOR FEATURE ENGINEERING
# ---------------------------------------------------------------------------
snapshot_date = df["InvoiceDate"].max() + pd.Timedelta(days=1)

order_counts = df.groupby("InvoiceNo")["CustomerID"].first()  # invoice -> customer
invoice_order_count = df.groupby("CustomerID")["InvoiceNo"].nunique()

customer_features = df.groupby("CustomerID").agg(
    recency_days=("InvoiceDate", lambda x: (snapshot_date - x.max()).days),
    frequency=("InvoiceNo", "nunique"),
    monetary=("TotalPrice", "sum"),
    first_purchase=("InvoiceDate", "min"),
    last_purchase=("InvoiceDate", "max"),
    distinct_products=("StockCode", "nunique"),
).reset_index()

customer_features["avg_order_value"] = (
    customer_features["monetary"] / customer_features["frequency"]
).round(2)
customer_features["is_repeat_customer"] = customer_features["frequency"] > 1
customer_features["tenure_days"] = (
    customer_features["last_purchase"] - customer_features["first_purchase"]
).dt.days

customer_features.to_csv(CUSTOMER_FEATURES_PATH, index=False)
print(f"\n✅ Customer-level feature table saved to {CUSTOMER_FEATURES_PATH} "
      f"-- {customer_features.shape[0]} unique customers")

repeat_rate = customer_features["is_repeat_customer"].mean()
print(f"Repeat customer rate: {repeat_rate:.1%}")

print("\nDone. Files written:")
for p in [CLEAN_PATH, CUSTOMER_FEATURES_PATH,
          f"{FIG_DIR}/monthly_revenue.png", f"{FIG_DIR}/order_value_distribution.png"]:
    print(" -", p, "(exists)" if os.path.exists(p) else "(MISSING!)")

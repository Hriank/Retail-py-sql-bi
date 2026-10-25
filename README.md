Readme · MD
Retail Customer Analytics: Python → SQL → Power BI

An end-to-end customer analytics project on the Online Retail II dataset. Raw transaction data is cleaned and profiled in Python, analysed in SQL, and turned into a five-page Power BI dashboard that walks a stakeholder from "how is the business doing?" to "what should we do about it?"

Headline result: 9.7% of customers (Champions) generate 49.7% of revenue, and repeat buyers (72.4% of customers) generate 96.4% of it. Half of all customers have not purchased in 90+ days. Full analysis: FINDINGS_AND_RECOMMENDATIONS.md

Dataset

Online Retail II (UCI Machine Learning Repository): transactions from a UK-based online gift retailer, December 2009 to December 2011. Check the dataset page for licensing terms.

Stage	Rows
Raw (two yearly sheets combined)	1,067,371
Cleaned transactions	779,425
Cancelled-order lines (kept separately)	18,744
Unique identified customers	5,878

The raw file is not included in this repository. Download it and place it at data/raw/online_retail_II.xlsx.

Project Structure
├── 01_data_cleaning_eda.py      # Cleaning, missing-value handling, EDA, customer features
├── data_cleaning_output.txt     # Console log from a full run (audit trail)
├── SQL analysis/                # SQL scripts: customer KPIs, RFM, cohorts, window functions
├── data/
│   └── clean/                   # transactions_clean, customer_features, cancellations (CSV)
├── reports/
│   └── figures/                 # EDA charts (monthly revenue, order value distribution)
├── FINDINGS_AND_RECOMMENDATIONS.md
└── README.md
Pipeline
Raw XLSX  →  Python (clean · EDA · features)  →  SQL (KPIs · RFM · cohorts)  →  Power BI (5-page story)
1. Python: cleaning and EDA (01_data_cleaning_eda.py)
Reads both yearly sheets of the XLSX (or a CSV) and stacks them into one table
Standardises column names and validates that required columns exist
Missing values: reports the count and percentage per column. Drops 243,007 rows (22.8%) with no CustomerID because they cannot be attributed to a customer. Fills missing Description with UNKNOWN
Cleaning: separates cancelled invoices (prefix C) into their own file, removes 71 rows with non-positive quantity or price, drops 26,124 exact duplicates
Outliers: winsorises extreme Quantity and UnitPrice values (Q3 + 3×IQR) instead of deleting rows
EDA: monthly revenue trend, order value distribution, top countries and products
Customer features: recency, frequency, monetary value, average order value, tenure, distinct products and a repeat-customer flag per customer
2. SQL (SQL analysis/)

Customer-level KPIs, RFM scoring, cohort retention and window-function analysis (running totals, rankings, month-over-month change) on the cleaned transactions.

3. Power BI dashboard

Five pages that follow one story arc:

Page	Question it answers
Business Overview	How is the business performing? Revenue, orders, customers, AOV, monthly trend, revenue by country
Customer Segmentation	Who are the customers? Segment size vs. segment revenue
Retention & Churn	Are we keeping them? Cohort retention heatmap, churn rate, month-1 return rate, recency buckets
Customer Value	Who is worth keeping? Average customer value, repeat vs. one-time revenue, revenue by value decile
Action Plan	What should we do? Protect, win back and convert actions, with a top-15 win-back list

Segmentation method. Segments in the dashboard are rule-based (DAX, thresholds on recency, frequency and monetary value):

Segment	Rule
Champions	recency ≤ 30 days, frequency ≥ 8, spend ≥ £3,000
Loyal	recency ≤ 90 days, frequency ≥ 5, spend ≥ £1,500
Hibernating	recency > 180 days, frequency ≤ 2
At Risk	recency > 90 days (and not Hibernating)
Other	everything else
<!-- Add dashboard screenshots here, e.g. ![Retention page](reports/dashboard/retention.png) -->
How to Run
bash
pip install pandas numpy matplotlib openpyxl

# 1. Place the downloaded file at data/raw/online_retail_II.xlsx
# 2. Run the cleaning and EDA script
python 01_data_cleaning_eda.py

The script writes data/clean/transactions_clean.csv, customer_features.csv, cancellations.csv and the charts in reports/figures/, then prints a checklist confirming each file exists. Next, run the scripts in SQL analysis/ against a database loaded with transactions_clean.csv, and point Power BI at the cleaned CSVs.

Key Data-Quality Decisions
Rows without a CustomerID are excluded, so every customer-level metric describes identified customers only.
Cancelled orders are stored separately rather than netted against revenue, so revenue figures are gross of cancellations.
The data ends around 9 December 2011, so the last month is partial and later cohort cells are incomplete.
"Average customer value" is historical spend per customer, not a predicted lifetime value.
Tech Stack

Python (pandas, NumPy, matplotlib) · SQL · Power BI (DAX, data modelling)

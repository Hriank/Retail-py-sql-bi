CREATE TABLE transactions ( InvoiceNo TEXT, StockCode TEXT, Description TEXT, Quantity NUMERIC, InvoiceDate TIMESTAMP, UnitPrice NUMERIC, CustomerID TEXT, Country TEXT, IsCancelled BOOLEAN, TotalPrice NUMERIC ); 

CREATE TABLE cancellations (
    "InvoiceNo"     VARCHAR(20),
    "StockCode"     VARCHAR(20),
    "Description"   TEXT,
    "Quantity"      INTEGER,
    "InvoiceDate"   TIMESTAMP,
    "UnitPrice"     NUMERIC(10,2),
    "CustomerID"    INTEGER,
    "Country"       VARCHAR(100),
    "IsCancelled"   BOOLEAN
);

CREATE TABLE customer_features (
    "CustomerID"          INTEGER PRIMARY KEY,
    "recency_days"        INTEGER,
    "frequency"           INTEGER,
    "monetary"            NUMERIC(12,2),
    "first_purchase"      TIMESTAMP,
    "last_purchase"       TIMESTAMP,
    "distinct_products"   INTEGER,
    "avg_order_value"     NUMERIC(12,2),
    "is_repeat_customer"  BOOLEAN,
    "tenure_days"         INTEGER
);
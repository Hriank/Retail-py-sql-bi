-- =============================================================================
-- Project: Customer Analytics Pipeline -- SQL Stage
-- Input: transactions_clean.csv (from Python stage) loaded into a table
--        `transactions(invoice_no, stock_code, description, quantity,
--                       invoice_date, unit_price, customer_id, country,
--                       total_price)`
-- Dialect: written for PostgreSQL / SQL Server (window functions are ANSI
--          standard; NTILE, DATE_TRUNC/DATEADD are noted where they differ)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CUSTOMER-LEVEL KPIs
-- -----------------------------------------------------------------------------
CREATE VIEW customer_kpis AS
SELECT
    customerid                                                    AS customer_id,
    COUNT(DISTINCT invoiceno)                                     AS total_orders,
    SUM(totalprice)                                                AS total_spend,
    ROUND(SUM(totalprice) / COUNT(DISTINCT invoiceno), 2)          AS avg_order_value,
    MIN(invoicedate)                                               AS first_purchase_date,
    MAX(invoicedate)                                               AS last_purchase_date,
    DATE_PART('day', MAX(invoicedate) - MIN(invoicedate))          AS tenure_days,
    COUNT(DISTINCT stockcode)                                      AS distinct_products_bought
FROM transactions
GROUP BY customerid;

-- -----------------------------------------------------------------------------
-- 2. RFM ANALYSIS (Recency, Frequency, Monetary) + segmentation
-- -----------------------------------------------------------------------------
WITH rfm_base AS (
    SELECT
        customer_id,
        DATE_PART('day', (SELECT MAX(invoice_date) FROM transactions) - MAX(invoice_date)) AS recency,
        COUNT(DISTINCT invoice_no) AS frequency,
        SUM(total_price)          AS monetary
    FROM transactions
    GROUP BY customer_id
),
rfm_scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        -- NTILE splits customers into 5 buckets; recency is inverted
        -- (lower recency = more recent = better score)
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    recency, frequency, monetary,
    r_score, f_score, m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating'
        ELSE 'Needs Attention'
    END AS customer_segment
INTO rfm_segments
FROM rfm_scored;

-- -----------------------------------------------------------------------------
-- 3. REPEAT VS ONE-TIME CUSTOMERS
-- -----------------------------------------------------------------------------
SELECT
    CASE WHEN total_orders = 1 THEN 'One-Time' ELSE 'Repeat' END AS customer_type,
    COUNT(*)                                    AS num_customers,
    SUM(total_spend)                            AS revenue,
    ROUND(SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 4) AS pct_of_revenue
FROM customer_kpis
GROUP BY CASE WHEN total_orders = 1 THEN 'One-Time' ELSE 'Repeat' END;

-- -----------------------------------------------------------------------------
-- 4. COHORT / RETENTION ANALYSIS
--    Cohort = month of a customer's first purchase.
--    cohort_index = number of months since first purchase.
-- -----------------------------------------------------------------------------
WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),
customer_orders AS (
    SELECT DISTINCT
        t.customer_id,
        DATE_TRUNC('month', t.invoice_date) AS order_month
    FROM transactions t
),
cohort_data AS (
    SELECT
        f.cohort_month,
        co.order_month,
        -- window function alternative: rank months relative to cohort start
        (DATE_PART('year', co.order_month) - DATE_PART('year', f.cohort_month)) * 12
          + (DATE_PART('month', co.order_month) - DATE_PART('month', f.cohort_month)) AS cohort_index,
        co.customer_id
    FROM customer_orders co
    JOIN first_purchase f ON co.customer_id = f.customer_id
)
SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_id) AS active_customers,
    -- retention rate vs. that cohort's month-0 size, using a window function
    ROUND(
      COUNT(DISTINCT customer_id) * 1.0 /
      FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER (
          PARTITION BY cohort_month ORDER BY cohort_index
      ), 4
    ) AS retention_rate
FROM cohort_data
GROUP BY cohort_month, cohort_index
ORDER BY cohort_month, cohort_index;

-- -----------------------------------------------------------------------------
-- 5. WINDOW FUNCTIONS SHOWCASE
--    (running totals, rankings, month-over-month growth -- these are the
--     lines to point to in an interview when asked "show me a window function")
-- -----------------------------------------------------------------------------

-- 5a. Running total of spend per customer, ordered by purchase date
SELECT
    customer_id,
    invoice_date,
    total_price,
    SUM(total_price) OVER (
        PARTITION BY customer_id ORDER BY invoice_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_customer_spend
FROM transactions;

-- 5b. Rank customers by total spend (dense rank handles ties)
SELECT
    customer_id,
    total_spend,
    RANK()       OVER (ORDER BY total_spend DESC) AS spend_rank,
    DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_dense_rank,
    NTILE(10)    OVER (ORDER BY total_spend DESC) AS spend_decile
FROM customer_kpis;

-- 5c. Month-over-month revenue growth using LAG
WITH monthly_rev AS (
    SELECT
        DATE_TRUNC('month', invoice_date) AS month,
        SUM(total_price) AS revenue
    FROM transactions
    GROUP BY DATE_TRUNC('month', invoice_date)
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
      (revenue - LAG(revenue) OVER (ORDER BY month)) /
      NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 2
    ) AS mom_growth_pct
FROM monthly_rev
ORDER BY month;

-- -----------------------------------------------------------------------------
-- 6. SIMPLE CUSTOMER LIFETIME VALUE (CLV) ESTIMATE
--    CLV = avg_order_value * purchase_frequency_per_year * avg_customer_lifespan_years
-- -----------------------------------------------------------------------------
WITH clv_inputs AS (
    SELECT
        customer_id,
        avg_order_value,
        total_orders,
        tenure_days,
        CASE WHEN tenure_days = 0 THEN 1 ELSE tenure_days END AS tenure_days_safe
    FROM customer_kpis
)
SELECT
    customer_id,
    avg_order_value,
    ROUND(total_orders * 365.0 / tenure_days_safe, 2) AS est_annual_purchase_freq,
    ROUND(
      avg_order_value * (total_orders * 365.0 / tenure_days_safe) * 2, 2
    ) AS est_2yr_clv   -- assumes a 2-year forward horizon; tune to business needs
FROM clv_inputs;

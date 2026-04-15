CREATE DATABASE IF NOT EXISTS olist_db;
USE olist_db;

-- QUICK PREVIEW 
-- ============================================================
 
SELECT COUNT(*) AS total_orders     FROM master_orders;
SELECT COUNT(*) AS total_customers  FROM master_customers;
SELECT COUNT(*) AS total_rfm_rows   FROM rfm_scored;
SELECT * FROM segment_profiles ORDER BY total_revenue DESC;

-- QUERY 1: MONTHLY REVENUE TREND WITH MONTH-OVER-MONTH GROWTH
-- ============================================================
-- Business question: Is Olist growing month by month?
 
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT order_id) AS order_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(total_payment), 2) AS total_revenue,
    ROUND(AVG(total_payment), 2) AS avg_order_value,
 
    ROUND(
        (
            SUM(total_payment)
            -
            LAG(SUM(total_payment), 1)
            OVER (ORDER BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m'))
        )
        /
        NULLIF(
            LAG(SUM(total_payment), 1)
            OVER (ORDER BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m'))
        , 0)
        * 100
    , 1) AS mom_growth_pct
 
FROM master_orders
WHERE
order_purchase_timestamp >= '2017-01-01'
AND order_purchase_timestamp < '2018-09-01'
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- ============================================================
-- QUERY 2: REVENUE BY PRODUCT CATEGORY (RANKED)
-- ============================================================
-- Business question: Which categories drive the most revenue?
 
SELECT
    primary_category,
    COUNT(DISTINCT order_id) AS order_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(total_payment), 2) AS total_revenue,
    ROUND(AVG(total_payment), 2) AS avg_order_value,
    ROUND(AVG(review_score), 2) AS avg_review_score,
 
    ROUND(
        SUM(total_payment) * 100.0
        / SUM(SUM(total_payment)) OVER ()
    , 2) AS revenue_pct,
 
    RANK() OVER (ORDER BY SUM(total_payment) DESC) AS revenue_rank,
    RANK() OVER (ORDER BY AVG(total_payment) DESC) AS premium_rank
 
FROM master_orders
WHERE primary_category IS NOT NULL
AND primary_category NOT IN ('unknown', 'uncategorized')
GROUP BY primary_category
ORDER BY total_revenue DESC
LIMIT 20;

-- ============================================================
-- QUERY 3: RFM SCORING IN PURE SQL
-- ============================================================
 
WITH rfm_raw AS (
    -- Step 1: Calculate raw R, F, M values per customer
    SELECT
        customer_unique_id,
        DATEDIFF('2018-10-18', MAX(order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        ROUND(SUM(total_payment), 2) AS monetary
    FROM master_orders
    GROUP BY customer_unique_id
),
 
rfm_scores AS (
    -- Step 2: Score R and M with NTILE. Score F with CASE WHEN.
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
 
        -- R score: smaller recency_days = bought more recently = better = score 5
        -- NTILE gives 1 to smallest, so we reverse: 6 - NTILE
        (6 - NTILE(5) OVER (ORDER BY recency_days ASC))   AS r_score,
 
        -- F score: CASE WHEN (NOT NTILE) — matches Python exactly
        -- Why: 96.5% bought once. NTILE would wrongly give those customers
        -- scores of 2, 3, 4. CASE WHEN correctly gives them all F=1.
        CASE
            WHEN frequency >= 6 THEN 5
            WHEN frequency >= 4 THEN 4
            WHEN frequency =  3 THEN 3
            WHEN frequency =  2 THEN 2
            ELSE 1
        END AS f_score,
 
        -- M score: higher spend = score 5
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
 
    FROM rfm_raw
),
 
rfm_labeled AS (
    -- Step 3: Build composite score and assign segment name
    -- Segment rules match Python Phase 5 exactly
    SELECT
        *,
        CONCAT(r_score, f_score, m_score) AS rfm_code,
        r_score + f_score + m_score AS rfm_sum,
 
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN r_score = 1 AND f_score >= 4 AND m_score >= 4
                THEN "Can't Lose Them"
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3
                THEN 'At Risk'
            WHEN f_score >= 3 AND m_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score = 1
                THEN 'New Customers'
            WHEN r_score >= 3 AND f_score <= 3 AND m_score <= 3
                THEN 'Potential Loyalists'
            WHEN r_score >= 3 AND f_score = 1
                THEN 'Promising'
            WHEN r_score BETWEEN 2 AND 3
             AND f_score BETWEEN 2 AND 3
             AND m_score BETWEEN 2 AND 3
                THEN 'Need Attention'
            WHEN r_score BETWEEN 2 AND 3
             AND f_score <= 2 AND m_score <= 2
                THEN 'About To Sleep'
            WHEN r_score = 1 AND f_score = 1 AND m_score = 1
                THEN 'Lost'
            ELSE 'Hibernating'
        END AS segment
 
    FROM rfm_scores
)
 
SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(
        SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER ()
    , 2) AS revenue_pct
FROM rfm_labeled
GROUP BY segment
ORDER BY total_revenue DESC;

-- ============================================================
-- QUERY 4: TOP 50 CUSTOMERS BY VALUE + PERCENTILE RANK
-- ============================================================
-- Business question: Who are our top 50 most valuable customers?
 
SELECT
    rs.customer_unique_id,
    rs.customer_state,
    rs.preferred_category,
    rs.segment,
    rs.recency_days,
    rs.frequency AS total_orders,
    ROUND(rs.monetary, 2) AS total_spend,
    ROUND(rs.avg_review_score, 2) AS avg_review,
 
    ROW_NUMBER() OVER (ORDER BY rs.monetary DESC) AS spend_rank,
 
    ROUND(PERCENT_RANK() OVER (ORDER BY rs.monetary ASC) * 100, 1) AS spend_percentile,
 
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY rs.monetary ASC) >= 0.99 THEN 'Top 1%'
        WHEN PERCENT_RANK() OVER (ORDER BY rs.monetary ASC) >= 0.90 THEN 'Top 10%'
        WHEN PERCENT_RANK() OVER (ORDER BY rs.monetary ASC) >= 0.80 THEN 'Top 20%'
        ELSE 'Rest'
    END AS value_tier
 
FROM rfm_scored rs
ORDER BY rs.monetary DESC
LIMIT 50;

-- ============================================================
-- QUERY 5: DELIVERY DELAY BY STATE
-- ============================================================
-- Business question: Which states have the worst delivery?
--                   Do problem states have more churned customers?
 
SELECT
    mo.customer_state,
    COUNT(DISTINCT mo.order_id) AS total_orders,
    ROUND(AVG(mo.delivery_delay_days), 1) AS avg_delay_days,
 
    ROUND(
        SUM(CASE WHEN mo.delivery_delay_days > 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 1) AS pct_late,
 
    ROUND(
        SUM(CASE WHEN mo.delivery_delay_days < 0 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
    , 1) AS pct_early,
 
    ROUND(AVG(mo.review_score), 2) AS avg_review_score,
 
    ROUND(
        SUM(CASE WHEN rs.segment IN ('Lost', 'At Risk') THEN 1 ELSE 0 END)
        * 100.0 / COUNT(DISTINCT mo.customer_unique_id)
    , 1) AS pct_at_risk_or_lost
 
FROM master_orders mo
LEFT JOIN rfm_scored rs ON mo.customer_unique_id = rs.customer_unique_id
WHERE mo.delivery_delay_days IS NOT NULL
GROUP BY mo.customer_state
HAVING COUNT(DISTINCT mo.order_id) >= 100
ORDER BY avg_delay_days DESC;

-- ============================================================
-- QUERY 6: PAYMENT BEHAVIOUR BY SEGMENT (CORRECTED)
-- ============================================================
-- Business question: Do Champions use fewer installments than Lost customers?
--
-- FIX APPLIED: used_credit_card_ever is in master_customers, NOT rfm_scored.
-- We JOIN master_customers to get this column.
--
-- SQL TECHNIQUES EXPLAINED:
--   AVG(CASE WHEN ... THEN value END):
--     Computes average only among rows where condition is true.
--     Rows where condition is false contribute NULL, which AVG ignores.
--     This is how you calculate "avg spend AMONG credit card users only".
 
SELECT
    rs.segment,
    COUNT(DISTINCT rs.customer_unique_id) AS customer_count,
    ROUND(AVG(rs.avg_installments), 1) AS avg_installments,
 
    -- used_credit_card_ever comes from master_customers (not rfm_scored)
    ROUND(AVG(mc.used_credit_card_ever) * 100.0, 1) AS pct_used_credit_card,
 
    -- Avg spend for credit card users only
    ROUND(
        AVG(CASE WHEN mc.used_credit_card_ever = 1 THEN rs.monetary END)
    , 2) AS avg_spend_cc_users,
 
    -- Avg spend for non-credit card users only
    ROUND(
        AVG(CASE WHEN mc.used_credit_card_ever = 0 THEN rs.monetary END)
    , 2) AS avg_spend_non_cc,
 
    ROUND(SUM(rs.monetary), 2) AS total_segment_revenue
 
FROM rfm_scored rs
-- JOIN to master_customers to get used_credit_card_ever column
JOIN master_customers mc ON rs.customer_unique_id = mc.customer_unique_id
GROUP BY rs.segment
ORDER BY total_segment_revenue DESC;

-- ============================================================
-- QUERY 7: COHORT RETENTION ANALYSIS
-- ============================================================
-- Business question: Of customers who first bought in Month X,
--                   what % came back in subsequent months?
 
WITH
cohorts AS (
    -- Step 1: Find when each customer first bought
    SELECT
        customer_unique_id,
        DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS cohort_month
    FROM master_orders
    GROUP BY customer_unique_id
),
orders_tagged AS (
    -- Step 2: For every order, calculate months elapsed since first purchase
    SELECT
        mo.customer_unique_id,
        c.cohort_month,
        DATE_FORMAT(mo.order_purchase_timestamp, '%Y-%m-01') AS order_month,
        TIMESTAMPDIFF(
            MONTH,
            c.cohort_month,
            DATE_FORMAT(mo.order_purchase_timestamp, '%Y-%m-01')
        ) AS cohort_index
    FROM master_orders mo
    JOIN cohorts c ON mo.customer_unique_id = c.customer_unique_id
),
counts AS (
    -- Step 3: Count unique customers per cohort per month
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS customers
    FROM orders_tagged
    GROUP BY cohort_month, cohort_index
),
sizes AS (
    -- Step 4: Get cohort size (month 0 = first purchase month)
    SELECT cohort_month, customers AS cohort_size
    FROM counts
    WHERE cohort_index = 0
)
-- Step 5: Calculate retention rate
SELECT
    c.cohort_month,
    c.cohort_index AS months_after_first_purchase,
    s.cohort_size,
    c.customers AS returning_customers,
    ROUND(c.customers * 100.0 / s.cohort_size, 2)  AS retention_rate_pct
FROM counts c
JOIN sizes s ON c.cohort_month = s.cohort_month
WHERE
    c.cohort_month >= '2017-01-01'
    AND c.cohort_month <= '2017-12-01'
    AND c.cohort_index <= 11
ORDER BY c.cohort_month, c.cohort_index;

-- ============================================================
-- QUERY 8: SEGMENT RECOMMENDATIONS WITH CAMPAIGN ROI
-- ============================================================
-- Business question: For each segment, what action gives highest ROI?
 
WITH segment_summary AS (
    SELECT
        segment,
        COUNT(*) AS customer_count,
        ROUND(AVG(recency_days), 1) AS avg_recency,
        ROUND(AVG(frequency), 2) AS avg_frequency,
        ROUND(AVG(monetary), 2) AS avg_monetary,
        ROUND(SUM(monetary), 2) AS total_revenue,
        ROUND(AVG(avg_review_score), 2) AS avg_satisfaction,
        ROUND(AVG(avg_delivery_delay_days), 1) AS avg_delivery_delay
    FROM rfm_scored
    GROUP BY segment
),
totals AS (
    SELECT
        SUM(total_revenue)  AS grand_total_revenue,
        SUM(customer_count) AS grand_total_customers
    FROM segment_summary
)
 
SELECT
    ss.segment,
    ss.customer_count,
    ROUND(ss.customer_count * 100.0 / t.grand_total_customers, 1) AS customer_pct,
    ss.avg_recency,
    ss.avg_frequency,
    ss.avg_monetary,
    ss.total_revenue,
    ROUND(ss.total_revenue * 100.0 / t.grand_total_revenue, 1) AS revenue_pct,
    ss.avg_satisfaction,
    ss.avg_delivery_delay,
 
    CASE
        WHEN ss.segment IN ('Champions', 'Loyal Customers')
            THEN '1 - Reward: loyalty programme + exclusive perks'
        WHEN ss.segment IN ('At Risk', "Can't Lose Them")
            THEN '2 - Urgent win-back: personalised email + 15% discount'
        WHEN ss.segment IN ('New Customers', 'Potential Loyalists')
            THEN '3 - Nurture: 3-email onboarding (days 3, 14, 28)'
        WHEN ss.segment IN ('Need Attention', 'About To Sleep', 'Promising')
            THEN '4 - Re-engage: discount on preferred category'
        ELSE '5 - Low-cost reactivation email'
    END AS campaign_action,
 
    ROUND(
        ss.total_revenue * CASE
            WHEN ss.segment = 'At Risk'          THEN 0.85
            WHEN ss.segment = "Can't Lose Them"  THEN 1.00
            WHEN ss.segment = 'About To Sleep'   THEN 0.60
            WHEN ss.segment = 'Promising'        THEN 0.30
            ELSE 0.00
        END
    , 2) AS revenue_at_risk,
 
    CASE
        WHEN ss.segment IN ('At Risk', "Can't Lose Them", 'About To Sleep')
        THEN ROUND(
            (
                (ss.avg_monetary * 0.15 * ss.customer_count)
                - (25 * ss.customer_count)
            )
            / NULLIF(25 * ss.customer_count, 0) * 100
        , 0)
        WHEN ss.segment IN ('New Customers', 'Potential Loyalists', 'Promising')
        THEN ROUND(
            (
                (ss.avg_monetary * 0.045 * ss.customer_count)
                - (5 * ss.customer_count)
            )
            / NULLIF(5 * ss.customer_count, 0) * 100
        , 0)
        ELSE NULL
    END AS estimated_roi_pct
 
FROM segment_summary ss
CROSS JOIN totals t
ORDER BY ss.total_revenue DESC;

-- ============================================================
-- QUERY 9: TOP 3 CATEGORIES PER SEGMENT
-- ============================================================
-- Business question: What does each segment prefer to buy?
 
SELECT *
FROM (
    SELECT
        rs.segment,
        mo.primary_category,
        COUNT(DISTINCT mo.order_id) AS orders,
        COUNT(DISTINCT mo.customer_unique_id) AS customers,
        ROUND(AVG(mo.total_payment), 2) AS avg_order_value,
        ROUND(AVG(mo.review_score), 2) AS avg_review,
        RANK() OVER (
            PARTITION BY rs.segment
            ORDER BY COUNT(DISTINCT mo.order_id) DESC
        ) AS cat_rank
    FROM master_orders mo
    JOIN rfm_scored rs ON mo.customer_unique_id = rs.customer_unique_id
    WHERE mo.primary_category IS NOT NULL
      AND mo.primary_category NOT IN ('unknown', 'uncategorized')
    GROUP BY rs.segment, mo.primary_category
) ranked
WHERE cat_rank <= 3
ORDER BY segment, cat_rank;
 
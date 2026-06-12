-- ============================================================
-- UPI TRANSACTIONS ANALYSIS
-- Database: upi_transactions
-- ============================================================

CREATE DATABASE upi_transactions


USE upi_transactions


-- ============================================================
-- PREVIEW DATA
-- ============================================================

-- Top 5 rows ordered by date
SELECT TOP 5 *
FROM upi_clean_data
ORDER BY year, month_num

-- Verify key columns
SELECT
    year,
    month_num,
    month_name,
    upi_volume_lakh,
    upi_value_crore,
    avg_txn_value_rs
FROM upi_clean_data
ORDER BY year, month_num


-- ============================================================
-- Q1: Overall Growth in Volume and Value (2019 vs 2026)
-- How many times has UPI grown from its earliest to latest year?
-- ============================================================

SELECT
    MIN(CASE WHEN year = 2019 THEN upi_volume_lakh END)  AS vol_2019,
    MAX(CASE WHEN year = 2026 THEN upi_volume_lakh END)  AS vol_2026,
    ROUND(
        MAX(CASE WHEN year = 2026 THEN upi_volume_lakh END) /
        MIN(CASE WHEN year = 2019 THEN upi_volume_lakh END), 2
    )                                                     AS volume_growth_times,

    MIN(CASE WHEN year = 2019 THEN upi_value_crore END)  AS val_2019,
    MAX(CASE WHEN year = 2026 THEN upi_value_crore END)  AS val_2026,
    ROUND(
        MAX(CASE WHEN year = 2026 THEN upi_value_crore END) /
        MIN(CASE WHEN year = 2019 THEN upi_value_crore END), 2
    )                                                     AS value_growth_times

FROM upi_clean_data
WHERE year IN (2019, 2026)


-- ============================================================
-- Q2: Year-on-Year Growth Rate
-- Which year saw the highest % growth in UPI transactions?
-- Note: 2019 and 2026 excluded as partial years (no prev/next year to compare)
-- ============================================================

WITH yearly_totals AS (
    SELECT
        year,
        SUM(upi_volume_lakh)  AS total_volume,
        SUM(upi_value_crore)  AS total_value
    FROM upi_clean_data
    GROUP BY year
),
yearly_growth AS (
    SELECT
        year,
        total_volume,
        total_value,
        LAG(total_volume) OVER (ORDER BY year)  AS prev_year_volume,
        LAG(total_value)  OVER (ORDER BY year)  AS prev_year_value
    FROM yearly_totals
)
SELECT
    year,
    ROUND(total_volume, 2)                                           AS total_volume_lakh,
    ROUND(total_value,  2)                                           AS total_value_crore,
    ROUND(
        (total_volume - prev_year_volume) / prev_year_volume * 100
    , 2)                                                             AS volume_growth_pct,
    ROUND(
        (total_value  - prev_year_value)  / prev_year_value  * 100
    , 2)                                                             AS value_growth_pct
FROM yearly_growth
WHERE year NOT IN (2019, 2026)
ORDER BY year


-- ============================================================
-- Q3: Months with Negative Growth vs Previous Month
-- Which months saw a drop in UPI transaction volume (MoM)?
-- ============================================================

WITH monthly_growth AS (
    SELECT
        year,
        month_num,
        month_name,
        upi_volume_lakh,
        LAG(upi_volume_lakh) OVER (ORDER BY year, month_num)  AS prev_month_volume,
        ROUND(
            (upi_volume_lakh - LAG(upi_volume_lakh) OVER (ORDER BY year, month_num))
            / LAG(upi_volume_lakh) OVER (ORDER BY year, month_num) * 100
        , 2)                                                   AS mom_growth_pct
    FROM upi_clean_data
)
SELECT
    year,
    month_name,
    ROUND(upi_volume_lakh,   2)  AS volume_lakh,
    ROUND(prev_month_volume, 2)  AS prev_month_volume,
    mom_growth_pct
FROM monthly_growth
WHERE mom_growth_pct < 0
ORDER BY year, month_num


-- ============================================================
-- Q4: Monthly Seasonality
-- Which months are consistently busiest/slowest across all years?
-- Note: 2019 and 2026 excluded as partial years to avoid skewed averages
-- ============================================================

WITH monthly_avg AS (
    SELECT
        month_num,
        month_name,
        ROUND(AVG(upi_volume_lakh), 2)  AS avg_volume_lakh,
        ROUND(AVG(upi_value_crore), 2)  AS avg_value_crore
    FROM upi_clean_data
    WHERE year NOT IN (2019, 2026)
    GROUP BY month_num, month_name
),
ranked AS (
    SELECT
        month_num,
        month_name,
        avg_volume_lakh,
        avg_value_crore,
        RANK() OVER (ORDER BY avg_volume_lakh DESC)  AS volume_rank
    FROM monthly_avg
)
SELECT
    volume_rank,
    month_name,
    avg_volume_lakh,
    avg_value_crore
FROM ranked
ORDER BY volume_rank


-- ============================================================
-- Q5: Best Performing Quarter
-- Which quarter consistently has the highest UPI transaction volume?
-- Note: 2019 and 2026 excluded as partial years
-- ============================================================

WITH quarters AS (
    SELECT
        year,
        upi_volume_lakh,
        CASE
            WHEN month_num IN (1, 2, 3)   THEN 'Q1'
            WHEN month_num IN (4, 5, 6)   THEN 'Q2'
            WHEN month_num IN (7, 8, 9)   THEN 'Q3'
            WHEN month_num IN (10, 11, 12) THEN 'Q4'
        END AS quarter
    FROM upi_clean_data
    WHERE year NOT IN (2019, 2026)
),
quarterly_totals AS (
    SELECT
        year,
        quarter,
        SUM(upi_volume_lakh)  AS total_volume
    FROM quarters
    GROUP BY year, quarter
)
SELECT
    quarter,
    ROUND(AVG(total_volume), 2)              AS avg_volume_lakh,
    RANK() OVER (ORDER BY AVG(total_volume) DESC)  AS quarter_rank
FROM quarterly_totals
GROUP BY quarter
ORDER BY quarter_rank


-- ============================================================
-- Q6: Average Transaction Value Per Year
-- How has the average UPI transaction size changed over the years?
-- Note: 2019 and 2026 excluded as partial years
-- ============================================================

SELECT
    year,
    ROUND(AVG(avg_txn_value_rs), 2)  AS avg_txn_value_per_year
FROM upi_clean_data
WHERE year NOT IN (2019, 2026)
GROUP BY year
ORDER BY year


-- ============================================================
-- Q7: Year with Highest Growth Rate
-- Refer to Q2 results -- sort by volume_growth_pct DESC to find the peak year
-- ============================================================


-- ============================================================
-- Q8: COVID Recovery -- Monthly Volume Comparison (2020 vs 2021)
-- How quickly did UPI recover post-COVID lockdown months (Mar-Jun)?
-- ============================================================

SELECT
    month_name,
    month_num,
    ROUND(SUM(CASE WHEN year = 2020 THEN upi_volume_lakh END), 2)  AS vol_2020,
    ROUND(SUM(CASE WHEN year = 2021 THEN upi_volume_lakh END), 2)  AS vol_2021,
    ROUND(
        (
            SUM(CASE WHEN year = 2021 THEN upi_volume_lakh END) -
            SUM(CASE WHEN year = 2020 THEN upi_volume_lakh END)
        ) /
        SUM(CASE WHEN year = 2020 THEN upi_volume_lakh END) * 100
    , 2)                                                            AS recovery_pct
FROM upi_clean_data
WHERE year      IN (2020, 2021)
  AND month_num IN (3, 4, 5, 6)
GROUP BY month_name, month_num
ORDER BY month_num
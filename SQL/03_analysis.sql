-- ============================================================
-- FASHION TREND INVENTORY — CORE ANALYSIS QUERIES
-- ============================================================


-- ── QUERY 1: Trend Phase Distribution ────────────────────────
-- Business Question: How many trends are currently in each phase?
-- Used in: Power BI → Trend Overview Page

SELECT
    trend_phase,
    COUNT(DISTINCT trend_name)                          AS trend_count,
    ROUND(AVG(trend_score)::NUMERIC, 4)                 AS avg_trend_score,
    ROUND(AVG(search_volume_idx)::NUMERIC, 0)           AS avg_search_volume,
    ROUND(AVG(social_mentions)::NUMERIC, 0)             AS avg_social_mentions
FROM trend_signals
GROUP BY trend_phase
ORDER BY avg_trend_score DESC;


-- ── QUERY 2: Top 10 Rising Trends Right Now ──────────────────
-- Business Question: Which trends are rising fastest this month?
-- Used in: Power BI → Trend Radar Page

SELECT
    ts.trend_name,
    ts.trend_phase,
    ts.trend_score,
    ts.search_volume_idx,
    ts.social_mentions,
    ts.week_start_date,
    -- Week over week change
    ts.trend_score - LAG(ts.trend_score) OVER (
        PARTITION BY ts.trend_name ORDER BY ts.week_number
    )                                                   AS score_wow_change
FROM trend_signals ts
WHERE ts.trend_phase IN ('Rising', 'Emerging')
  AND ts.week_start_date >= '2024-01-01'
ORDER BY ts.trend_score DESC
LIMIT 10;


-- ── QUERY 3: Trend-to-Inventory Gap Analysis ─────────────────
-- THE CORE QUERY of the entire project
-- Business Question: For rising trends, how much inventory exists
--                   vs how much is needed?
-- Used in: Power BI → Gap Analysis Page

WITH latest_inventory AS (
    SELECT
        sku_id,
        category,
        closing_stock,
        inventory_health,
        weeks_of_cover,
        snapshot_date,
        ROW_NUMBER() OVER (
            PARTITION BY sku_id ORDER BY snapshot_date DESC
        ) AS rn
    FROM inventory
),
trend_demand AS (
    SELECT
        tm.sku_id,
        tm.trend_name,
        tm.category,
        tm.relevance_score,
        tm.is_hero_sku,
        ts.trend_score,
        ts.trend_phase,
        ts.search_volume_idx
    FROM trend_sku_mapping tm
    JOIN trend_signals ts
        ON tm.trend_id = ts.trend_id
    WHERE ts.trend_phase IN ('Rising', 'Peaking')
      AND ts.week_start_date >= '2024-06-01'
)
SELECT
    td.trend_name,
    td.trend_phase,
    td.category,
    td.sku_id,
    td.relevance_score,
    td.trend_score,
    li.closing_stock,
    li.inventory_health,
    li.weeks_of_cover,
    -- Gap Score: high trend score + low inventory = danger
    ROUND((td.trend_score * 100) / NULLIF(li.weeks_of_cover, 0), 2)
                                                        AS gap_score,
    CASE
        WHEN li.inventory_health IN ('Critical','Low')
         AND td.trend_score > 0.6  THEN 'URGENT — Buy Now'
        WHEN li.inventory_health = 'Healthy'
         AND td.trend_score > 0.7  THEN 'Monitor — Rising Fast'
        WHEN li.inventory_health = 'Overstock'
         AND td.trend_score < 0.3  THEN 'WARNING — Trend Dying'
        ELSE 'Stable'
    END                                                 AS action_flag
FROM trend_demand td
JOIN latest_inventory li
    ON td.sku_id = li.sku_id AND li.rn = 1
ORDER BY gap_score DESC
LIMIT 50;


-- ── QUERY 4: Dead Stock Early Warning ────────────────────────
-- Business Question: Which SKUs have high inventory but dying trends?
-- Used in: Power BI → Dead Stock Alerts Page

WITH latest_inv AS (
    SELECT
        sku_id,
        closing_stock,
        inventory_value,
        weeks_of_cover,
        inventory_health,
        snapshot_date,
        ROW_NUMBER() OVER (
            PARTITION BY sku_id ORDER BY snapshot_date DESC
        ) AS rn
    FROM inventory
),
dying_trends AS (
    SELECT
        tm.sku_id,
        tm.trend_name,
        tm.category,
        ts.trend_score,
        ts.trend_phase
    FROM trend_sku_mapping tm
    JOIN trend_signals ts ON tm.trend_id = ts.trend_id
    WHERE ts.trend_phase IN ('Declining', 'Dead')
      AND ts.week_start_date >= '2024-01-01'
)
SELECT
    dt.trend_name,
    dt.trend_phase,
    dt.category,
    dt.sku_id,
    li.closing_stock,
    li.inventory_health,
    li.weeks_of_cover,
    ROUND(li.inventory_value::NUMERIC, 2)               AS inventory_value_inr,
    dt.trend_score,
    -- Dead stock risk score
    ROUND((li.weeks_of_cover * (1 - dt.trend_score))::NUMERIC, 2)
                                                        AS deadstock_risk_score
FROM dying_trends dt
JOIN latest_inv li ON dt.sku_id = li.sku_id AND li.rn = 1
WHERE li.closing_stock > 100
  AND li.weeks_of_cover > 8
ORDER BY deadstock_risk_score DESC
LIMIT 50;


-- ── QUERY 5: Buying Window Calculator ────────────────────────
-- Business Question: For each rising trend, how many weeks do we
--                   have before the trend peaks? Is there enough
--                   time to place a PO and receive stock?
-- Used in: Power BI → Buying Decisions Page

-- ── QUERY 5: Buying Window Calculator (FINAL FIX) ────────────

WITH active_trends AS (
    SELECT
        trend_name,
        trend_phase,
        peak_week,
        week_number                                     AS current_week,
        peak_week - week_number                         AS weeks_to_peak,
        trend_score,
        week_start_date
    FROM trend_signals
    WHERE trend_phase IN ('Emerging', 'Rising', 'Peaking')
      AND trend_score > 0.3
),
-- Take the most recent active snapshot per trend
latest_active AS (
    SELECT DISTINCT ON (trend_name)
        trend_name,
        trend_phase,
        peak_week,
        current_week,
        weeks_to_peak,
        trend_score,
        week_start_date
    FROM active_trends
    ORDER BY trend_name, week_start_date DESC
),
avg_lead_time AS (
    SELECT
        p.category,
        ROUND(AVG(po.lead_time_days)::NUMERIC, 0)       AS avg_lead_days
    FROM purchase_orders po
    JOIN products p ON po.sku_id = p.sku_id
    GROUP BY p.category
)
SELECT
    la.trend_name,
    la.trend_phase,
    la.week_start_date                                  AS last_active_date,
    la.current_week,
    la.peak_week,
    la.weeks_to_peak,
    la.trend_score,
    alt.category,
    alt.avg_lead_days,
    ROUND(alt.avg_lead_days / 7.0, 1)                  AS avg_lead_weeks,
    ROUND(
        (la.weeks_to_peak - (alt.avg_lead_days / 7.0))::NUMERIC
    , 1)                                                AS buying_window_weeks,
    CASE
        WHEN la.weeks_to_peak - (alt.avg_lead_days/7.0) > 4
            THEN 'BUY NOW — Good Window'
        WHEN la.weeks_to_peak - (alt.avg_lead_days/7.0) BETWEEN 1 AND 4
            THEN 'RUSH ORDER — Tight Window'
        WHEN la.weeks_to_peak - (alt.avg_lead_days/7.0) <= 0
            THEN 'TOO LATE — Trend Peaking'
        ELSE 'MONITOR'
    END                                                 AS buying_decision
FROM latest_active la
CROSS JOIN avg_lead_time alt
ORDER BY buying_window_weeks DESC
LIMIT 30;


-- ── QUERY 6: Brand-wise Revenue & Margin Performance ─────────
-- Business Question: Which brands are most profitable and why?
-- Used in: Power BI → Brand Performance Page

SELECT
    brand,
    COUNT(DISTINCT sku_id)                              AS total_skus,
    SUM(quantity)                                       AS units_sold,
    ROUND(SUM(revenue)::NUMERIC, 2)                     AS total_revenue,
    ROUND(SUM(gross_profit)::NUMERIC, 2)                AS total_gross_profit,
    ROUND(AVG(gross_margin_pct)::NUMERIC, 2)            AS avg_margin_pct,
    ROUND(AVG(discount_pct)::NUMERIC, 2)                AS avg_discount_pct,
    ROUND(SUM(revenue) / NULLIF(COUNT(DISTINCT sku_id),0)::NUMERIC, 2)
                                                        AS revenue_per_sku,
    SUM(CASE WHEN is_returned = 1 THEN 1 ELSE 0 END)   AS total_returns,
    ROUND(
        SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS return_rate_pct
FROM sales_transactions
GROUP BY brand
ORDER BY total_revenue DESC;


-- ── QUERY 7: Channel Performance Analysis ────────────────────
-- Business Question: Which sales channel gives best margin?
-- Used in: Power BI → Channel Analysis Page

SELECT
    channel,
    COUNT(*)                                            AS total_orders,
    SUM(quantity)                                       AS units_sold,
    ROUND(SUM(revenue)::NUMERIC, 2)                     AS total_revenue,
    ROUND(AVG(selling_price)::NUMERIC, 2)               AS avg_selling_price,
    ROUND(AVG(discount_pct)::NUMERIC, 2)                AS avg_discount_pct,
    ROUND(AVG(gross_margin_pct)::NUMERIC, 2)            AS avg_margin_pct,
    ROUND(
        SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS return_rate_pct,
    ROUND(SUM(revenue) / COUNT(*)::NUMERIC, 2)          AS revenue_per_order
FROM sales_transactions
GROUP BY channel
ORDER BY total_revenue DESC;


-- ── QUERY 8: Geographic Trend Sensitivity Analysis ───────────
-- Business Question: Which cities adopt trends fastest?
--                   Where should we launch trend-led products first?
-- Used in: Power BI → Geographic Intelligence Page

SELECT
    city,
    region,
    city_tier,
    COUNT(*)                                            AS total_orders,
    ROUND(SUM(revenue)::NUMERIC, 2)                     AS total_revenue,
    ROUND(AVG(trend_sensitivity)::NUMERIC, 2)           AS trend_sensitivity,
    ROUND(AVG(discount_pct)::NUMERIC, 2)                AS avg_discount,
    ROUND(AVG(gross_margin_pct)::NUMERIC, 2)            AS avg_margin,
    ROUND(
        SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS return_rate_pct
FROM sales_transactions
GROUP BY city, region, city_tier
ORDER BY trend_sensitivity DESC, total_revenue DESC;


-- ── QUERY 9: Seasonal Inventory vs Sales Alignment ───────────
-- Business Question: Are we stocking the right products
--                   in the right season?
-- Used in: Power BI → Seasonal Intelligence Page

SELECT
    s.season,
    s.category,
    COUNT(DISTINCT s.sku_id)                            AS skus_selling,
    SUM(s.quantity)                                     AS units_sold,
    ROUND(SUM(s.revenue)::NUMERIC, 2)                   AS revenue,
    ROUND(AVG(s.gross_margin_pct)::NUMERIC, 2)          AS avg_margin,
    ROUND(AVG(i.closing_stock)::NUMERIC, 0)             AS avg_stock_level,
    ROUND(AVG(i.weeks_of_cover)::NUMERIC, 1)            AS avg_weeks_cover,
    -- Alignment score: are sales and stock moving together?
    ROUND(
        SUM(s.quantity)::NUMERIC /
        NULLIF(AVG(i.closing_stock), 0), 4
    )                                                   AS sell_through_rate
FROM sales_transactions s
JOIN inventory i
    ON s.sku_id = i.sku_id
    AND DATE_TRUNC('week', s.sale_date) = i.snapshot_date
GROUP BY s.season, s.category
ORDER BY s.season, revenue DESC;


-- ── QUERY 10: Supplier Lead Time & Delay Analysis ────────────
-- Business Question: Which suppliers are causing delays
--                   that kill our trend window?
-- Used in: Power BI → Supply Chain Page

SELECT
    supplier,
    COUNT(*)                                            AS total_pos,
    ROUND(AVG(lead_time_days)::NUMERIC, 1)              AS avg_lead_days,
    ROUND(AVG(delay_days)::NUMERIC, 1)                  AS avg_delay_days,
    SUM(CASE WHEN is_delayed=1 THEN 1 ELSE 0 END)       AS delayed_pos,
    ROUND(
        SUM(CASE WHEN is_delayed=1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS delay_rate_pct,
    ROUND(AVG(fulfillment_rate)::NUMERIC, 2)            AS avg_fulfillment_pct,
    ROUND(SUM(po_value)::NUMERIC, 2)                    AS total_po_value
FROM purchase_orders
GROUP BY supplier
ORDER BY delay_rate_pct DESC;


-- ── QUERY 11: Social Signal Momentum by Platform ─────────────
-- Business Question: Which platform is the best early signal
--                   for trend detection?
-- Used in: Power BI → Social Intelligence Page

SELECT
    platform,
    COUNT(*)                                            AS total_signals,
    ROUND(AVG(mentions)::NUMERIC, 0)                    AS avg_mentions,
    ROUND(AVG(hashtag_reach)::NUMERIC, 0)               AS avg_reach,
    ROUND(AVG(engagement_rate)::NUMERIC, 4)             AS avg_engagement,
    ROUND(AVG(trend_score)::NUMERIC, 4)                 AS avg_trend_score,
    SUM(CASE WHEN is_peak_week=1 THEN 1 ELSE 0 END)     AS peak_week_signals,
    -- Signal lead score: high engagement before peak = good early signal
    ROUND(AVG(CASE WHEN is_peak_week=0
        THEN engagement_rate ELSE NULL END)::NUMERIC, 4)
                                                        AS pre_peak_engagement
FROM social_signals
GROUP BY platform
ORDER BY pre_peak_engagement DESC;


-- ── QUERY 12: Category Trend Alignment Score ─────────────────
-- Business Question: Which categories are most aligned with
--                   current trends vs lagging behind?
-- Used in: Power BI → Category Intelligence Page

WITH category_trend AS (
    SELECT
        tm.category,
        AVG(ts.trend_score)                             AS avg_trend_score,
        COUNT(DISTINCT tm.trend_name)                   AS active_trends
    FROM trend_sku_mapping tm
    JOIN trend_signals ts ON tm.trend_id = ts.trend_id
    WHERE ts.trend_phase IN ('Rising','Peaking')
    GROUP BY tm.category
),
category_sales AS (
    SELECT
        category,
        ROUND(SUM(revenue)::NUMERIC, 2)                 AS revenue,
        ROUND(AVG(gross_margin_pct)::NUMERIC, 2)        AS margin,
        ROUND(
            SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*), 2
        )                                               AS return_rate
    FROM sales_transactions
    GROUP BY category
)
SELECT
    cs.category,
    cs.revenue,
    cs.margin,
    cs.return_rate,
    ROUND(ct.avg_trend_score::NUMERIC, 4)               AS trend_score,
    ct.active_trends,
    -- Alignment: high sales + high trend score = well aligned
    ROUND((cs.revenue / 1000000 * ct.avg_trend_score)::NUMERIC, 4)
                                                        AS alignment_score
FROM category_sales cs
LEFT JOIN category_trend ct ON cs.category = ct.category
ORDER BY alignment_score DESC;


-- ── QUERY 13: Weekly Revenue Trend (Time Series) ─────────────
-- Business Question: What is our revenue trajectory week by week?
-- Used in: Power BI → Executive Dashboard Page

SELECT
    DATE_TRUNC('week', sale_date)::DATE                 AS week_start,
    EXTRACT(YEAR FROM DATE_TRUNC('week', sale_date))    AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('week', sale_date))   AS month,
    COUNT(*)                                            AS orders,
    SUM(quantity)                                       AS units_sold,
    ROUND(SUM(revenue)::NUMERIC, 2)                     AS weekly_revenue,
    ROUND(AVG(gross_margin_pct)::NUMERIC, 2)            AS avg_margin,
    ROUND(AVG(discount_pct)::NUMERIC, 2)                AS avg_discount,
    SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)      AS returns,
    ROUND(SUM(SUM(revenue)) OVER (
        ORDER BY DATE_TRUNC('week', sale_date)
    )::NUMERIC, 2)                                      AS cumulative_revenue
FROM sales_transactions
GROUP BY DATE_TRUNC('week', sale_date)
ORDER BY week_start;


-- ── QUERY 14: Stockout Impact Analysis ───────────────────────
-- Business Question: How much revenue are we losing to stockouts
--                   during trend peaks?
-- Used in: Power BI → Lost Revenue Page

WITH stockout_weeks AS (
    SELECT
        i.sku_id,
        i.category,
        i.snapshot_date,
        i.stockout_flag,
        i.weeks_of_cover,
        p.brand,
        p.mrp
    FROM inventory i
    JOIN products p ON i.sku_id = p.sku_id
    WHERE i.stockout_flag = 1
),
avg_weekly_sales AS (
    SELECT
        sku_id,
        ROUND(AVG(quantity)::NUMERIC, 2)                AS avg_weekly_qty,
        ROUND(AVG(revenue)::NUMERIC, 2)                 AS avg_weekly_revenue
    FROM (
        SELECT
            sku_id,
            DATE_TRUNC('week', sale_date)               AS week,
            SUM(quantity)                               AS quantity,
            SUM(revenue)                                AS revenue
        FROM sales_transactions
        GROUP BY sku_id, DATE_TRUNC('week', sale_date)
    ) weekly
    GROUP BY sku_id
)
SELECT
    sw.brand,
    sw.category,
    COUNT(*)                                            AS stockout_weeks,
    ROUND(AVG(aws.avg_weekly_qty)::NUMERIC, 2)          AS avg_weekly_units,
    ROUND(SUM(aws.avg_weekly_revenue)::NUMERIC, 2)      AS estimated_lost_revenue,
    ROUND(AVG(sw.mrp)::NUMERIC, 2)                      AS avg_mrp
FROM stockout_weeks sw
JOIN avg_weekly_sales aws ON sw.sku_id = aws.sku_id
GROUP BY sw.brand, sw.category
ORDER BY estimated_lost_revenue DESC;


-- ── QUERY 15: Executive KPI Summary ──────────────────────────
-- Business Question: What are the top-line numbers?
-- Used in: Power BI → Executive Dashboard (KPI Cards)

SELECT
    -- Revenue
    ROUND(SUM(revenue)::NUMERIC, 2)                     AS total_revenue,
    ROUND(SUM(gross_profit)::NUMERIC, 2)                AS total_gross_profit,
    ROUND(AVG(gross_margin_pct)::NUMERIC, 2)            AS avg_gross_margin_pct,

    -- Volume
    COUNT(*)                                            AS total_orders,
    SUM(quantity)                                       AS total_units_sold,
    ROUND(AVG(quantity)::NUMERIC, 2)                    AS avg_order_size,

    -- Pricing
    ROUND(AVG(mrp)::NUMERIC, 2)                         AS avg_mrp,
    ROUND(AVG(selling_price)::NUMERIC, 2)               AS avg_selling_price,
    ROUND(AVG(discount_pct)::NUMERIC, 2)                AS avg_discount_pct,

    -- Returns
    SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)      AS total_returns,
    ROUND(
        SUM(CASE WHEN is_returned=1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    )                                                   AS overall_return_rate_pct,

    -- Cities & Channels
    COUNT(DISTINCT city)                                AS cities_covered,
    COUNT(DISTINCT channel)                             AS channels_active,
    COUNT(DISTINCT sku_id)                              AS skus_with_sales

FROM sales_transactions;

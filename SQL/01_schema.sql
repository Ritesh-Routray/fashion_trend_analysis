-- ============================================================
-- FASHION TREND INVENTORY — DATABASE SCHEMA
-- ============================================================

-- 1. Products
CREATE TABLE IF NOT EXISTS products (
    sku_id              VARCHAR(10)     PRIMARY KEY,
    product_name        VARCHAR(100)    NOT NULL,
    category            VARCHAR(50)     NOT NULL,
    subcategory         VARCHAR(50)     NOT NULL,
    brand               VARCHAR(50)     NOT NULL,
    color               VARCHAR(30)     NOT NULL,
    segment             VARCHAR(20)     NOT NULL,
    mrp                 NUMERIC(10,2)   NOT NULL,
    cost_price          NUMERIC(10,2)   NOT NULL,
    gross_margin_pct    NUMERIC(5,2),
    launch_season       VARCHAR(20),
    is_active           SMALLINT        DEFAULT 1
);

-- 2. Trend Signals
CREATE TABLE IF NOT EXISTS trend_signals (
    trend_id            VARCHAR(10)     NOT NULL,
    trend_name          VARCHAR(100)    NOT NULL,
    week_start_date     DATE            NOT NULL,
    week_number         INT             NOT NULL,
    year                INT             NOT NULL,
    month               INT             NOT NULL,
    trend_score         NUMERIC(6,4)    NOT NULL,
    search_volume_idx   INT,
    social_mentions     INT,
    trend_phase         VARCHAR(20),
    peak_week           INT,
    decay_speed         VARCHAR(10),
    relevant_categories TEXT,
    max_score           NUMERIC(4,2),
    PRIMARY KEY (trend_id, week_number)
);

-- 3. Inventory
CREATE TABLE IF NOT EXISTS inventory (
    inventory_id        VARCHAR(12)     PRIMARY KEY,
    sku_id              VARCHAR(10)     REFERENCES products(sku_id),
    brand               VARCHAR(50),
    category            VARCHAR(50),
    snapshot_date       DATE            NOT NULL,
    week_number         INT             NOT NULL,
    opening_stock       INT,
    units_sold          INT,
    units_received      INT,
    closing_stock       INT,
    reorder_point       INT,
    lead_time_days      INT,
    stockout_flag       SMALLINT        DEFAULT 0,
    weeks_of_cover      NUMERIC(6,1),
    inventory_health    VARCHAR(20),
    inventory_value     NUMERIC(12,2)
);

-- 4. Sales Transactions
CREATE TABLE IF NOT EXISTS sales_transactions (
    sale_id             VARCHAR(12)     PRIMARY KEY,
    sku_id              VARCHAR(10)     REFERENCES products(sku_id),
    brand               VARCHAR(50),
    category            VARCHAR(50),
    subcategory         VARCHAR(50),
    sale_date           DATE            NOT NULL,
    month               INT,
    year                INT,
    season              VARCHAR(20),
    city                VARCHAR(50),
    region              VARCHAR(20),
    city_tier           INT,
    channel             VARCHAR(30),
    quantity            INT,
    mrp                 NUMERIC(10,2),
    discount_pct        NUMERIC(5,2),
    selling_price       NUMERIC(10,2),
    revenue             NUMERIC(12,2),
    cogs                NUMERIC(12,2),
    gross_profit        NUMERIC(12,2),
    gross_margin_pct    NUMERIC(5,2),
    is_returned         SMALLINT        DEFAULT 0,
    trend_sensitivity   NUMERIC(4,2)
);

-- 5. Purchase Orders
CREATE TABLE IF NOT EXISTS purchase_orders (
    po_id               VARCHAR(10)     PRIMARY KEY,
    sku_id              VARCHAR(10)     REFERENCES products(sku_id),
    brand               VARCHAR(50),
    category            VARCHAR(50),
    supplier            VARCHAR(100),
    po_date             DATE,
    expected_delivery   DATE,
    actual_delivery     DATE,
    lead_time_days      INT,
    delay_days          INT,
    is_delayed          SMALLINT        DEFAULT 0,
    qty_ordered         INT,
    qty_received        INT,
    fulfillment_rate    NUMERIC(5,2),
    unit_cost           NUMERIC(10,2),
    po_value            NUMERIC(12,2),
    po_status           VARCHAR(20)
);

-- 6. Social Signals
CREATE TABLE IF NOT EXISTS social_signals (
    signal_id           VARCHAR(12)     PRIMARY KEY,
    trend_id            VARCHAR(10)     NOT NULL,
    trend_name          VARCHAR(100),
    platform            VARCHAR(30),
    city_tier           INT,
    week_start_date     DATE,
    week_number         INT,
    mentions            INT,
    hashtag_reach       INT,
    saves               INT,
    shares              INT,
    engagement_rate     NUMERIC(8,4),
    trend_score         NUMERIC(6,4),
    is_peak_week        SMALLINT        DEFAULT 0
);

-- 7. Trend SKU Mapping
CREATE TABLE IF NOT EXISTS trend_sku_mapping (
    mapping_id          VARCHAR(10)     PRIMARY KEY,
    trend_id            VARCHAR(10)     NOT NULL,
    trend_name          VARCHAR(100),
    sku_id              VARCHAR(10)     REFERENCES products(sku_id),
    brand               VARCHAR(50),
    category            VARCHAR(50),
    subcategory         VARCHAR(50),
    relevance_score     NUMERIC(4,2),
    is_hero_sku         SMALLINT        DEFAULT 0
);

-- ── Indexes for query performance ────────────────────────────
CREATE INDEX idx_inventory_sku      ON inventory(sku_id);
CREATE INDEX idx_inventory_date     ON inventory(snapshot_date);
CREATE INDEX idx_sales_date         ON sales_transactions(sale_date);
CREATE INDEX idx_sales_sku          ON sales_transactions(sku_id);
CREATE INDEX idx_sales_brand        ON sales_transactions(brand);
CREATE INDEX idx_sales_channel      ON sales_transactions(channel);
CREATE INDEX idx_trend_name         ON trend_signals(trend_name);
CREATE INDEX idx_trend_phase        ON trend_signals(trend_phase);
CREATE INDEX idx_social_platform    ON social_signals(platform);
CREATE INDEX idx_po_status          ON purchase_orders(po_status);

SELECT 'Schema created successfully ✅' AS status;


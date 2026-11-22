# Fashion Trend-to-Inventory Alignment System

**End-to-end analytics project for Indian fashion retail & D2C**
Python · PostgreSQL · SQL · Machine Learning · Power BI

---

## Business Problem

Indian fashion D2C brands and marketplaces lose an estimated 18–25% of potential
seasonal revenue because trend demand and physical inventory are out of step.
Buying teams place purchase orders 45–90 days before a trend peaks, usually on
intuition. By the time a trend is visibly popular, stock is either missing
(stockout) or already committed to a dying trend (dead stock).

This project builds a system that:

- Maps social trend signals against inventory position at SKU level
- Calculates the buying window before a trend peaks
- Raises early warnings before gaps turn into lost revenue
- Predicts stockout probability and dead-stock risk per SKU

---

## Tech Stack

| Layer | Tools |
|---|---|
| Data generation | Python (pandas, NumPy, Faker) |
| Database | PostgreSQL 17 |
| Analysis | Jupyter, SQL |
| Machine learning | scikit-learn, XGBoost |
| Visualization | Power BI |

---

## Dataset

Synthetic, modelled on Indian fashion retail patterns (10 brands, 6 categories, 18 cities, 6 channels).

| Table | Rows | Description |
|---|---|---|
| products | 1,170 | Master SKU catalog |
| trend_signals | 2,080 | Weekly scores for 20 trends over 2 years |
| inventory | 122,850 | Weekly stock snapshots per SKU |
| sales_transactions | 120,000 | Individual sale records |
| purchase_orders | 8,000 | PO history with supplier delays |
| social_signals | 37,440 | Platform-wise trend mentions (Instagram, Pinterest, etc.) |
| trend_sku_mapping | 1,200 | Trend → SKU relevance bridge |
| **Total** | **292,740** | |

---

## Pipeline

```
1. Data generation      Python → 7 CSV tables
2. PostgreSQL           schema, load, 15 analysis queries
3. EDA                  9 plots + business insights
4. ML models            stockout, trend decay, dead stock, buying opportunity
5. Power BI             8-page executive dashboard
```

---

## Machine Learning Models

| # | Model | Algorithm | Target | Key metric |
|---|---|---|---|---|
| 1 | Stockout risk | Random Forest | Will the SKU stock out? | AUC 1.00 (CV 0.999) |
| 2 | Trend decay | Gradient Boosting Regressor | Next-week trend score | R² 0.992, MAE 0.022 |
| 3 | Dead-stock risk | XGBoost | Will the SKU become dead stock? | AUC 1.00 (CV 0.999) |
| 4 | Buying opportunity | XGBoost | Is this a high-opportunity buying window? | AUC 0.9999 |

> **Caveat:** the near-perfect scores come from the synthetic data, whose
> patterns are largely deterministic. They show that the pipeline works
> end to end, not that the models would score this high on real data, where
> an AUC of roughly 0.78–0.88 would be a realistic expectation.

---

## Key Findings

- **₹30.4 Cr** revenue over 2 years across 18 cities and 6 channels
- **49.7%** gross margin, offset by a **19.4%** return rate
- **348 SKUs (29.7%)** flagged as dead-stock risk; **148** are in a dying trend with high inventory cover
- **H&M India and Urbanic** lead on revenue; **Zudio** leads on volume
- **D2C Website and Myntra** are the top channels; **Meesho** has the highest return rate
- **Mumbai, Delhi, Bangalore** drive over 40% of revenue
- **Festive** is the strongest season; **Monsoon** has the lowest return rate
- Average supplier lead time is **60 days**, which bounds how late a buy can be placed
- **Instagram** is the strongest early-signal platform

---

## Dashboard (Power BI, 8 pages)

| Page | Focus |
|---|---|
| 1. Executive Summary | Top-line KPIs, weekly revenue, brand revenue |
| 2. Trend Intelligence | Lifecycle curves, phase distribution, social signals |
| 3. Inventory Gap Analysis | Gap scores, action flags, danger-zone scatter |
| 4. ML Risk Scores | Dead-stock and stockout risk, SKU status matrix |
| 5. Brand & Channel | Revenue by brand and segment, margin heatmap, channels |
| 6. Geographic Intelligence | City revenue, trend sensitivity, regions |
| 7. Supplier & Supply Chain | Delay rates, lead times, supplier grades, PO timeline |
| 8. Seasonal Intelligence | Season revenue, category heatmap, returns by season |

![Executive Summary](<Dashboard Screenshots/Page 1 - Executive Summary.png>)
![Inventory Gap Analysis](<Dashboard Screenshots/Page 3 - Inventory Gap Analysis.png>)

Screenshots of all 8 pages are in [`Dashboard Screenshots/`](Dashboard%20Screenshots).

---

## SQL Analysis (15 queries in `SQL/03_analysis.sql`)

| Query | Business question |
|---|---|
| Q1 | Trend phase distribution |
| Q2 | Top 10 rising trends right now |
| Q3 | Trend-to-inventory gap analysis (core query) |
| Q4 | Dead-stock early warning |
| Q5 | Buying window calculator |
| Q6 | Brand-wise revenue and margin |
| Q7 | Channel performance |
| Q8 | Geographic trend sensitivity |
| Q9 | Seasonal inventory vs sales alignment |
| Q10 | Supplier lead time and delays |
| Q11 | Social signal momentum by platform |
| Q12 | Category trend alignment score |
| Q13 | Weekly revenue time series |
| Q14 | Stockout impact |
| Q15 | Executive KPI summary |

---

## Repository Structure

```
fashion_trend_analysis/
├── Notebooks/
│   ├── 01_data_generation.ipynb
│   ├── 02_data_loading_to_postgres.ipynb
│   ├── 03_eda.ipynb
│   ├── 04_ml_models.ipynb
│   └── 05_powerbi_prep.ipynb
├── SQL/
│   ├── 01_schema.sql
│   ├── 02_verify_load.sql
│   └── 03_analysis.sql
├── Sample Data/
│   ├── Raw/                  7 generated CSV tables
│   └── Processed/            Power BI exports and ML scores
├── EDA Plots, ML Plots, Models/
│   ├── EDA Plots/            9 plots
│   ├── ML Plots/             4 plots
│   └── Models/               trained .pkl files
├── Dashboard/                Fashion Trend Inventory.pbix
├── Dashboard Screenshots/    one image per dashboard page
├── requirements.txt
└── README.md
```

---

## How to Run

```bash
git clone https://github.com/Ritesh-Routray/fashion_trend_analysis.git
cd fashion_trend_analysis
pip install -r requirements.txt
```

1. **Generate data:** run `Notebooks/01_data_generation.ipynb` (or use the CSVs in `Sample Data/Raw/`).
2. **Create the database:** create `fashion_trend_db` in PostgreSQL, then run `SQL/01_schema.sql`.
3. **Set your database password** as an environment variable (the notebooks read it, nothing is hardcoded):
   ```powershell
   $env:DB_PASSWORD = "your-password"
   ```
4. **Load data:** run `Notebooks/02_data_loading_to_postgres.ipynb`, then check with `SQL/02_verify_load.sql`.
5. **Analyse:** run notebooks `03_eda`, `04_ml_models`, `05_powerbi_prep` in order.
6. **Dashboard:** open `Dashboard/Fashion Trend Inventory.pbix` in Power BI Desktop.

---

## Who This Is Relevant To

- **D2C brands:** Bewakoof, Snitch, The Souled Store, Urbanic, FabAlley
- **Marketplaces:** Myntra, Ajio, Meesho, Amazon Fashion
- **Fast fashion:** Zudio, H&M India, Styli, Virgio

---

## Author

**Ritesh Routray**
[GitHub](https://github.com/Ritesh-Routray)

Released under the [MIT License](LICENSE).

# E-Commerce Customer Segmentation & RFM Analysis
### Olist Brazilian E-Commerce | Python · MySQL · Pandas · Seaborn · Plotly

---

## Business Problem

Olist is a Brazilian e-commerce marketplace connecting small sellers to customers across 27 states. Despite processing **99,441 orders** over 2 years, the platform faced a critical retention crisis: **96.5% of customers made only one purchase and never returned.**

Without knowing *who* their valuable customers were, Olist could not:
- Build cost-effective retention or loyalty strategies
- Decide which customers deserve investment
- Personalise product recommendations by customer type
- Justify where to focus marketing spend

**This project segments all 96,096 unique customers using RFM methodology, cross-analyses those segments across product categories, geography, and payment behaviour, and delivers 5 specific business recommendations — each with a quantified projected ROI.**

---

## What Makes This Analysis Different

Most RFM projects compute scores and draw a bar chart. This project goes 4 layers deeper:

| Layer | Analysis | Business Value |
|-------|----------|---------------|
| **Layer 1** | Standard RFM scoring (R, F, M scores 1–5) | Who are our customers? |
| **Layer 2** | RFM × Product Category | What does each segment buy? |
| **Layer 3** | RFM × Geography (27 Brazilian states) | Where are high-value customers? |
| **Layer 4** | RFM × Payment Behaviour | How do segments pay differently? |
| **Bonus** | Cohort Retention Matrix (2017 cohorts) | When do customers stop returning? |

---

## Key Findings

### 1. The Retention Crisis is Real
- **96.5% of 96,096 customers placed exactly one order**
- Only 2,997 customers ever made a second purchase
- The platform runs almost entirely on new customer acquisition — an expensive and unsustainable growth model

### 2. Segment Revenue Distribution
| Segment | Customers | % of Customers | Revenue | % of Revenue |
|---------|-----------|---------------|---------|-------------|
| New Customers | 36,345 | 38.9% | R$5,975,014 | 38.7% |
| Hibernating | 26,873 | 28.8% | R$5,974,183 | 38.7% |
| Promising | 6,932 | 7.4% | R$1,935,638 | 12.6% |
| Potential Loyalists | 11,505 | 12.3% | R$836,247 | 5.4% |
| About To Sleep | 7,482 | 8.0% | R$419,567 | 2.7% |
| Lost | 3,874 | 4.1% | R$153,857 | 1.0% |
| Loyal Customers | 126 | 0.1% | R$57,623 | 0.4% |
| At Risk | 65 | 0.1% | R$28,635 | 0.2% |
| **Champions** | **33** | **0.04%** | **R$28,595** | **0.2%** |

### 3. The Promising Segment Has a Satisfaction Problem
The Promising segment (recent buyers, single purchase) shows the **highest 1-star review rate at 15.9%** and the **lowest average review score at 3.88**. This directly explains why they don't return — a bad first experience prevents repeat purchase. This is the most actionable insight in the dataset.

### 4. SP State: Scale Without Efficiency
- SP has 41.9% of all customers but only 37.4% of revenue
- SP average spend (R$147.43) is **below** the national average (R$165.20)
- SP has 36.4% of all 33 Champions (12 out of 33)
- SP already has better delivery than national average (4.5% late vs 6.8% nationally)
- The SP opportunity is **engagement and spend uplift**, not logistics

### 5. Cohort Retention Collapses After Month 1
Average month-1 retention across 2017 cohorts is below 5%. Customers who return within 30 days of their first purchase are 3× more likely to become loyal customers. The 30-day window is the most critical re-engagement period.

---

## Business Recommendations & Projected ROI

All assumptions stated explicitly. Win-back rates based on industry benchmarks.

| Priority | Recommendation | Customers | Campaign Cost | Revenue Uplift | ROI |
|----------|---------------|-----------|--------------|---------------|-----|
| 1 | New Customer 3-email onboarding | 36,345 | R$181,725 | R$268,789 | **48%** |
| 2 | Promising segment category nudge | 6,932 | R$55,456 | R$232,042 | **318%** |
| 3 | Hibernating reactivation email | 26,873 | R$403,095 | R$429,973 | **7%** |
| 4 | At-Risk + Can't Lose win-back | 66 | R$2,310 | R$4,881 | **111%** |
| 5 | Champions VIP loyalty programme | 33 | R$3,135 | R$3,139 | **0% (churn protection)** |
| **Total** | **All campaigns** | **70,249** | **R$645,721** | **R$938,824** | **45%** |

**Key assumption**: Email campaign costs are near-zero marginal cost. Win-back rates (8–20%) are standard industry benchmarks for their respective segment types. Actual ROI should be tracked post-execution and the model updated.

## Dataset

**Source:** [Olist Brazilian E-Commerce Public Dataset — Kaggle]()

| File | Rows | Description |
|------|------|-------------|
| olist_orders_dataset.csv | 99,441 | Order status and timestamps |
| olist_order_items_dataset.csv | 112,650 | Product-level pricing and freight |
| olist_order_payments_dataset.csv | 103,886 | Payment methods and installments |
| olist_customers_dataset.csv | 99,441 | Customer geography |
| olist_order_reviews_dataset.csv | 99,224 | Review scores and comments |
| olist_products_dataset.csv | 32,951 | Product details and categories |
| olist_sellers_dataset.csv | 3,095 | Seller geography |
| product_category_name_translation.csv | 71 | Portuguese → English category names |

**Critical data note:** The dataset contains two customer ID columns. `customer_id` changes with every order (session-level). `customer_unique_id` stays constant per person. All RFM analysis uses `customer_unique_id`. 

---

## How to Run

### Step 1: Install dependencies
```bash
pip install pandas numpy matplotlib seaborn plotly scipy sqlalchemy pymysql
```

### Step 2: Download the dataset
Download all 8 CSV files from Kaggle and place them in the `data/` folder.

### Step 3: Set up MySQL (for SQL analysis)
```sql
-- Run in MySQL Workbench
CREATE DATABASE IF NOT EXISTS olist_db;
```

### Step 4: Update config in the notebook
In `Phase_7_MySQL_Upload`, update:
```python
MYSQL_PASSWORD = "your_actual_password"
```

### Step 5: Run notebooks in order
```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 9
```

Phase 3 saves two master CSV files. All phases after Phase 3 load from those CSVs — you do not need to re-run Phase 3 every time.

---

## Technical Stack

| Tool | Purpose |
|------|---------|
| Python / Pandas | Data cleaning, feature engineering, RFM computation |
| NumPy | Numerical operations, percentile calculations |
| SciPy | Statistical testing (Mann-Whitney U test) |
| Seaborn / Matplotlib | All static charts |
| MySQL / SQLAlchemy | SQL analysis layer, data persistence |

### SQL Techniques Demonstrated
- `LAG()` — month-over-month revenue growth
- `RANK()` and `PERCENT_RANK()` — customer value ranking
- `CASE WHEN` — F-score scoring 
- Multi-CTE structure — cohort retention in pure SQL
- `CROSS JOIN` — grand total calculation for revenue percentages
- `TIMESTAMPDIFF()` — cohort index calculation in MySQL

---

## Analytical Decisions Documented

Every cleaning and modelling decision is documented with a business reason inside the notebook. Key decisions:

| Decision | Reason |
|----------|--------|
| Keep only 'delivered' orders | Cancelled/processing orders did not generate real revenue |
| Use `customer_unique_id` not `customer_id` | `customer_id` changes per order — using it makes every purchase look like a new customer |
| Manual F-score buckets (not NTILE) | 96.5% of customers have frequency=1. NTILE would incorrectly assign F=4 to one-time buyers |
| Reference date = Oct 18, 2018 | Last order is Oct 17. Using Oct 17 gives recency=0 for that customer, breaking scoring |
| Fill missing categories with 'uncategorized' | Dropping them would lose their revenue from analysis |
| Delivery hypothesis revised | Data showed 93.2% of orders arrive early — delivery is a strength, not a churn driver |

---

## Author

**[Apoorv Vimal]**
- LinkedIn: [https://www.linkedin.com/in/apoorv-vimal-analytics/]
- Email: [vimalapoorv08@gmail.com]


# Distribution Hub Optimizer

**Where should a company open its next 2 regional distribution hubs in India?**

## Overview

A company expanding its distribution network needs to pick locations where goods movement is growing, the local economy supports it, and demand is stable. This project uses India's GST E-Way Bill data, state GSDP and state population to forecast goods movement for each state, check whether it is growing faster than the economy, group states by risk and growth, and shortlist the 2 best states for new hubs.

## Business Problem

> Where should a company open its next 2 regional distribution hubs in India to capture higher growth and minimal logistics risk?

### Sub-Problems

| # | Question | Technique |
|---|----------|-----------|
| 1 | What is the estimated goods volume and amount for the next 2 years in each state? | Time Series Forecasting |
| 2 | Is goods movement per person growing faster or slower than the state's economy? | Classification |
| 3 | Which states share similar growth, size and risk profiles? | Clustering |

## Data

| Dataset | Description |
|---------|-------------|
| GST E-Way Bill | Monthly bill counts and goods value (intra-state, inter-state out and inter-state in) for 35 states and UTs, Apr 2019 to Mar 2026 (2,940 state-month rows) |
| State GSDP | Gross State Domestic Product by fiscal year |
| State population | Yearly population by state |

## Tools

Python (Pandas, NumPy, StatsForecast, scikit-learn, Statsmodels, Matplotlib, Seaborn) and MySQL.

## Methodology

**1. Data preparation (MySQL)**
- Standardised state names across the three datasets (for example Orissa to Odisha) and merged Daman & Diu with Dadra & Nagar Haveli.
- Dropped the "other territory" and "India" rows, and mapped Ladakh into Jammu & Kashmir.
- Converted months into fiscal years (April to March) so the E-Way Bill data lines up with GSDP.
- Kept only complete fiscal years and added 3-month and 12-month rolling averages.
- Created one clean SQL view per question: forecasting data, gain classification and cluster data.

**2. Forecasting (Python)**
- Anomaly check on month-to-month changes found problem values in Lakshadweep.
- Compared 6 models (Naive, Seasonal Naive, ARIMA, SARIMA, AutoTheta, AutoETS) using rolling cross-validation: 5 windows, 12-month horizon.
- Held out the final 12 months (Apr 2025 to Mar 2026) and trained on the rest.
- Forecasted 24 months ahead for volume and amount, and measured growth as next 12 months against last 12 months.

**3. Classification and clustering (Python)**: described below.

## Analysis and Results

### 1. Forecasting goods movement (Time Series Forecasting)
- SARIMA had the lowest error for both measures in cross-validation.
- The ranking held across most windows, so it was not a one-window result.

| Model | Mean MAPE: amount | Mean MAPE: volume |
|-------|-------------------|-------------------|
| SARIMA | 8.09% | 8.43% |
| AutoETS | 8.64% | 9.33% |
| Naive | 11.01% | 10.29% |

- Fastest forecasted amount growth: Arunachal Pradesh (32.5%), Andaman & Nicobar (31.9%) and Odisha (26.1%).
- Fastest forecasted volume growth: Goa (26.6%), Jharkhand (19.5%) and Assam (18.4%).

### 2. Goods growth vs. economic growth (Classification)
- Compared each state's per capita goods amount gain with its GSDP gain from 2019-20 to 2023-24.
- Gap = per capita gain minus GSDP gain. States within ±10 points are "In Line", and gaps beyond ±30 points count as "Strong".
- Result: 13 Strong Outperformers, 11 Outperformers, 8 In Line, 1 Underperformer (Mizoram), and none declining.

| Class | States | Avg per capita gain | Avg GSDP gain |
|-------|--------|---------------------|---------------|
| Strong Outperformer | 13 | 88.6% | 47.0% |
| Outperformer | 11 | 66.3% | 45.2% |
| In Line | 8 | 45.9% | 46.3% |
| Underperformer | 1 | 15.1% | 33.2% |

- Biggest gaps: Arunachal Pradesh (+74.9 points), Tripura (+50.2) and Chhattisgarh (+48.5).

### 3. Grouping states by risk and growth (Clustering)
- Clustered 33 states with KMeans on four scaled features: forecast growth, per capita amount (log), GSDP growth and volatility of monthly goods amount.
- k = 3 was chosen using the elbow method and silhouette score (0.357).

| Cluster | States | Avg forecast growth | Avg volatility |
|---------|--------|---------------------|----------------|
| Low Volatility (ranked best) | 23 | 11.8% | 10.4% |
| High Forecast Growth, Low Per Capita | 5 | 25.7% | 17.2% |
| High Volatility, High Per Capita | 5 | 14.9% | 35.8% |

- The high volatility cluster includes Gujarat, Maharashtra, Tamil Nadu, Kerala and Puducherry.

### 4. Picking the 2 hubs
- Shortlisted states in the low volatility cluster that rank in the top 10 for both forecasted volume growth and forecasted amount growth.
- Only two states passed: **Chhattisgarh** and **Andhra Pradesh**.

| State | Volume growth | Amount growth | Growth vs. GSDP | Cluster |
|-------|---------------|---------------|-----------------|---------|
| Chhattisgarh | 16.9% | 18.9% | Strong Outperformer (95% vs 47%) | Low Volatility |
| Andhra Pradesh | 16.0% | 16.5% | Outperformer (gap of about 15 points) | Low Volatility |

## Key Findings

1. **Chhattisgarh and Andhra Pradesh are the best hub locations.** Both are in the top 10 for forecasted volume and amount growth and sit in the low-volatility cluster.
2. **Chhattisgarh is the strongest pick.** Per capita goods grew 95% against GSDP growth of 47%, so goods movement is outpacing its economy.
3. **The fastest-growing states are not the safest.** Arunachal Pradesh, Odisha and Andaman & Nicobar forecast higher growth, but they fall in the high growth, low per capita cluster, where volatility is higher (17.2% against 10.4%).
4. **Large industrial states carry the most risk.** Gujarat, Maharashtra and Tamil Nadu have high per capita goods movement but volatility of about 36%.

## Note

This project analyses historical data for educational and portfolio purposes. The 2-hub shortlist is a rule-based pick from the forecasts and clusters, and does not include land, labour or transport costs.

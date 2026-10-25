# Findings and Recommendations

Analysis of the Online Retail II dataset (Dec 2009 to Dec 2011). All figures come from the cleaned data (779,425 transaction lines, 5,878 identified customers, **£13.16M** total revenue) and match the Power BI dashboard.

---

## Executive summary

1. **Revenue is concentrated in a small group of customers.** The top 20% of customers generate 72.9% of revenue, and Champions alone (9.7% of customers) generate 49.7%.
2. **Repeat buyers are the business.** 72.4% of customers have ordered more than once, and they produce 96.4% of revenue (£12.69M of £13.16M).
3. **A large share of customers has gone quiet.** 50.9% have not purchased in the last 90 days, and 40.8% have not purchased in 180 days.
4. **The first month is the leak.** Only about 20% of a new cohort buys again the month after their first purchase.
5. **Sales are seasonal.** September to November drives the year, with November the peak in both years.

---

## Findings

### 1. Business overview

| Metric | Value |
|---|---|
| Total revenue | £13.16M |
| Identified customers | 5,878 |
| UK share of revenue | 84.4% |
| Average customer value (historical) | £2,238 |

- The **United Kingdom** is 84% of revenue. The next largest markets are EIRE (£421K), Germany (£379K), France (£283K) and the Netherlands (£251K).
- Revenue peaks every **November**: £931K in 2010 and £945K in 2011, after a ramp-up from September.
- Top products by revenue: Regency Cakestand 3 Tier (£224K), White Hanging Heart T-Light Holder (£169K), Party Bunting (£85K).

### 2. Customer segmentation

| Segment | Customers | % of customers | Revenue | % of revenue | Avg value per customer |
|---|---|---|---|---|---|
| Champions | 571 | 9.7% | £6.54M | 49.7% | ~£11,460 |
| Loyal | 763 | 13.0% | £2.71M | 20.6% | ~£3,550 |
| At Risk | 1,330 | 22.6% | £2.08M | 15.8% | ~£1,560 |
| Other | 1,555 | 26.5% | £1.23M | 9.4% | ~£790 |
| Hibernating | 1,659 | 28.2% | £0.59M | 4.5% | ~£360 |

- **Champions and Loyal together are 22.7% of customers but 70.3% of revenue.**
- **Hibernating is the largest group by headcount (28%) but the smallest by revenue (4.5%).** Customer count and customer value are very different things.
- **At Risk holds £2.08M**, the biggest pool of recoverable revenue.

### 3. Retention and churn

- **Churn (no purchase in 90+ days): 50.9%.** At 180+ days: 40.8%.
- **Month-1 return rate: about 20%.** Roughly one in five new customers buys again the following month.
- The **December 2009 cohort retained best** (about 35% in month 1, and still around 38% in month 12), and most later cohorts sit between 15% and 30% in the first months.
- Retention curves fall quickly in the first few months and then flatten, so the early period is where customers are won or lost.

### 4. Customer value

| | Customers | Revenue | Avg order value |
|---|---|---|---|
| Repeat | 4,255 (72.4%) | £12.69M (96.4%) | ~£320 |
| One-time | 1,623 (27.6%) | £0.47M (3.6%) | ~£289 |

- Repeat customers also place slightly larger orders on average.
- The first revenue decile (top 10% of customers) alone brings in about £7.5M, over half of all revenue.

---

## Recommendations

### Protect: Champions and Loyal (1,334 customers, 70% of revenue)
- Create a loyalty or early-access programme. Losing even a small share of this group costs more than losing any other segment.
- Track their recency monthly. A Champion who passes 60 to 90 days without buying should trigger an alert before they become At Risk.

### Win back: At Risk (1,330 customers, £2.08M)
- Run a targeted win-back offer. Start with the **top 15 At Risk customers by spend** (the table on the Action Plan page) and contact them personally.
- Measure the campaign by reactivation rate and recovered revenue, so the next round can be sized properly.

### Convert: one-time buyers (1,623 customers)
- Send a **second-purchase offer within 30 days** of the first order. A month-1 return rate of 20% is the baseline to beat.
- A repeat customer has spent about £2,980 in total on average, versus about £289 for a one-time customer (roughly 10 times more), so even a small lift in conversion is valuable.

### Spend efficiently on Hibernating (1,659 customers, 4.5% of revenue)
- Use low-cost reactivation only, such as a single automated email. Heavy discounting here has the worst expected return.

### Plan around seasonality
- Build stock and campaigns for the **September to November** ramp, using the top products (cakestand, T-light holders, bunting) as the anchor lines.
- Treat January and February as the low point when planning cash flow.

### Reduce geographic concentration
- With 84% of revenue from the UK, growth in EIRE, Germany, France and the Netherlands is the most direct route to diversification. Test targeted campaigns there before investing heavily.

### Improve data capture
- 22.8% of transaction lines had no customer ID and could not be analysed at customer level. Encouraging account creation or email capture at checkout would make every future retention analysis more complete.

---

## Limitations

- **Identified customers only.** The 22.8% of lines without a `CustomerID` are excluded, so customer-level figures understate total business activity.
- **Revenue is gross of cancellations.** Cancelled orders (18,744 lines) are stored separately and not subtracted.
- **Partial final month.** Data ends around 9 December 2011, so December 2011 and the latest cohorts look weaker than they are.
- **Rule-based segments.** Segment thresholds were chosen by judgment, not statistically, so moving them moves segment sizes. The "Other" group (26.5%) is a catch-all and could be split further.
- **Historical value, not predicted lifetime value.** "Average customer value" is what customers have spent so far. It does not forecast future spend.
- **Churn definition.** Churn here means no purchase in 90+ days. The right window depends on how often customers normally buy, and the business should confirm it.
- **Outliers were capped, not removed**, to preserve revenue totals. Extreme orders therefore still slightly influence the largest customers' figures.

## Suggested next steps

1. Rebuild segmentation with quintile (`NTILE`) RFM scores and compare against the rule-based segments.
2. Add a forward-looking lifetime value estimate.
3. Net cancellations against revenue to get a true net revenue figure.
4. Add an AI-generated summary layer on top of the aggregated KPIs, documenting exactly what the model sees and how its output is checked.
5. Run the win-back and second-purchase ideas as a measured experiment, then report the result.

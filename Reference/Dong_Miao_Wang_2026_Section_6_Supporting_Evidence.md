# 6 Supporting Evidence

> **Source:** Ding Dong, Jianjun Miao, and Pengfei Wang, *Rational Bubbles in Dividend-Paying Assets under Balanced Growth*, April 29, 2026. Section 6, printed pages 39–44 (PDF pages 40–45).
>
> **Zotero:** [Library item](zotero://select/library/items/BT8QQPV9) · [Open source PDF at Section 6](zotero://open-pdf/library/items/8UJDJV74?page=40).
>
> **Conversion:** Original wording, citations, numerical results, and numbering are retained. PDF line wrapping and line-end hyphenation are removed; mathematics, tables, and footnotes are formatted as Markdown/LaTeX. Tables are placed between paragraphs for continuous reading.

In this section, we present empirical evidence at the aggregate and disaggregate levels supporting the predictions and mechanisms of our theoretical framework. Across all three economies analyzed in this paper, asset bubbles relax credit constraints and stimulate R&D activity through the selection and reallocation channels. The testable implications arise most naturally from the transition dynamics of the Jones regime (Section 5.2), where bubble episodes generate temporary surges in R&D intensity and knowledge accumulation that permanently shift the economy to a higher level path. Specifically, along the transition path, the emergence of equity bubbles promotes labor reallocation to the R&D sector (i.e. $L_t^R/L_t$ increases), raises the productivity threshold $z^*$, and increases the creation of new products ($A_t$), which eventually boosts aggregate output.

## 6.1 Aggregate Evidence

Our empirical strategy assesses the model’s prediction that aggregate stock market bubbles positively correlate with R&D investment, reflecting the relaxation of borrowing constraints. The counterfactual exercise in Section 5.2 shows that a bubble episode raises detrended knowledge per capita by 3.2% and output per capita by 2.3% along the transition path, driven by higher R&D labor shares and TFP gains. We now ask whether the data bear out these qualitative patterns. We employ a time-series correlation analysis using quarterly data from 1970 to 2020, consistent with the model’s prediction of bubble-driven innovation surges along the transition path. This approach tests whether periods of elevated bubble activity coincide with heightened R&D intensity and output.

We utilize two measures of aggregate R&D from the Bureau of Economic Analysis (BEA): (i) the growth rate of real R&D investment, measured as the seasonally adjusted annual rate of percent change from the preceding period, and (ii) the contribution of R&D to the percent change in real GDP, expressed in percentage points at a seasonally adjusted annual rate. These proxies capture both the input and output scale of R&D sector and its direct impact on economic output, aligning with the model’s emphasis on $A_t$ growth driving $Y_t$.

To measure stock market bubbles, we adopt three complementary indices: (i) a naive measure based on the growth rate of S&P 500 price-to-dividend (P/D) ratio, reflecting excess valuations over fundamentals, (ii) an indicator variable of detected equity bubble in the S&P 500 index using the method of Phillips et al. (2015) (henceforth PSY),[^11] and (iii) the sentiment index constructed by Gao and Martin (2021), which integrates option prices, valuation ratios, and interest rates to capture market exuberance. These measures are positively related to equity bubbles and are used as their indicators.

According to Panel A of Table 4, the correlation coefficients between different measures of stock market bubble and aggregate R&D are all positive and significant, suggesting that periods with higher likelihood of stock bubbles are often associated with intensified R&D investment and output growth.

**Table 4: Stock Market Bubble and Aggregate R&D**

**Panel A: Full Sample**

| Measure of Bubbles | $\Delta P/D^{S\&P500}$ | S&P500 Bubble | Sentiment |
|:---|---:|---:|---:|
| R&D Growth | 0.21 | 0.13 | 0.17 |
| R&D Contribution | 0.19 | 0.12 | 0.12 |

**Panel B: Sub-sample with Positive ANFCI**

| Measure of Bubbles | $\Delta P/D^{S\&P500}$ | S&P500 Bubble | Sentiment |
|:---|---:|---:|---:|
| R&D Growth | 0.44 | 0.24 | 0.34 |
| R&D Contribution | 0.44 | 0.25 | 0.35 |

*Notes:* The series of R&D Growth is the seasonally adjusted annual rate of percent change in research and development investment from preceding period (FRED series Y006RL1Q225SBEA). The series of R&D Contribution is seasonally adjusted annual rate of the contribution to the percent change in real GDP from research and development investment (in percentage point, FRED series Y006RY2Q224SBEA). Positive values of adjusted national financial condition index (ANFCI) indicate financial conditions that are tighter than average. All series are at the quarterly frequency from 1970Q1 to 2020Q4.

To illustrate the role of financial constraint, we further sort historical periods by the tightness of the credit condition based on the Chicago Fed’s Adjusted National Financial Conditions Index (or ANFCI). The index provides comprehensive weekly update on the U.S. financial conditions in money markets, debt and equity markets and the traditional and the shadow banking systems, orthogonalized by the economic conditions. Positive values of the ANFCI indicate financial conditions that are tighter than average. According to Panel B, the positive correlations between measures of aggregate stock bubble and R&D investment are more pronounced during periods with tightened financial condition, which suggests a vital role of financial constraint as an amplification mechanism.

The relation between aggregate innovation and stock market bubble presented here echoes the evidence documented in Sorescu et al. (2018), who use a sample of 51 major innovations introduced between 1825 and 2000, and detect bubbles in 73% of the cases.[^12] Consistent with our mechanism, the authors also show that firms bearing stock market bubbles raise significantly more equity capital–often proportional to the magnitude of the bubble–compared to the average firm in the market, which accelerates and increases the diffusion of innovation. Our model’s prediction that elevated equity valuations relax credit constraints and stimulate innovation is further corroborated by cross-country evidence on stock market liberalization. Moshirian et al. (2021) show that opening markets to foreign investors boosts technological innovation by 10–15%, primarily through eased financial constraints and improved risk-sharing—channels akin to our equity bubbles’ collateral and selection effects. This effect is stronger in constrained environments and mediates productivity growth, aligning with our transitional TFP gains and level effects on output.

## 6.2 Firm-level Evidence

In this subsection, we further test the model’s implications using the firm-level balance sheet data from Compustat to examine how equity bubbles influence R&D activity among U.S. publicly traded firms.[^13] According to our model, the emergence of equity bubbles relaxes the credit constraint, allowing the firm to make more R&D investment. We first estimate the effects of equity bubble on firm R&D investment based on the regression

$$
\log(XRD_{j,t}) = \beta_0 + \beta_1 \cdot Bubble_{j,t} + \beta_2 \cdot \log(XRD_{j,t-1}) + \Phi_{j,t} + \gamma_j + \phi_t + \varepsilon_{j,t}
\tag{72}
$$

where $\log(XRD_{j,t})$ denotes firm $j$’s expenses on research and development in quarter $t$ (Compustat item xrd) in log. $Bubble_{j,t}$ is a dummy variable that equals one if a bubble is detected in the stock price of firm $j$ in year $t$ according to the PSY method, and equals zero otherwise.[^14] We control a set of firm-level time-varying characteristics including Tobin’s Q, cash ratio, and book leverage ratio (summarized by $\Phi_{j,t}$). In estimating equation (72), we also control the time fixed-effect ($\phi_t$) and firm fixed-effect ($\gamma_j$). The coefficient of interest $\beta_1$ captures the effect of equity bubble on firm R&D expenses.

The first column of Table 5 presents the OLS results. The results reveal a statistically significant positive coefficient on the dummy indicative of stock bubble, suggesting that firms with elevated valuations increase R&D spending. According to the estimate, the presence of a bubble in the stock price raises firm R&D investment by 4.1%. This is consistent with the model’s prediction that bubbles promote innovation.

**Table 5: Stock bubble, financial constraint and R&D investment**

| Variable | OLS: $\log(XRD_{jt})$ (1) | 2SLS: $FF_{jt}$ (2) | 2SLS: $\log(XRD_{jt})$ (3) |
|:---|---:|---:|---:|
| $Bubble_{jt}$ | 0.041\*\*\* | -0.0043\*\*\* | |
| | (0.015) | (0.0006) | |
| $\widehat{FF}_{jt}$ | | | -9.490\*\*\* |
| | | | (3.284) |
| $\log(XRD_{jt-1})$ | 0.793\*\*\* | -.004\*\*\* | 0.755\*\*\* |
| | (0.003) | (.0002) | (0.014) |
| $FF_{jt-1}$ | -2.418\*\*\* | 0.758\*\*\* | 4.778\* |
| | (0.078) | (0.005) | (2.494) |
| Constant | 0.181 | -0.061\*\*\* | -0.755\*\* |
| | (0.256) | (0.015) | (0.317) |
| Observations | 26,861 | 27,236 | 26,861 |
| R-squared | 0.840 | 0.786 | 0.850 |
| Firm Controls | Yes | Yes | Yes |
| Firm Fixed Effect | Yes | Yes | Yes |
| Time Fixed Effect | Yes | Yes | Yes |

*Notes:* This table reports the estimation results of the regression (72). The dependent variables in the OLS regression is the log of firm R&D expenditure ($\log(XRD_{jt})$) from Compustat. $Bubble_{jt}$ is a dummy variable indicative of bubbles detected in the stock price of firm j at period t using the PSY method. $FF_{jt}$ denotes the WW index measuring the tightness of firm-level credit constraints, and $\widehat{FF}_{jt}$ denotes the predicted firm-level financial constraint obtained from the first-stage regression (Column 2). Robust standard errors are in parentheses. \*\*\* $p < 0.01$, \*\* $p < 0.05$, \* $p < 0.1$.

To test the role of the financial constraint channel, we follow the mediation approach of Bertrand and Mullainathan (2001): rather than using bubbles as an instrument for financial constraints, this two-stage procedure decomposes the total effect of bubbles on R&D into a component operating through credit constraints. In the first-stage regression, we regress the firm-level financial constraint measure (WW index constructed by Whited and Wu (2006), higher value of which indicates tighter financial constraint) on the same set of explanatory variables used in the specification (72). This regression helps isolate the effects of bubble on a firm’s financial constraint. The coefficient on the dummy variable of bubble in Column (2) shows that stock price bubbles predict declines in the WW index, implying a loosening of credit constraints. The estimated effects are statistically significant at the 99% confidence level.

In the second-stage regression, we regress the measure of the firm R&D investment ($\log(XRD_{jt})$, on the predicted WW index (denoted by $\widehat{FF}_{jt}$) from the first stage regression. The coefficients on the predicted WW index capture the effects of bubble on firm R&D investment through the credit constraint channel. The estimated channeling effects are negative and statistically significant at the 99% level (see Columns 3). For example, the presence of a bubble in the stock price raises firm R&D investment by 4% according to the 2SLS estimates, consistent with the magnitude from the OLS regression. Taken together, the evidence indicates that stock price bubbles enhance firm innovation via the channel of relaxing credit constraints.

The results here based on input-based measures of firm-level R&D (e.g. R&D expenditures) echo the finding using outcome-based R&D measures. For example, Haddad et al. (2022) show that 1.4 more patents are issued within a U.S. Patent and Trademark Office technology class during a bubble, which translates into a 15% increases in patent issuance per class, indicating more innovation activity. In another related paper, Dong et al. (2021) find a strong association between stock overvaluation with various measures of firm-level innovation, not only by the R&D and innovative output (patent and citation counts), but also by innovative inventiveness (novelty, originality, and scope).

We note that our theoretical framework stylizes R&D production as labor-only, whereas Compustat R&D expenditures capture a broader input mix including capital goods and intangible assets. This, if anything, strengthens our test: by using total R&D spending, we capture the full resource commitment to innovation, which should respond to credit-easing channels even beyond the labor margin.

---

[^11]: The method of PSY (2015) detects bubbles by applying the Generalized Supremum Augmented Dickey-Fuller (GSADF) test to identify explosive behavior in time series of price-to-earning ratio (P/E ratio), using recursive regressions with window sizes of 10 years with annual data. Bubble periods are dated by comparing Backward SADF (BSADF) statistics against critical values of 2, marking a bubble when the statistic exceeds the threshold.

[^12]: Shiller (2015) provides a similar narrative, associating asset bubbles with nine major innovations including the phonograph, electricity, trains, the automobile, radio, electrification, motion pictures, TV, and the Internet.

[^13]: While our theoretical model distinguishes between R&D firms dedicated to innovation and manufacturing firms focused on production using invented blueprints, our baseline empirical analysis utilizes a comprehensive sample of all public firms. This reflects the reality that modern firms often integrate both R&D and production activities internally, rendering it challenging to differentiate pure R&D entities from manufacturers. For robustness, we restrict the sample to firms with above-median R&D expense intensity (defined as R&D expenses scaled by total assets), thereby focusing on entities more aligned with innovation-driven activities. The results remain consistent and, in some cases, exhibit stronger magnitudes; see Appendix E.

[^14]: Bubbles are detected in 2.7% of our sample covering U.S. listed firms from 1960 to 2022. The median price-to-earning (PE) ratio of stocks with bubbles detected is 97% higher than that of the firms without bubbles (21.5 vs. 10.9).

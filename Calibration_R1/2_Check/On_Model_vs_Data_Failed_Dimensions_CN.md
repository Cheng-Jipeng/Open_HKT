# Model vs data 记分卡：V6 two-country production model 匹配不上的 data dimensions

2026 年 10 月 26 日初稿，10 月 30 日修订（修订内容见第 6 节）。本文件是 [On_Model_vs_Data_Failed_Dimensions.md](On_Model_vs_Data_Failed_Dimensions.md) 的中文版，两者内容一致。以 figure 为主的 deck 见 [slides/model_vs_data_slides.pdf](slides/model_vs_data_slides.pdf)。

三类来源，均未被修改：

1. **Model 与 simulation。** `AI_drafting/V6_production.tex`（production block、free entry、funding identity、asymptotic HKT reduction）；zero-exponent solver 及 notebooks 02–06，位于 `Two_country_proudction_zero_nu_b/`（`outputs_zero_nu_b/`）。其中 AHP-seeded calibration 为 β=0.45、γ=0.25、ϑ_US=0.85、a_US=0.20、a_W=0.06、A_X,US,u=15、A_L,US,u=1.5、H_US=L_US=1、H_W=L_W=3、ξ_u=2.25、ν_u∈{0.75, 1.00, 1.25, 1.75}、ν_b=ξ_W=0、π=0.75（notebook 06 另外搜索 π、ω̄、ω̄*、η）。Notebook 06 把 one period 当作 episode index，并说明这只是 plotting convention，不是校准过的 model frequency；R1 与 mapping package 则采用 one period = one year。
2. **Pilot calibration。** `Calibration_R1/1_Do/runs/01_observed_labor`、`runs/02_fixed_mean_labor`、spillover diagnosis、`Calibration_R1/0_Plan`。
3. **Empirical data。** `Empirical_Data/Variable_mappings/Empirical_Mapping_Annual`（AHP corporate 与 external mappings、implied a 与 implied β diagnostics、overidentification checks）、`Empirical_Data/AHP_NFA`、`US_Equity_Positions`、`US_Debt_Positions`、mechanism-evidence package（US vs G4）、`Skill_Premium_and_RD_Share_2026-10-26`。

记号：Y = AHP total-corporate GVA；COMP = corporate compensation；Q = AHP enterprise value（EV，年末）；D = AHP free cash flow（FCF）；e = w_H H + w_L L；B_H、B_L = 用 CPS bridge 得到的 skilled、unskilled wage bill；I = (1−φ)H w_H，即 IPO transfer。比率无量纲；R1 panel 的 level 单位是 trillion 2017 USD，mapping package 的单位是 nominal USD。

---

## 1. 记分卡

| # | Dimension | Data（默认 US） | Model | Verdict | Structural source |
|---|---|---|---|---|---|
| 1 | Valuation scale：Q/Y、Q/COMP | Q/Y：1.29 (1990)、2.23 (2007)、1.94 (2009)、4.45 (2024)、4.66 (2025)。Q/COMP：2.0、3.7、3.3、7.9、8.3。Implied β=(Q+NFA)/e：2.0 (1990)、3.6 (2007)、4.7 (2022)、6.3 (2025)，36 年全部 >1 | 恒等式 Q+NFA=A=βe。ν_u sweeps：Q/e 从 0.41 (t=1) 降到 0.23–0.25 (T=80)。Notebook 06 最优点：约 0.8 降到 0.5 | **Fail**：2025 年 level 差 10 倍以上，trend 方向相反 | Two-period OLG：equity value 由当期 young cohort 的 saving 融资 |
| 2 | Non-labor income 与 markup | (Y−COMP)/Y：36% (1990) → 44% (2022–25)。FCF/Y：6.4% → 12.7%。CFC + taxes 占 25–27%，NCF 占 4–7%（2009 年为 −0.6%） | 无 capital，故 net cash flow D−I = Y−e，即全部 Y−COMP。P1 逐年 markup floor 为 2.35–2.81，共同 bound 为 2.81 (observed labor)、2.73 (mean labor)；若 1−φ≈7%，μ=2.34–3.02（因 premium series 而异）。Notebooks 用 ϑ=0.85 (μ=1.18)，D/Y=1.4% | **Fail**：model 的 net cash flow 占 GVA 44%，FCF 只占 12% | 没有 corporate capital |
| 3 | Dividend yield D/Q | 5.0% (1990)、3.6% (2007)、7.5% (2009)、3.4% (2022)、2.7% (2025)。Cash dividends/equity：7.8% → 2.7% | d/q = a(1−ϑ)/ϑ·φH = 0.20×0.176×0.98 = 3.45%/period (t=1)，随 φ 下降 | Level 靠 ϑ 的选择匹配，方向匹配 | 机制不对，见 row 4 |
| 4 | Q/D 上升的分解 | 2007→2025：Δlog(Q/D)=+0.29，其中 Δlog(Q/Y)=+0.74，Δlog(D/Y)=+0.45。1990→2025：+0.61，其中 +1.29、+0.68。2009→2024：+0.97，其中 +0.83、−0.14。D/Y 没有下降趋势（2005–25 在 7.5–15%，2023–25 为 12.5–12.7%）；各窗口都是 Q/Y 主导 | ν_u=1，t=1→80：Δlog(Q/e)=−0.59，Δlog(d/q)=−2.1；D/Y 从 1.39% 降到 0.08%。Explosive q/d 来自 dividend 塌缩 | **Fail：channel 错了** | φ→0 机制加上 funding cap |
| 5 | R&D share of skilled labor，1−φ | BERD researchers/H 3.4–3.8%；BERD personnel/H 4.9–5.7%；NSCG for-profit RD1 6.1–7.3%（2010 年 6.9%，2023 年 7.3%）；BERD labor cost/skilled bill 7.1–10.5%（因 premium 而异）。每十年约 +1–2pp。NRC occupational share 30.5% (1990) → 43.9% (2024)，分母是 total employment，不是 H | AHP-seed：1.8% (t=1)。ν_u=1.75：1.9% → 0.6% (T=30)，下降。ν_u=1.25/1.00/0.75：25%/88%/99% (T=80)。Notebook 06 最优点 28–30%。R1 conditional (μ=3.5)：22–30%，隐含 R&D workers 7.2–9.7 million，为 NSCG RD1 (1.4–2.2 million) 的 3.5–6 倍；research payroll 为 BERD labor cost 的 2–3 倍 | **Fail：level 与 trend 都不对** | φ-decay 机制；P1 把 Y−COMP 全部算作 profit |
| 6 | Free entry：q=w_H/(aN)，等价于 B_H/Q=a·H/G_N | B_H/Q：0.098 (1995)、0.101 (2007)、0.123 (2009)、0.077 (2019)、0.079 (2022)。Q/w_H 指数：1995=1，2022=2.86。Implied a：−54% 到 −62%；implied a·H：−19% 到 −22%；patent stock 口径为 −38%，它从 2001 年起算，带 initial-stock effect（1995–2007 均值 vs 2018–24 均值）。Free-entry residual 均值 +5–7%/年，累计约 +1.4 log（1995–2024）。R1 constant-a：Q RMSE 25–31%，2009–12 高估（−0.53 到 −0.20），2013–24 低估（+0.05 到 +0.37） | 恒等成立。AHP-seed：a·H=0.2，B_H/Q≈0.20 | **Fail in trend**；level 可以靠 a 调，见 2.5 节 | Entry cost 只含 skilled labor；总价格（fundamental + bubble）被钉在 entry cost 上 |
| 7 | Skill premium w_H/w_L | 1.8–2.5：CPS re-censored 1.87 → 1.78 (2009–24)；ACS annual 2.47 → 2.44；ACS hourly 2.09 → 2.17；BLS medians 持平于 1.82。Package series 在 2023–24 跳到 2.16 是 top-code artifact | w_H/w_L=0.088 (t=1)，0.040–0.050 (T=80)，switch 后 0.11。w_L/w_H=(A_X/A_L)φ²/ϑ（ρ=2，α=½，H=L） | **Fail：差 20 倍以上** | A_X/A_L=10 且 ρ=2 |
| 8 | Skilled wage-bill share 与 skill upgrading | B_H/COMP：29% (1994)、40% (2009)、50% (2022)；ACS annual premium 下 47–58% (2009–24)。BA+ employment share 19.5% (1994) → 36% (2024)。H/L：+134% (1994–2024)、+56% (2009–24)。COMP/Y 64% → 56% | 恒等式 w_H H/e = βζ·aH/G_N：8.1% (t=1)，3.8–4.8% (T=80)；ζ→1 时极限为 βaH/(1+aH)=7.5%。H、L 固定 | **Fail：level 与 trend 都不对** | Funding cap 加 free entry 钉住该 share；endowments 固定 |
| 9 | Technology ordering ξ_u > ν_u | ρ=2 的 relative-wage inversion：ξ−ν=−1.82 (observed labor)、−0.11 (mean labor)；八种 premium series 下分别为 −1.32 到 −1.86、−0.03 到 −0.13，从未为正。施加 ξ≥ν≥0 只得到 boundary ξ=ν | 要求 ξ_u > ν_u > ν_b = 0，ψ>0 | **所有 mapping 都 Fail** | ρ>1 与 ξ>ν 无法同时容纳上升的 X/L 和持平的 premium |
| 10 | Output growth | Real corporate GVA：2.4%/年 (1990–2025)、2.4%/年 (2008–23)、2.8%/年 (2009–24) | Notebook 06：Y_US 10.5%/period，16 期 ×4.5。ν_u sweeps：t≈16 时 0.7–0.9%/period，T=80 时 6–17%/period | **在 one period = one year 下 Fail**；把 period 拉长又不再对应 2008–23 窗口 | Y∝N^ν_u，ν_u=1.75，G_N≈1.06 |
| 11 | Equity price indices | AHP implied liability price ×2.22，asset price ×1.05 (2008Q1–2023Q3)；MSCI USA ×5.4 (2011–25)；S&P 500 ×4.7 (2007–25)；ACWI ex-US ×1.9 (2011–25)；OECD G4 local ×1.08 (2007–21)、×1.24 (2007–24) | Notebook 06 最优点：q_US ×1.29（log growth 只有 data 的 32%），q_W ×0.97（接近 1.05）。AHP baseline：q_US ×1.00，q_W ×0.52。Sweeps 到 T=80：q_US 从 1.09 降到 0.91/0.59/0.12；q_W 从 2.30 降到 0.06–0.16，约 −4% 到 −5%/period | **Fail**：US 明显低估；除搜索出的 q_W 外，长期方向相反 | q=Q/N_{t+1}，Q 受 cap 约束而 N 增长 |
| 12 | External positions 与 flows，2008Q1–2023Q3，/GVA | ΔNFA −1.02；net equity VA −0.67（liability −0.72，asset +0.05）；CA −0.52；equity liabilities 1.55；equity assets 1.17。NFA/GVA：−0.14 (2008Q1) → −1.06 (2023Q3) | −0.0016；−0.011（−0.011，−0.0005）；+0.0098；0.018；0.093。NFA/Y：−0.35 → −0.08 | **Fail**：scale 差 13–620 倍；CA 与 asset VA 符号相反；NFA/Y trend 相反。只有 liability share of gross VA 匹配（0.96 vs 0.93） | Positions ∝ βe；NFA level 基本不变而 Y ×4.5 |
| 13 | Foreign ownership of US equity | Equity liabilities/Y（AHP 口径，含 portfolio 与 FDI）：September 2026 release 为 0.76 (2007)、1.34 (2022)、1.94 (2025)，2025 年约占 EV 的 42%；notebook 06 使用的 June 2026 release 为 1.46 (2022)、2.27 (2025) | Liability exposure/Y：0.27 (t=1) → 0.018 (t=16)；position level ×0.30，Y ×4.5 | **Fail：trend 相反** | 同上 |
| 14 | RoW growth 与 research intensity | G4 NRC share +5.5pp (2011–24)，US +6.3pp。Researcher FTE per 100 employed：G4 0.40 → 0.66 (2011–24)，US 0.57 → 0.82 (2008–23)。R&D capital：G4 +34%，US +53% (2007–21) | ξ_W=0，RoW 无技术增长，Y_W 不增长。e_W 到 t=60 维持在 5.0–5.1；ν_u≤1 时 T=80 升到 8.1/15.5，这来自 RoW IPO transfer（φ_W 降到 0.12/0.04），不是产出增长。b regime 中两国 aggregate 零增长 | **Fail**：RoW 停滞；data 里没有 US-only 的研究转移 | Zero-exponent specialization |
| 15 | Regime switch | 没有可识别的 b-type event。2007→09：nominal GVA −4.8%（2010 年恢复），real GVA −7.3%（最迟 2012 年恢复）；EV 2007→08 −22%（2010 年恢复） | τ=16：e_US −39%，Q_US −21%，φ_US 降到 0.885；此后 aggregate 零增长，q_US −2.3%/period | 无法识别；幅度与永久性都不像已观察到的事件 | ν_b=0 且 Ā_b<Ā_u |
| 16 | Bubble share | 不可测 | t=1 的 finite-prefix upper bound：6×10⁻⁹ 到 8×10⁻⁷；ν_u=1 时 t=20 为 3×10⁻⁵。Total leakage 0.32/period（switch 0.29，dividend 0.035） | 校准后的 model 在 data 相关的早期没有可见 bubble | π=0.75 的 switch leakage |

**Model 能匹配的部分：** D/Q level（ϑ=0.85 与 a·H=0.2 的结果）和 US yield 下降的方向；notebook 06 最优点中 q_W 的走势、ΔNFA 和 liability VA 的符号、liability share of gross VA；window 内 RoW yield 大致持平（但 level 为 13.5–18%，高于 G4 FCF/EV 的 6–9%）。R1 的 G_N≈1.02–1.03 接近 R&D capital 约 3%/年的增速，不过这是 Q 拟合的结果，且对应 3.5–6 倍的 R&D workers。R1 对 Y（RMSE 1.2–1.6%）和 wages（2–4%）的拟合是 inversion，不算 validation。

---

## 2. 分维度说明

### 2.1 Valuation scale（rows 1、11、12、13）

最紧的约束是 A=βe=Q+NFA，它沿任何路径都精确成立。ζ=Q/(βe) 只是它的改写，全球版本是 Q_US+Q_W=βe_US+s_W e_W。`lem_relative_dividend_bounds` 与 `prop_hkt_cone_invariance` 给出的 ζ∈[½, 3/2] 和 ζ→1 只在 HKT cone 内成立；notebook 05 的 ζ 从 0.90 降到 0.50–0.56，notebook 06 最优点的 ζ 从约 1.76 降到 1.17，都不在 tail 区域。无论 ζ 取多少，全球 equity value 都等于当期 young cohort 的总 saving。

Data 要求 Q/COMP 从 2 升到 8，implied β 从 2.0 升到 6.3（`data_final/implied_beta_US_main.csv`）。拉长 period 只改 level，不改 trend：取 T 年为一期，2025 年 Q/(5e)=1.67、A/(5e)=1.26，T≥7 才有 A/(Te)<1；但 A/e 在 1990–2025 升至 3.2 倍这件事 rescale 消除不了，而且 implied β 的 readme 已经指出，不重建 cohort income 和 asset ownership 的 rescale 是任意的。

因为 Q 有 cap 而 N_{t+1} 增长，q=Q/N_{t+1} 在每个 sweep 中都下降。Notebook 06 靠 portfolio search（ω̄=0.95、ω̄*=0.425、η=0.086）让 q_US 上升，但 log growth 只有 data 的 32%。External positions 与 valuation effects 只有 data 的 1–8%。此外 model 的 NFA level 基本不变（−0.92 到 −0.96）而 Y 增长 4.5 倍，所以所有 /Y ratio 都被 row 10 的高增长机械压低。

### 2.2 Income shares、markup 与 D 的 mapping（rows 2、3、4、5）

没有 capital 时，Y = w_L L + φH w_H + D，因此 D−I = Y−e。P1 可以写成闭式：

μ = (1 + (Y−COMP)/B_H) / φ

若 capital 吸收全部 Y−COMP−FCF（CFC、taxes、NCF），则 PX = B_H + FCF，D−I = FCF，于是：

μ = (1 + FCF/B_H) / φ

差别只在于用 44% of GVA 还是 12% of GVA。取 φ=1−NSCG share、2009–2024 全部年份和三种 premium（package CPS、re-censored CPS、ACS annual）：

| 设定 | 隐含 μ | 说明 |
|---|---|---|
| 无 capital | 2.34–3.02 | 2022 年 2.79，即现有 P1 结果 |
| Capital 吸收 Y−COMP−FCF | 1.45–1.73 | 2022 年 1.54，落在 external 1.10–1.84 内 |

这是 accounting illustration，不是 estimation。FCF 中仍含 capital 的 net return，所以 1.45–1.73 应视为 pure-rent markup 的上界。P1 被拒、μ≥2.7 的下界、R1 中 untargeted FCF 250% 的 RMSE（model net cash flow 是 FCF 的 3 倍左右）是同一个问题：model 没有 capital，net cash flow 是 FCF 的 3.7 倍。

趋势上，ρ>1 且 A_X X/(A_L L) 增长时 X 的 output share 趋于 0，所以 D/Y→0，d/q∝φ→0。Data 里 D/Y 没有下降趋势，yield 下降靠的是 Q/Y 上升。这个结论与窗口无关，但“D/Y 上升”并非与窗口无关：2007→2025 为 8.1% → 12.7%，2009→2024 为 14.4% → 12.5%（2009 年 FCF 异常高，因为 NCF 为负）。

### 2.3 R&D share（row 5）

1−φ 的 empirical counterparts 集中在 3–10%，每十年只变动 1–2pp。Model 中 1−φ 由 free entry 与 funding 共同决定：G_N = a·βζ·(e/w_H)，1−φ=(G_N−1)/(aH)。AHP-seed 在 t=1 时 0.2×0.4066×12.34=1.0036，所以 1−φ=1.8%。此后或者继续下降（ν_u=1.75），或者爆炸（ν_u≤1.25）。Notebook 06 的 28–30% 来自较高的 ζ；R1 的 22–30% 来自把 μ 设为 3.5 并把 Y−B_L 全归给 skilled margin。

a、ϑ、H 不变时，model 的 yield 只随 φ 变动，这是解析结论。要匹配 2007→2025 的 D/Q −26%，φ 要下降 26%，也就是 1−φ 从 7% 升到约 31%；从 1990 年算起（D/Q −46%）则要升到约 50%。实测的 1−φ 远没有这种变化。所以要匹配的 data pattern 是：R&D share 小且接近持平，同时 Q/Y 大幅上升。当前 block 下 1−φ 是 yield 唯一的变动来源，这正是冲突所在。

### 2.4 Free-entry（indifference）condition（row 6）

Free entry 给出 q=w_H/(aN)，等价于 Q=G_N w_H/a，也等价于 B_H/Q=a·H/G_N。Implied a、residual（dlog a = −residual）和 R1 constant-a fit 是**同一个约束的三种写法**，不是三个独立检验。各 knowledge mapping 结果相近也不算独立证据，因为 G_N≈1，N 基本不影响这个比率。真正起作用的是 Q、w_H、H 的 mapping。

能确认的事实是：Q/w_H 在 1995–2022 升至 2.86 倍（R1 样本 2009–24：observed labor ×2.85，mean labor ×2.23），knowledge stock 增速却稳定在 2–4%/年。这个 moment 本身无法区分下面几种解释：

- a_t 随时间下降（fishing out）。
- Entry cost 不以 skilled wage 计价。
- 价格中含有 entry 无法复制的部分（rent 或 bubble）。V6 目前让 bubble 在固定的 q 内挤占 fundamental，而不是抬高 q。

另外，Q 用的 EV 含有 physical capital 的价值，而 free entry 只约束 variety value。因此加入 capital 之后，这条 residual 必须重算。

### 2.5 Factor proportions 与 skill premium（rows 7、8、9）

ρ=2 时，log(w_H/w_L) = log[ϑα/(1−α)] − (ρ−1) log(A_X/A_L) − ρ log(X/L)。AHP-seed 与 HKT default 的 A_X/A_L 都等于 10，把 skilled wage 压到 unskilled wage 的 5–9%。Unbalanced branch 上 A_X/A_L∝N^{ξ−ν} 与 φ∝N^{−ψ/ρ} 两股力量渐近抵消，所以 premium 和 skilled bill share 最终趋于常数（后者极限 7.5%），并不趋于 0。趋于 0 的是 production 部分 φw_H H/e 和 D/Y。

三个失配维度由一条恒等式连起来：

w_H H/e = (Q/e) · (aH/G_N)

| | w_H H/e | Q/e | aH/G_N |
|---|---|---|---|
| Data 2022 | 0.495 | 6.27 | 0.079 |
| Model t=1 | 0.081 | 0.406 | 0.199 |

可见 skilled bill share 低，是因为 funding cap 压低了 Q/e，a·H 反而是 data 的 2.5 倍。如果放松 funding cap 使 Q/e≈6，并取 a·H≈0.08，free entry 就会自动给出 skilled bill share≈0.5（G_N≈1）。因此 free entry 的 **level** 问题可以解决，真正冲突的是 **trend**，也就是 row 6 的 B_H/Q 下降。

Trend 方面，H/L 自 1994 年上升 134%，自 2009 年上升 56%，premium 基本持平。在 ρ>1 下，这要求 A_X/A_L 下降，因此所有 mapping 都得到 ξ<ν。Model 也完全没有 skill upgrading。

### 2.6 RoW 与 regime structure（rows 14、15、16）

ξ_W=ν_b=0 下 RoW 没有技术增长。Absorbing regime 中两国 aggregate 零增长，US 在 switch 时收入下降 39%；这个幅度同时反映 ν_b=0 和 calibration 中 Ā_b(10, 1) 低于 u-regime 的 (15, 1.5)。实际上 covered RoW 在增长，其 research intensity 增速不低于 US（G4 researcher FTE per 100 employed +64%，US +43%，窗口不同）。Data 显示的 US/RoW asymmetry 主要在 valuations（MSCI USA ×5.4 vs ACWI ex-US ×1.9）和 sector productivity（US relative ICT productivity +98% vs G4 +42%），R&D capital 也有差距（+53% vs +34%），但不是 US-only 的转移。Simulation 中 date 1 的 bubble share upper bound 低于 10⁻⁶，switch leakage（0.29/period）占主导。

---

## 3. 对 model 修改的含义

以下排序是我的判断，依据是每项改动能覆盖多少记分卡维度。

1. **Funding cap 是第一阶失败（rows 1、8、11、12、13）。** 只要 equity value 还等于当期 young cohort 的 saving，production block 再怎么改，也无法让 Q/COMP 从 2 升到 8，无法产生 1–2 GVA 的 gross positions 或 −0.7 GVA 的 valuation effects。候选方向：更长或多期 life cycle、跨 cohort 持有 wealth、outside wealth 或 bequests、需求不绑定当期 labor income 的 asset-holding sector。Implied β（2.0 → 6.3）是该 block 的直接 target。放松它还能同时解决 skilled bill share 的 level（2.5 节）。

2. **Corporate capital（rows 2、3、5）。** 加入 depreciation、production taxes、net investment 之后，P1 可以同时给出 μ≈1.45–1.73 和 1−φ≈7%（2.2 节），并消除 D 的 3.7 倍歧义。Capital 还提供不经过 φ 的 Q 增长渠道（capital accumulation、Tobin's q），但仍受 row 1 的 cap 约束。

3. **不依赖 1−φ→1 的 explosive Q/D 机制（rows 4、5、6）。** Data 的分解很明确：Q/D 上升主要靠 Q/Y，R&D share 稳定在 7% 附近；当前机制给出相反的分解。替代机制应让 incumbent claims 的价格相对 entry cost 上升，例如 convex 或 goods-denominated entry cost、递减的 a(N)、entry 无法复制 rents 的 heterogeneous varieties，或把 q 抬到 w_H/(aN) 之上的 bubble component。Targets 是 B_H/Q 的下降（0.10 → 0.08）和 Q/w_H 约 ×2.9。

4. **Factor-proportions block（rows 7–9）。** ρ>1 下 model 容纳不了 H/L 上升、premium 持平和 ξ>ν 这三者。可选方向：让 H_t 外生增长后重新检验 ordering；在 mapping 中把 skilled production input 与 BA+ employment 分开；或者接受 φ-decay 机制（需要 ρ>1 且 ξ>ν）不是 valuation facts 的来源。

5. **Growth calibration、RoW 与 absorbing regime（rows 10、14–16）。** ξ_W>0、ν_b>0（`Two_country_proudction_fixed_nu_b` 已有 fixed-exponent solver）可以消除 RoW 停滞和零增长的 absorbing regime。Output growth 需要同时约束 a·H、1−φ 与 ν_u。

## 4. Data 无法约束的维度

π 与 b-regime technology（没有可操作的 regime classifier，all-u 样本是 right-censored）、bubble share、γ<1（external evidence 集中在 γ≈1）、RoW safe rate R_f^W。这些仍是 scenario，不是 target。

## 5. 来源文件

- Model：`AI_drafting/V6_production.tex` lines 300–515（production、free entry、output identity），1281–1335（NFA bridge），1506–1540（technology primitives），2074–2135 与 2305–2365（cone 与 asymptotic reduction）。Solver：`Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl`（`compute_production`）。
- Simulation：`outputs_zero_nu_b/05_nu_u_funding_regime_sweeps/{all_u_and_realized_switch_state_paths,production_wage_and_force_paths,us_bubble_share_bound_leakage,stock_funding_identity_summary}.csv`；`outputs_zero_nu_b/06_post2008_ahp_nfa_calibration_search/{model_empirical_comparison,candidate_summary,best_candidate_path,run_manifest}.csv`；`outputs_zero_nu_b/02_ahp_hkt_scalar_tail_bubble_bounds/calibration_manifest.csv`；`outputs_zero_nu_b/04_phi_spillover_funding_sweeps/spillover_sweep_summary.csv`。
- Calibration：`Calibration_R1/1_Do/runs/01_observed_labor/{report.md,Spillover_Diagnosis/README.md,results/baseline_allocation.csv}`；`Calibration_R1/1_Do/runs/02_fixed_mean_labor/{README.md,results/run_comparison.csv,results/conditional_paths.csv,results/calibration_status.json}`；`Calibration_R1/1_Do/shared/references/data_audit.md`。
- Data：`Empirical_Mapping_Annual/data_intermediate/{us_corporate_external_corporate,us_corporate_external_external,labor_wages,row_corporate}.csv`；`data_final/{implied_beta_US_main,implied_ai_US_main,us_row_dq_two_panel}.csv`；`diagnostics/{implied_beta_readme.md,overidentification_checks.csv}`；`Mechanism_Evidence_US_ROW/processed/dated_moments.csv`；`WRDS_Enhancement_2026-09-19/processed/wrds_dated_moments.csv`；`AHP_NFA/ahp_us_nfa_period_summary.csv`；`US_Equity_Positions/{summary_statistics.json,us_equity_capitalization_summary.json}`；`Skill_Premium_and_RD_Share_2026-10-26/{README.md,data/derived/*.csv,figures/data/*.csv}`。

## 6. 10 月 30 日修订内容

相对 10 月 26 日初稿，重新计算后作了以下更正：

- **Row 4：** “D/Y 上升”依赖窗口。2009→2024 的 D/Y 是下降的（14.4% → 12.5%）。稳健的结论是 D/Y 没有下降趋势、Q/Y 主导。
- **Row 6：** 初稿称“三个独立检验”，实际是同一约束的三种写法。Implied a·H 的降幅更正为 −19% 到 −38%（初稿 −40%），并补充 a 本身 −54% 到 −62%。
- **Row 8：** 初稿称 skilled bill share 趋于 0，有误。正确结果是由恒等式 w_H H/e=βζ·aH/G_N 决定，极限 7.5%。
- **Row 10：** 新增 output growth，初稿遗漏。
- **Row 12：** Scale miss 更正为 13–620 倍（初稿 50–100 倍），补充 NFA/Y trend。
- **Row 14：** e_W 并非每期不变；T=80 时 φ_W 为 0.04–0.53（初稿 0.12–0.53）。
- **其他数字：** H/L 自 1994 年 +134%（初稿 85%）；ζ 到 T=80 为 0.50–0.56；μ floor 为 2.35–2.81，1−φ≈7% 时 μ=2.34–3.02；NSCG 下限 6.1%（2013 年，该年有 data caveat）；A_X/A_L 两组 calibration 都是 10（初稿写 10 或 15）；q_W 的终值区间 0.06–0.16。
- **机制表述：** 1.8% 的 R&D share 由 G_N=a·βζ(e/w_H) 决定，不是因为 production margin 占优；T≥7 年即可使 2025 年 A/(Te)<1，不需要 generation-length period。
- **新增：** μ 的闭式对比（2.2 节）和 w_H H/e=(Q/e)(aH/G_N) 三角关系（2.5 节）。
- **Rows 12、13（vintage）：** external accounts 有 June 2026 release（`AHP_NFA`，notebook 06 的 targets）和 September 2026 release 两个版本，初稿混用了。Row 13 现在两个都报告；同一 vintage 下，2025 年 foreign-held equity 约占 EV 的 42%，不是 49%。Row 12 的 NFA/GVA 改用与其 ΔNFA 相同的 vintage。
- **Row 9：** 不同的 premium series 是八种；`calibration_sensitivity.csv` 第九行是 splice，与 CPS re-censored 相同。
- **Row 6：** implied a·H 的 −38% 只来自 patent stock，其他三种 knowledge mapping 约为 −20%。

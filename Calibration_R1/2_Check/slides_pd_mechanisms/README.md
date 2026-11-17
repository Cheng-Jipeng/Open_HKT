# P/D 比率上升的来源：替代机制与在位企业队列检验（主窗口 2009–2025）

Beamer 幻灯片（中文，经济学术语保留英文），19 页，2026 年 11 月 13 日。回答的问题：Calibration R1 的数据不支持 R&D 技能劳动份额趋于 1，那么还有哪些机制能产生 explosive P/D ratio，数据支持哪一条。PDF 是 `main.pdf`。

**窗口约定。** 主窗口是 2009–2025 年，即被识别为 unbalanced-growth（u 态）的年份；1990–2008 只在图中以灰色显示，不作为证据。2009 年是危机谷底（FCF/Y 14.4%，D/Q 7.4%，回购几乎停止），所以每处都并报 2011 或 2013 基年。

| 文件 | 作用 |
|---|---|
| `main.tex` | 源文件，xelatex + xeCJK（Hiragino Sans GB）。数值由 `data/values.tex` 的 `\val{key}` 注入，不手写。 |
| `scripts/fetch_wrds.py` | 直连 WRDS PostgreSQL 提取 Compustat 年度基本面（`comp.funda` 1989–2024 财年，美国公司）和 `comp.company`。凭据来自 `~/.pgpass`，不入库。WRDS MCP 在 2026-11-13 超时，故改用直连。 |
| `scripts/build_data.py` | 从仓库已有输出与 Compustat 提取生成 `data/*.csv`、`data/values.tex` 与 `figures/*.pdf|png`。只读输入。 |
| `data/wrds/` | Compustat 提取（gzip CSV）与 `manifest.json`（查询语句、行数、时间）。仅供本项目研究使用。 |
| `data/t0`–`t9` | 幻灯片中每张表的数据：核心序列、倍数（2009/2010/2011/2013 基年）、比率、分解、自由进入、收益率恒等式（曲线与各基年所需份额）、Compustat 全体与 2009/2010/2011 队列。 |
| `figures/f01`–`f09` | 幻灯片图。蓝 = 数据，橙 = 模型，绿 = Compustat 队列，灰 = 2009 之前。 |

## 主要结果（2009–2025）

- Q ×5.5、FCF ×2.0、GVA ×2.3、COMP ×2.2。D/e 在 18% 到 25% 之间，无趋势；以 2009 为基年 D 比 e 慢 0.5 个百分点/年，以 2011 为基年快 0.3 个百分点。HKT Theorem 1 条件 (i) 在窗口内最多勉强成立，explosive P/D 在 Q ≤ βe 下等价于 D/e → 0，被否定。
- Δlog(Q/D) 的 87%（2009 起）到 102%（2011 起）来自 Q/Y。隐含 β 从 2.7 升到 6.3；外资持有/Y ×2.8，D/Y ×0.88。
- 收益率恒等式 D/Q = (μ−1)·φ/(1−φ)·(G−1)/G：读法 A（HKT）任何基年都需要 R&D share 27% 以上；读法 B 从 2010/2011 基年需要 13–14%，从 2013/2015 基年需要 9%。自由进入隐含 G−1 ≈ 0.3–0.8%/年、μ ≈ 1.43–1.51。隐含 a 在 2009–2022 年的趋势 −7.0%/年（BJVW −5.1%）。
- 在位企业队列（Compustat，2009 队列 6,146 家）：现金股息 ×2.32 对 e ×2.06，队列市值 ×3.9；2010、2011 队列同。企业层面也没有分红坍缩，新进入者稀释的是市值份额而非股息。
- 替代机制排序：世界储蓄与财富存量（资金侧）> 供给收缩与无弹性需求 > 租金与无形资本 > 研究生产率下降（block 内修正，有界）。

## 重建

```bash
cd scripts
WRDS_USER=$(cut -d: -f4 ~/.pgpass) uv run --no-project --python 3.12 --with wrds --with pandas python -I fetch_wrds.py   # 已有提取时跳过（脚本拒绝覆盖）
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I build_data.py
cd .. && latexmk -xelatex main.tex
```

## 口径与保留

- Compustat：`indfmt=INDL, datafmt=STD, popsrc=D, consol=C, fic=USA, curcd=USD`；重复 gvkey-fyear 取总资产最大者；缺失的 dvt、prstkc、sstk、oancf、capx 记 0；队列为基年总资产大于 0 的公司，逐年加总仍在报告的成员。队列随并购与退市收缩，使队列股息向下偏，即偏向 HKT 的企业层面假说。2009 基年的净 payout 与 FCF 起点有危机效应（回购停止、FCF 高峰），2011 队列是干净对照。
- 上市公司数用 Compustat 交易所代码 11/12/14 且有年末价格，口径与 CRSP（Doidge–Karolyi–Stulz 2017）不同。
- 知识存量增速 convention-driven（见 `Data_Reliability_Audit_2026-11-11`），收益率恒等式里任何 G 的数字都是条件性的。
- 外部头寸用 2026 年 9 月版；现金股息收益率为 Fed Z.1 总股息/股权市值。

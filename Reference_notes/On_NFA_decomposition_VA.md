## NFA decomposition

From the US perspective,
$$
NFA_t
=
\underbrace{q_{W,t}n_{W,t}}_{\text{US equity assets in RoW}}
+
\underbrace{b_t}_{\text{US net bond position}}
-
\underbrace{q_{US,t}n^*_{US,t}}_{\text{RoW equity claims on US}}.
$$
Equivalently,
$$
\begin{align}
\mathrm{NFA}_t
 &=
\underbrace{(1-\omega_t)(1-\theta_t)A_t}_{\text{U.S. outward equity claims}}
-
\underbrace{\omega_t^*(1-\theta_{US,t}^*)A_t^*}_{\text{foreign-held U.S. equity liabilities}}
+
\underbrace{\theta_tA_t}_{\text{U.S. net safe-asset/bond claims}} 
\\
&= A_t -Q_t
\end{align}
$$

Define the value of foreign assets owned by domestic residents:
$$
\begin{align}
\begin{split}
FA_t&=q_{W,t}n_{W,t},\\
\Rightarrow \Delta FA_t &= q_{W,t}n_{W,t} - q_{W,t-1}n_{W,t-1} \\
&= \underbrace{(n_{W,t}-n_{W,t-1})q_{W,t}}_{\text{net purchase of foreign assets}} 
+ \underbrace{n_{W,t-1}(q_{W,t}-q_{W,t-1})}_{\text{capital gains on existing foreign assetes}}
\end{split}
\end{align}
$$
Similarly, the foreign-owned domestic liabilities are defined as
$$
\begin{align}
\begin{split}
FL_t&=q_{US,t}n^*_{US,t}-b_t,\\
\Rightarrow \Delta FL_t &= q_{US,t}n^*_{US,t}-b_t - (q_{US,t-1}n^*_{US,t-1}-b_{t-1}) \\
&= \underbrace{(n^*_{US,t}-n^*_{US,t-1})q_{US,t}}_{\text{net inccurence of foreign liabilities}} 
+ \underbrace{n^*_{US,t-1}(q_{W,t}-q_{W,t-1})}_{\text{capital gains on existing domestic liabilities}} - (b_t - b_{t-1})
\end{split}
\end{align}
$$
The change in the NFA position is thus
$$
\begin{align}
\begin{split}
\Delta NFA_t =& \Delta FA_t  -\Delta FL_t \\
=& {\color{red}\underbrace{n_{W,t-1}(q_{W,t}-q_{W,t-1})}_{\text{capital gain on US-held RoW equity}}
-
\underbrace{n^*_{US,t-1}(q_{US,t}-q_{US,t-1})}_{\text{capital gain on foreign-held US equity}} \equiv VA_t} \\
&+ {\color{blue}\underbrace{q_{W,t}(n_{W,t}-n_{W,t-1})}_{\text{net US purchases of RoW equity}}
-
\underbrace{q_{US,t}(n^*_{US,t}-n^*_{US,t-1})}_{\text{net RoW purchases of US equity}}
+
\underbrace{(b_t-b_{t-1})}_{\text{change in US net bond position}} \equiv CA_t}.
\end{split}
\end{align}
$$

$$
n_{W,t}q_{W,t}-n_{W,t-1}q_{W,t-1}
$$



### Valuation effects $VA_t$

The clean equity valuation effect is:
$$
VA_t^{eq}
=
\underbrace{n_{W,t-1}(q_{W,t}-q_{W,t-1})}_{\text{capital gain on US-held RoW equity}}
-
\underbrace{n^*_{US,t-1}(q_{US,t}-q_{US,t-1})}_{\text{capital gain on foreign-held US equity}}.
$$
The important timing point is that we should use **per-variety price growth** $q_{i,t}/q_{i,t-1}-1$, not aggregate market-cap growth $\mathcal Q_{i,t}/\mathcal Q_{i,t-1}-1$. The reason is that
$$
\mathcal Q_{i,t}=N_{i,t+1}q_{i,t}
$$
includes newly created varieties. New claims created by R&D are transactions/issuance, not valuation gains on existing holdings.

### Current account $CA_t$

The current account should be the **net transaction flow** that changes the US external position, evaluated at current prices:
$$
CA_t
=
\underbrace{q_{W,t}(n_{W,t}-n_{W,t-1})}_{\text{net US purchases of RoW equity}}
-
\underbrace{q_{US,t}(n^*_{US,t}-n^*_{US,t-1})}_{\text{net RoW purchases of US equity}}
+
\underbrace{(b_t-b_{t-1})}_{\text{change in US net bond position}}.
$$
This is the V4 counterpart of AHP’s equation

### Exact model identity (residual term)

With the definitions above,
$$
NFA_t-NFA_{t-1}
=
CA_t+VA_t^{eq}.
$$
To verify:
$$
NFA_t-NFA_{t-1}
=
\left[
q_{W,t}n_{W,t}
-
q_{W,t-1}n_{W,t-1}
\right]
-
\left[
q_{US,t}n^*_{US,t}
-
q_{US,t-1}n^*_{US,t-1}
\right]
+
(b_t-b_{t-1}).
$$
Add and subtract $q_{W,t}n_{W,t-1}$ and $q_{US,t}n^*_{US,t-1}$:
$$
NFA_t-NFA_{t-1}
=
\underbrace{
q_{W,t}(n_{W,t}-n_{W,t-1})
-
q_{US,t}(n^*_{US,t}-n^*_{US,t-1})
+
(b_t-b_{t-1})
}_{CA_t}
\\+
\underbrace{
n_{W,t-1}(q_{W,t}-q_{W,t-1})
-
n^*_{US,t-1}(q_{US,t}-q_{US,t-1})
}_{VA_t}.
$$
So in our model,
$$
RES_t
=
NFA_t-NFA_{t-1}-CA_t-VA_t
=
0.
$$
If the numerical residual is not close to zero, the likely problem is timing: using $N_{i,t+1}$ instead of $N_{i,t}$ for existing claims, or using aggregate market-cap changes as valuation changes.

## Normalization

AHP’s Figure 2 plots NFA, cumulative current account, cumulative valuation effects, and cumulative residuals as fractions of US corporate GVA. They write
$$
NFA_t
=
NFA_0
+
\sum_{j=1}^t CA_j
+
\sum_{j=1}^t VA_j
+
\sum_{j=1}^t RES_j.
$$
In our model, use $Y_{US,t}$ as the analog of US corporate GVA. Then compute
$$
\begin{gathered}
\frac{N F A_t}{Y_{U S, t}}, \\
\frac{\sum_{j=1}^t C A_j}{Y_{U S, t}}, \\
\frac{\sum_{j=1}^t V A_j}{Y_{U S, t}}, \\
\frac{\sum_{j=1}^t R E S_j}{Y_{U S, t}} .
\end{gathered}
$$
Since our model has no data discrepancy,
$$
\sum_{j=1}^t RES_j \approx 0.
$$
For an exact accounting line, plot
$$
\frac{NFA_0+\sum_{j=1}^t CA_j+\sum_{j=1}^t VA_j}{Y_{US,t}}
$$
against
$$
\frac{NFA_t}{Y_{US,t}}.
$$
They should coincide.

## Summary



After solving the model and simulating a realized path, store:
$$
q_{US,t},q_{W,t},N_{US,t},N_{W,t},n_{W,t},n^*_{US,t},b_t,Y_{US,t}.
$$
Then for $t\ge1$:
$$
\begin{gathered}
N F A_t=q_{W, t} n_{W, t}+b_t-q_{U S, t} n_{U S, t}^*, \\
V A_t=n_{W, t-1}\left(q_{W, t}-q_{W, t-1}\right)-n_{U S, t-1}^*\left(q_{U S, t}-q_{U S, t-1}\right), \\
C A_t=q_{W, t}\left(n_{W, t}-n_{W, t-1}\right)-q_{U S, t}\left(n_{U S, t}^*-n_{U S, t-1}^*\right)+\left(b_t-b_{t-1}\right), \\
R E S_t=N F A_t-N F A_{t-1}-C A_t-V A_t .
\end{gathered}
$$

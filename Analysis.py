import os
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import stats
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import stats

# ---- Paths: edit BASE for your machine ---------------------------------------
BASE = Path(r"C:\International_Debt Analysis System")  
OUT = Path(os.environ.get("IDS_OUT", BASE / "Output"))
WIDE = Path(os.environ.get("IDS_WIDE", OUT / "ids_cleaned_wide.csv"))
META = Path(os.environ.get("IDS_META", OUT / "country_metadata_cleaned.csv"))
RES = OUT / "analysis"
RES.mkdir(parents=True, exist_ok=True)
YEAR = "2024"

# ---- Load, join metadata, keep real countries only (drop 14 aggregates) -------
W = pd.read_csv(WIDE)
M = pd.read_csv(META)
M["country_code"] = M["country_code"].str.strip()
W = W.drop(columns=["country_name"]).merge(
    M[["country_code", "country_name", "entity_type", "region", "income_group", "is_hipc"]],
    on="country_code", how="left")
W = W[W.entity_type == "Country"]
info = W.drop_duplicates("country_code").set_index("country_code")[
    ["country_name", "region", "income_group", "is_hipc"]]

def s(code, y=YEAR):
    return W[W.indicator_code == code].set_index("country_code")[y]

# ---- Core table for the latest year -----------------------------------------
X = pd.DataFrame({
    "debt_usd": s("DT.DOD.DECT.CD"), "gni": s("NY.GNP.MKTP.CD"), "pop": s("SP.POP.TOTL"),
    "debt_gni": s("DT.DOD.DECT.GN.ZS"), "debt_exports": s("DT.DOD.DECT.EX.ZS"),
    "debt_service_exports": s("DT.TDS.DECT.EX.ZS"), "interest_gni": s("DT.INT.DECT.GN.ZS"),
    "debt_per_capita": s("DT.DOD.DECT.PC.CD"), "short_term_pct": s("DT.DOD.DSTC.ZS"),
    "concessional_pct": s("DT.DOD.ALLC.ZS"), "multilateral_pct": s("DT.DOD.MLAT.ZS"),
    "reserves_pct_debt": s("FI.RES.TOTL.DT.ZS") if (W.indicator_code == "FI.RES.TOTL.DT.ZS").any() else np.nan,
    "reserves_usd": s("FI.RES.TOTL.CD"),
}).join(info)
X["reserves_pct_debt"] = X["reserves_pct_debt"].fillna(X.reserves_usd / X.debt_usd * 100)
X.to_csv(RES / "country_debt_profile_2024.csv")

# ---- 1. Distribution, top/bottom ---------------------------------------------
d = X.debt_usd.sort_values(ascending=False)
summary = pd.Series({
    "countries": d.count(), "total_bn": d.sum() / 1e9, "mean_bn": d.mean() / 1e9,
    "median_bn": d.median() / 1e9, "std_bn": d.std() / 1e9, "skew": d.skew(),
    "top1_share_%": d.iloc[0] / d.sum() * 100, "top5_share_%": d.head(5).sum() / d.sum() * 100,
    "top10_share_%": d.head(10).sum() / d.sum() * 100})
summary.to_csv(RES / "distribution_summary.csv", header=["value"])
top10 = (d.head(10) / 1e9).rename(index=info.country_name)
bot10 = (d.tail(10) / 1e9).rename(index=info.country_name)

def ranked(col, n=10):
    r = X[col].dropna().sort_values(ascending=False)
    return pd.concat([r.head(n), r.tail(n)]).rename(index=info.country_name)
for col in ["debt_gni", "debt_per_capita", "debt_service_exports"]:
    ranked(col).to_csv(RES / f"top_bottom_{col}.csv", header=[col])

# ---- 2. Group comparisons -----------------------------------------------------
agg = {"n": ("debt_usd", "size"), "total_debt_bn": ("debt_usd", lambda x: x.sum() / 1e9),
       "median_debt_gni": ("debt_gni", "median"), "median_service_exports": ("debt_service_exports", "median"),
       "median_per_capita": ("debt_per_capita", "median"), "median_short_term": ("short_term_pct", "median"),
       "median_concessional": ("concessional_pct", "median")}
for grp in ["region", "income_group", "is_hipc"]:
    X.groupby(grp).agg(**agg).round(2).to_csv(RES / f"by_{grp}.csv")

# ---- 3. Trend (balanced panel so country coverage does not drive growth) -------
yrs = [str(y) for y in range(2000, 2025)]
D = W[W.indicator_code == "DT.DOD.DECT.CD"].set_index("country_code")[yrs]
bal = D.dropna(subset=["2000", "2024"])
trend = (bal.sum() / 1e9).rename("total_debt_bn")
cagr = ((trend["2024"] / trend["2000"]) ** (1 / 24) - 1) * 100
trend.to_csv(RES / "trend_total_debt_balanced.csv")

# ---- 4. Composition ----------------------------------------------------------
comp_codes = {"Public & publicly guaranteed": "DT.DOD.DPPG.CD", "Private nonguaranteed": "DT.DOD.DPNG.CD",
              "Short-term": "DT.DOD.DSTC.CD", "Long-term": "DT.DOD.DLXF.CD",
              "Multilateral (PPG)": "DT.DOD.MLAT.CD", "Bilateral (PPG)": "DT.DOD.BLAT.CD",
              "Concessional": "DT.DOD.ALLC.CD", "Variable rate": "DT.DOD.VTOT.CD"}
tot = X.debt_usd.sum()
comp = pd.DataFrame({k: [s(v).sum() / 1e9, s(v).sum() / tot * 100] for k, v in comp_codes.items()},
                    index=["bn_usd", "pct_of_total_debt"]).T.round(1)
comp.to_csv(RES / "debt_composition_2024.csv")

# 5. Relationships (Spearman: robust to the heavy skew) consistently move up or down together based on their rank ------
cols = ["debt_gni", "debt_service_exports", "interest_gni", "debt_per_capita", "short_term_pct",
        "concessional_pct", "multilateral_pct", "reserves_pct_debt"]
corr = X[cols].corr(method="spearman").round(2)
corr.to_csv(RES / "correlation_spearman.csv")
pairs = [("gni", "debt_usd"), ("pop", "debt_usd"), ("debt_gni", "debt_service_exports"),
         ("concessional_pct", "debt_service_exports"), ("reserves_pct_debt", "debt_gni"),
         ("reserves_pct_debt", "debt_service_exports"), ("short_term_pct", "debt_service_exports")]
rows = []
for a, b in pairs:
    z = X[[a, b]].dropna(); r = stats.spearmanr(z[a], z[b])
    rows.append({"x": a, "y": b, "n": len(z), "spearman_rho": round(r[0], 2), "p_value": r[1]})
pd.DataFrame(rows).to_csv(RES / "relationship_tests.csv", index=False)
hipc_rows = []
for v in ["debt_gni", "debt_service_exports", "concessional_pct", "short_term_pct", "debt_per_capita"]:
    a, c = X[X.is_hipc][v].dropna(), X[~X.is_hipc][v].dropna()
    hipc_rows.append({"indicator": v, "HIPC_median": a.median(), "non_HIPC_median": c.median(),
                      "mann_whitney_p": stats.mannwhitneyu(a, c).pvalue})
pd.DataFrame(hipc_rows).round(4).to_csv(RES / "hipc_vs_non_hipc.csv", index=False)

# ---- Charts --------------------------------------------------------------------
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
C1, C2 = "#1f4e79", "#c0504d"

fig, ax = plt.subplots(1, 2, figsize=(13, 5))
top10[::-1].plot.barh(ax=ax[0], color=C1); ax[0].set_title("Top 10 – total external debt, 2024 (US$ bn)")
bot10[::-1].plot.barh(ax=ax[1], color=C2); ax[1].set_title("Bottom 10 – total external debt, 2024 (US$ bn)")
for a in ax: a.set_ylabel("")
plt.tight_layout(); plt.savefig(RES / "1_top_bottom_debt.png", dpi=150); plt.close()

fig, ax = plt.subplots(figsize=(9, 4.5))
ax.plot(trend.index.astype(int), trend.values, color=C1, lw=2.5, marker="o", ms=3)
ax.set_title(f"Total external debt, {len(bal)} countries with data in 2000 and 2024 (US$ bn; CAGR {cagr:.1f}%)")
ax.set_xlabel("Year"); plt.tight_layout(); plt.savefig(RES / "2_trend.png", dpi=150); plt.close()

fig, ax = plt.subplots(1, 2, figsize=(13, 4.8))
order = ["Low income", "Lower middle income", "Upper middle income"]
g = X[X.income_group.isin(order)].groupby("income_group")[["short_term_pct", "concessional_pct", "multilateral_pct"]].median().loc[order]
g.plot.bar(ax=ax[0], rot=15, color=[C1, "#9bbb59", C2]); ax[0].set_title("Median debt mix by income group (% of total external debt)"); ax[0].set_xlabel("")
reg = X.groupby("region")["debt_gni"].median().sort_values()
reg.plot.barh(ax=ax[1], color=C1); ax[1].set_title("Median external debt, % of GNI, by region (2024)"); ax[1].set_ylabel("")
plt.tight_layout(); plt.savefig(RES / "3_composition_regions.png", dpi=150); plt.close()

z = X[["gni", "debt_usd", "debt_gni"]].dropna()
fig, ax = plt.subplots(figsize=(8, 6))
sc = ax.scatter(z.gni / 1e9, z.debt_usd / 1e9, c=z.debt_gni.clip(upper=150), cmap="YlOrRd", edgecolor="k", lw=.3, s=45)
ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlabel("GNI (US$ bn, log)"); ax.set_ylabel("External debt (US$ bn, log)")
ax.set_title("Debt scales with economy size; colour = debt % of GNI"); plt.colorbar(sc, label="Debt % of GNI (capped at 150)")
for code in z.sort_values("debt_gni", ascending=False).head(4).index.union(z.debt_usd.nlargest(3).index):
    ax.annotate(info.country_name[code], (z.gni[code] / 1e9, z.debt_usd[code] / 1e9), fontsize=8, xytext=(4, 4), textcoords="offset points")
plt.tight_layout(); plt.savefig(RES / "4_gni_vs_debt.png", dpi=150); plt.close()

fig, ax = plt.subplots(figsize=(8, 6.5))
im = ax.imshow(corr, cmap="RdBu_r", vmin=-1, vmax=1)
ax.set_xticks(range(len(cols))); ax.set_yticks(range(len(cols)))
ax.set_xticklabels(cols, rotation=45, ha="right"); ax.set_yticklabels(cols)
for i in range(len(cols)):
    for j in range(len(cols)): ax.text(j, i, f"{corr.iloc[i, j]:.2f}", ha="center", va="center", fontsize=8)
ax.set_title("Spearman correlations, debt indicators (2024)"); plt.colorbar(im)
plt.tight_layout(); plt.savefig(RES / "5_correlation_heatmap.png", dpi=150); plt.close()

print(summary.round(2)); print("CAGR", round(cagr, 2)); print(comp); print(corr)

#debt_long
"""
External debt analysis: World Bank International Debt Statistics (long format).

Usage:
    python debt_analysis.py [path/to/ids_debt_long.csv] [output_dir]

Requires: pandas, numpy, scipy, matplotlib
Columns expected: country_code, indicator_code, year, value
"""


CSV = sys.argv[1] if len(sys.argv) > 1 else "Output/ids_debt_long.csv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "Output/analysis"
LAST = 2024  # last year with actuals; 2025-2032 are scheduled debt service only

pd.set_option("display.width", 220)
pd.set_option("display.max_columns", 30)
plt.rcParams.update({"font.size": 10, "axes.spines.top": False,
                     "axes.spines.right": False, "axes.titleweight": "bold",
                     "axes.titlesize": 11})
BLUE, RED, GREY = "#1f4e79", "#c0504d", "#7f7f7f"

# --------------------------------------------------------------------------
# 1. Metadata: country names and regions (the CSV has neither)
# --------------------------------------------------------------------------
NAMES = """AFG Afghanistan|AGO Angola|ALB Albania|ARG Argentina|ARM Armenia|AZE Azerbaijan|BDI Burundi|BEN Benin|BFA Burkina Faso|BGD Bangladesh|BIH Bosnia & Herz.|BLR Belarus|BLZ Belize|BOL Bolivia|BRA Brazil|BTN Bhutan|BWA Botswana|CAF Central African Rep.|CHN China|CIV Côte d'Ivoire|CMR Cameroon|COD DR Congo|COG Rep. of Congo|COL Colombia|COM Comoros|CPV Cabo Verde|DJI Djibouti|DMA Dominica|DOM Dominican Rep.|DZA Algeria|ECU Ecuador|EGY Egypt|ERI Eritrea|ETH Ethiopia|FJI Fiji|GAB Gabon|GEO Georgia|GHA Ghana|GIN Guinea|GMB Gambia|GNB Guinea-Bissau|GNQ Equatorial Guinea|GRD Grenada|GTM Guatemala|GUY Guyana|HND Honduras|HTI Haiti|IDN Indonesia|IND India|IRN Iran|IRQ Iraq|JAM Jamaica|JOR Jordan|KAZ Kazakhstan|KEN Kenya|KGZ Kyrgyz Rep.|KHM Cambodia|LAO Lao PDR|LBN Lebanon|LBR Liberia|LCA St. Lucia|LKA Sri Lanka|LSO Lesotho|MAR Morocco|MDA Moldova|MDG Madagascar|MDV Maldives|MEX Mexico|MKD North Macedonia|MLI Mali|MMR Myanmar|MNE Montenegro|MNG Mongolia|MOZ Mozambique|MRT Mauritania|MUS Mauritius|MWI Malawi|NER Niger|NGA Nigeria|NIC Nicaragua|NPL Nepal|PAK Pakistan|PER Peru|PHL Philippines|PNG Papua New Guinea|PRY Paraguay|RWA Rwanda|SDN Sudan|SEN Senegal|SLB Solomon Is.|SLE Sierra Leone|SLV El Salvador|SOM Somalia|SRB Serbia|STP São Tomé & Príncipe|SUR Suriname|SWZ Eswatini|SYR Syria|TCD Chad|TGO Togo|THA Thailand|TJK Tajikistan|TKM Turkmenistan|TLS Timor-Leste|TON Tonga|TUN Tunisia|TUR Türkiye|TZA Tanzania|UGA Uganda|UKR Ukraine|UZB Uzbekistan|VCT St. Vincent & Gren.|VNM Vietnam|VUT Vanuatu|WSM Samoa|XKX Kosovo|YEM Yemen|ZAF South Africa|ZMB Zambia|ZWE Zimbabwe"""
NAME = {x[:3]: x[4:] for x in NAMES.split("|")}

_REGIONS = {
    "SAS": "AFG BGD BTN IND LKA MDV NPL PAK",
    "EAP": "CHN FJI IDN KHM LAO MMR MNG PHL PNG SLB THA TLS TON VNM VUT WSM",
    "ECA": "ALB ARM AZE BIH BLR GEO KAZ KGZ MDA MKD MNE SRB TJK TKM TUR UKR UZB XKX",
    "MNA": "DJI DZA EGY IRN IRQ JOR LBN MAR SYR TUN YEM",
    "LAC": "ARG BLZ BOL BRA COL DMA DOM ECU GRD GTM GUY HND HTI JAM LCA MEX NIC PER PRY SLV SUR VCT",
}
REG = {c: r for r, codes in _REGIONS.items() for c in codes.split()}
for c in NAME:
    REG.setdefault(c, "SSA")  # everything else is Sub-Saharan Africa

# Indicator codes
D, GN, EX = "DT.DOD.DECT.CD", "DT.DOD.DECT.GN.ZS", "DT.DOD.DECT.EX.ZS"
TDS, TDSX = "DT.TDS.DECT.CD", "DT.TDS.DECT.EX.ZS"
INT, INTGN, NFL = "DT.INT.DECT.CD", "DT.INT.DECT.GN.ZS", "DT.NFL.DECT.CD"
STS, CONC, MLAT = "DT.DOD.DSTC.ZS", "DT.DOD.ALLC.ZS", "DT.DOD.MLAT.ZS"

# --------------------------------------------------------------------------
# 2. Load, drop regional/income aggregates, pivot to country-year x indicator
# --------------------------------------------------------------------------
raw = pd.read_csv(CSV)
raw = raw[raw.country_code.isin(NAME)]  # keeps only the 120 real countries
p = raw.pivot_table(index=["country_code", "year"], columns="indicator_code", values="value")
act = p[p.index.get_level_values("year") <= LAST]      # actuals
a = act.xs(LAST, level="year").copy()                  # 2024 cross-section
a["region"] = a.index.map(REG)

print(f"Countries: {a.shape[0]}, indicators: {p.shape[1]}, years: {raw.year.min()}-{raw.year.max()}")

# --------------------------------------------------------------------------
# 3. Country-wise distribution and concentration
# --------------------------------------------------------------------------
stock = a[D].sort_values(ascending=False)
total = stock.sum()
print(f"\nTotal external debt {LAST}: ${total/1e12:.2f}tn | median ${stock.median()/1e9:.1f}bn | mean ${stock.mean()/1e9:.1f}bn")
print(f"Share: top1 {stock.iloc[0]/total:.1%}, top5 {stock.head(5).sum()/total:.1%}, top10 {stock.head(10).sum()/total:.1%}")

# --------------------------------------------------------------------------
# 4. Highest / lowest by each measure
# --------------------------------------------------------------------------
def rank_table(col, label, n=10, scale=1.0):
    s = (a[col].dropna() / scale).sort_values(ascending=False)
    print(f"\n{label}  (n={len(s)}, median={s.median():.1f})")
    print("  Highest:", [(NAME[c], round(v, 1)) for c, v in s.head(n).items()])
    print("  Lowest :", [(NAME[c], round(v, 1)) for c, v in s.tail(n)[::-1].items()])

rank_table(D, "Debt stock ($bn)", scale=1e9)
rank_table(GN, "Debt / GNI (%)")
rank_table(EX, "Debt / exports (%)")
rank_table(TDSX, "Debt service / exports (%)")
rank_table(INTGN, "Interest / GNI (%)")

g, t = a[GN].dropna(), a[TDSX].dropna()
print(f"\nDebt/GNI > 60%: {(g > 60).sum()} of {len(g)} | > 100%: {(g > 100).sum()}")
print(f"Debt service/exports > 20%: {(t > 20).sum()} of {len(t)}")

# --------------------------------------------------------------------------
# 5. Trends over time
# --------------------------------------------------------------------------
yr = act.groupby(level="year")[[D, TDS, INT, NFL]].sum() / 1e9
yr["debt_ex_china"] = act.drop("CHN", level=0)[D].groupby(level="year").sum() / 1e9
med = act.groupby(level="year")[[GN, EX, TDSX]].median()
print("\nAggregate trend ($bn) and median ratios:")
print(pd.concat([yr, med], axis=1).loc[[2000, 2005, 2010, 2015, 2020, 2024]].round(1))

n_years = LAST - 2000
cagr = (yr[D][LAST] / yr[D][2000]) ** (1 / n_years) - 1
cagr_x = (yr.debt_ex_china[LAST] / yr.debt_ex_china[2000]) ** (1 / n_years) - 1
print(f"\nGrowth 2000-{LAST}: {yr[D][LAST]/yr[D][2000]:.1f}x | CAGR {cagr:.1%} (ex-China {cagr_x:.1%})")

d = act[D].unstack(0)
c = ((d.loc[LAST] / d.loc[2010]) ** (1 / 14) - 1).dropna().sort_values()
print("Fastest growth 2010-24 (%/yr):", [(NAME[k], round(v * 100, 1)) for k, v in c.tail(5)[::-1].items()])

gr = act[GN].unstack(0)
chg = (gr.loc[LAST] - gr.loc[2019]).dropna().sort_values()
print(f"Debt/GNI up since 2019 in {(chg > 0).sum()} of {len(chg)} countries")
print("  Largest rises :", [(NAME[k], round(v, 1)) for k, v in chg.tail(5)[::-1].items()])
print("  Largest falls :", [(NAME[k], round(v, 1)) for k, v in chg.head(5).items()])

# Composition of debt (% of total stock); PPG = multilateral + bilateral + bonds + other PPG
def tot(col): return act[col].groupby(level="year").sum()
comp = pd.DataFrame({
    "Multilateral (PPG)": tot("DT.DOD.MLAT.CD"),
    "Bilateral (PPG)": tot("DT.DOD.BLAT.CD"),
    "Bonds (PPG)": tot("DT.DOD.PBND.CD"),
})
comp["Other PPG"] = tot("DT.DOD.DPPG.CD") - comp.sum(axis=1)
comp["Private non-guaranteed"] = tot("DT.DOD.PRVS.CD")
comp["IMF credit"] = tot("DT.DOD.DIMF.CD")
comp["Short-term"] = tot("DT.DOD.DSTC.CD")
comp_pct = comp.div(tot(D), axis=0) * 100
print("\nComposition (% of total stock):")
print(comp_pct.loc[[2000, 2010, 2015, 2020, 2024]].round(1))

# Scheduled debt service on EXISTING debt (no new borrowing assumed after 2024)
sched = p[TDS].groupby(level="year").sum() / 1e9
print("\nDebt service $bn (2025+ is scheduled on existing debt only):")
print(sched.loc[2022:2032].round(0).to_string())

# --------------------------------------------------------------------------
# 6. Statistical summaries and relationships
# --------------------------------------------------------------------------
X = pd.DataFrame({
    "log10 stock": np.log10(a[D]),
    "Debt/GNI": a[GN],
    "Debt/Exports": a[EX],
    "DebtServ/Exports": a[TDSX],
    "Interest/GNI": a[INTGN],
    "Short-term %": a[STS],
    "Concessional %": a[CONC],
    "Multilateral %": a[MLAT],
    "USD share %": a["DT.CUR.USDL.ZS"],
    "Interest/stock %": a[INT] / a[D] * 100,
    "IMF share %": a["DT.DOD.DIMF.CD"] / a[D] * 100,
})
print("\nSummary statistics (2024):")
print(X.describe().T[["count", "mean", "50%", "std", "min", "max"]].round(1))
print("\nSkewness:", X.skew().round(1).to_dict())

corr = X.corr(method="spearman")  # rank-based: robust to heavy skew/outliers
print("\nSpearman correlation matrix:")
print(corr.round(2))

def spearman(x, y):
    dd = X[[x, y]].dropna()
    r, pv = stats.spearmanr(dd[x], dd[y])
    return f"rho={r:.2f}, p={pv:.4f}, n={len(dd)}"

print("\nKey pairs:")
for x, y in [("Debt/GNI", "Interest/GNI"), ("Concessional %", "Interest/stock %"),
             ("Concessional %", "DebtServ/Exports"), ("Concessional %", "Debt/GNI"),
             ("Short-term %", "DebtServ/Exports"), ("Debt/Exports", "DebtServ/Exports"),
             ("log10 stock", "Debt/GNI")]:
    print(f"  {x} vs {y}: {spearman(x, y)}")

# Group comparisons
print("\nRegional medians (2024):")
reg = a.groupby("region").agg(n=(D, "size"), debt_bn=(D, lambda s: s.sum() / 1e9),
                              med_debt_GNI=(GN, "median"), med_debt_exports=(EX, "median"),
                              med_service_exports=(TDSX, "median"), med_concessional=(CONC, "median"))
reg["share_%"] = reg.debt_bn / reg.debt_bn.sum() * 100
print(reg.round(1))

for col, lab in [(GN, "Debt/GNI"), (TDSX, "Debt service/exports"), (CONC, "Concessional share")]:
    h, pv = stats.kruskal(*[g_[col].dropna() for _, g_ in a.groupby("region")])
    print(f"  Kruskal-Wallis across regions, {lab}: H={h:.2f}, p={pv:.4g}")

a["conc_tercile"] = pd.qcut(a[CONC], 3, labels=["low", "mid", "high"], duplicates="drop")
print("\nMedians by concessional-share tercile:")
print(a.groupby("conc_tercile", observed=True)[[GN, EX, TDSX, INTGN]].median().round(1))

a["size_quartile"] = pd.qcut(a[D], 4, labels=["Q1 small", "Q2", "Q3", "Q4 large"])
print("\nMedians by debt-size quartile:")
print(a.groupby("size_quartile", observed=True)[[GN, EX, TDSX, INTGN]].median().round(1))

# Paired change over time: same countries, Wilcoxon signed-rank
for col, y0, lab in [(GN, 2010, "Debt/GNI"), (TDSX, 2012, "Debt service/exports")]:
    w = act[col].unstack(0).loc[[y0, LAST]].dropna(axis=1)
    stat, pv = stats.wilcoxon(w.loc[y0], w.loc[LAST])
    print(f"\n{lab} {y0} vs {LAST} (n={w.shape[1]}): median {w.loc[y0].median():.1f} -> "
          f"{w.loc[LAST].median():.1f}, Wilcoxon p={pv:.2g}")

# --------------------------------------------------------------------------
# 7. Charts
# --------------------------------------------------------------------------
fig, ax = plt.subplots(3, 2, figsize=(15, 16))
ax = ax.ravel()

s = stock.head(10)[::-1]
ax[0].barh([NAME[c] for c in s.index], s / 1e9, color=BLUE)
for i, v in enumerate(s / 1e9):
    ax[0].text(v + 20, i, f"${v:,.0f}bn", va="center", fontsize=9)
ax[0].set_xlim(0, s.max() / 1e9 * 1.15)
ax[0].set_title(f"Top 10 by external debt stock, {LAST}")

gg = a[GN].dropna().sort_values(ascending=False).head(10)[::-1]
ax[1].barh([NAME[c] for c in gg.index], gg, color=RED)
for i, v in enumerate(gg):
    ax[1].text(v + 3, i, f"{v:.0f}%", va="center", fontsize=9)
ax[1].set_xlim(0, gg.max() * 1.15)
ax[1].set_title(f"Top 10 by debt as % of GNI, {LAST}")

ax[2].plot(yr.index, yr[D] / 1e3, color=BLUE, lw=2.5, label="All 120 countries")
ax[2].plot(yr.index, yr.debt_ex_china / 1e3, color=GREY, lw=2, ls="--", label="Excluding China")
ax[2].set_ylim(0)
ax[2].legend(frameon=False)
ax[2].set_title("Total external debt stock ($ trillion)")

ax[3].plot(med.index, med[GN], color=BLUE, lw=2.5)
ax[3].set_ylabel("Median debt / GNI (%)", color=BLUE)
ax[3].set_ylim(0)
tw = ax[3].twinx()
tw.plot(med.index, med[TDSX], color=RED, lw=2.5)
tw.set_ylabel("Median debt service / exports (%)", color=RED)
tw.set_ylim(0)
tw.spines["right"].set_visible(True)
ax[3].set_title("Median burden ratios")

ax[4].stackplot(comp_pct.index, comp_pct.T.values, labels=comp_pct.columns,
                colors=["#1f4e79", "#6fa8dc", "#c0504d", "#d9d9d9", "#f6b26b", "#93c47d", "#555555"])
ax[4].legend(loc="upper center", bbox_to_anchor=(0.5, -0.08), fontsize=8, ncol=4, frameon=False)
ax[4].set_ylim(0, 100)
ax[4].set_title("Composition of external debt (% of total stock)")

sch = sched.loc[2019:]
ax[5].bar(sch.index, sch, color=[BLUE if i <= LAST else GREY for i in sch.index])
ax[5].set_ylabel("$ bn")
ax[5].set_title("Debt service: actual to 2024, scheduled on existing debt after")
plt.tight_layout()
plt.savefig(f"{OUT}/debt_overview.png", dpi=130)
plt.close()

fig, ax = plt.subplots(1, 3, figsize=(17, 5.5))
dd = a[[GN, INTGN]].dropna()
ax[0].scatter(dd[GN], dd[INTGN], c=BLUE, alpha=0.7, s=28)
ax[0].set_xscale("log"); ax[0].set_yscale("log")
ax[0].set_xlabel("Debt / GNI (%)"); ax[0].set_ylabel("Interest / GNI (%)")
ax[0].set_title("Debt vs interest burden")
for code in ["MOZ", "MNG", "SEN", "UKR", "ZMB", "LAO"]:
    if code in dd.index:
        ax[0].annotate(NAME[code], (dd.loc[code, GN], dd.loc[code, INTGN]), fontsize=8,
                       xytext=(4, 3), textcoords="offset points")

ax[1].scatter(X["Concessional %"], X["Interest/stock %"], c=RED, alpha=0.7, s=28)
ax[1].set_xlabel("Concessional share of debt (%)"); ax[1].set_ylabel("Interest paid / debt stock (%)")
ax[1].set_title("Concessional lending vs interest cost")

hm_cols = ["Debt/GNI", "Debt/Exports", "DebtServ/Exports", "Interest/GNI",
           "Short-term %", "Concessional %", "Multilateral %", "IMF share %"]
cm = corr.loc[hm_cols, hm_cols]
ax[2].imshow(cm, cmap="RdBu_r", vmin=-1, vmax=1)
ax[2].set_xticks(range(len(hm_cols))); ax[2].set_xticklabels(hm_cols, rotation=45, ha="right", fontsize=8)
ax[2].set_yticks(range(len(hm_cols))); ax[2].set_yticklabels(hm_cols, fontsize=8)
for i in range(len(hm_cols)):
    for j in range(len(hm_cols)):
        ax[2].text(j, i, f"{cm.iloc[i, j]:.2f}", ha="center", va="center", fontsize=7)
ax[2].set_title(f"Spearman correlations, {LAST}")
ax[2].spines[:].set_visible(False)
plt.tight_layout()
plt.savefig(f"{OUT}/debt_relationships.png", dpi=130)
plt.close()

print(f"\nSaved charts to {OUT}/debt_overview.png and {OUT}/debt_relationships.png")

#indicator_lookup
# ===== CELL 1: settings (edit these 2 lines only) =====
DATA_PATH   = r""            # e.g. r"C:\International_Debt Analysis System\Data\ids_data.csv"  (leave "" to auto-search)
LOOKUP_PATH = r"ids_indicator_lookup.csv"
OUT_DIR     = "debt_output"  # directory to save outputs (will be created if it doesn't exist)

# ===== CELL 2: analysis (run as-is) =====
import re
from pathlib import Path
import numpy as np, pandas as pd, seaborn as sns
import matplotlib.pyplot as plt
from scipy import stats
sns.set_theme(style="whitegrid")
out = Path(OUT_DIR); out.mkdir(exist_ok=True)

# --- 1. find the data file -------------------------------------------------
if not DATA_PATH:
    roots = [Path("."), Path(".."), Path.home() / "Downloads", Path.home() / "Documents"]
    found = [f for r in roots if r.exists() for f in r.rglob("*.csv")
             if "lookup" not in f.name.lower() and f.stat().st_size > 200_000]
    if not found:
        raise SystemExit("Main IDS data CSV not found. Set DATA_PATH in Cell 1.")
    DATA_PATH = str(max(found, key=lambda f: f.stat().st_size))
print("Using data file:", DATA_PATH)

# --- 2. load + tidy --------------------------------------------------------
ALIAS = {"country": ["country name", "country", "economy"],
         "indicator_code": ["series code", "indicator_code", "indicator code"],
         "counterpart": ["counterpart-area name", "counterpart area", "counterpart"],
         "year": ["year", "time"], "value": ["value", "obs_value"]}
raw = pd.read_csv(DATA_PATH, low_memory=False, na_values=["..", "", "NA"])
low = {c.lower().strip(): c for c in raw.columns}
raw = raw.rename(columns={low[o]: k for k, v in ALIAS.items() for o in v if o in low})
ycols = [c for c in raw.columns if re.fullmatch(r"(19|20)\d{2}(\s*\[YR\d{4}\])?", str(c).strip())]
if ycols:
    raw = raw.melt(id_vars=[c for c in raw.columns if c not in ycols], value_vars=ycols,
                   var_name="year", value_name="value")
    raw["year"] = raw["year"].astype(str).str.extract(r"((?:19|20)\d{2})")[0]
if "country" not in raw.columns and "country_code" in raw.columns:
    raw["country"] = raw["country_code"]          # file has codes only
need = {"country", "indicator_code", "year", "value"} - set(raw.columns)
if need:
    raise SystemExit(f"Missing columns {need}. Your columns: {list(raw.columns)}")
if "counterpart" in raw.columns:
    raw = raw[raw["counterpart"].astype(str).str.lower().isin(["world", "all", "nan"])]
raw["year"] = pd.to_numeric(raw["year"], errors="coerce")
raw["value"] = pd.to_numeric(raw["value"], errors="coerce")
raw = raw.dropna(subset=["year", "value"]); raw["year"] = raw["year"].astype(int)
AGG = re.compile(r"income|region|IDA|IBRD|world|countries|developing|Sub-Saharan|Asia|Europe|"
                 r"Latin America|Middle East|North Africa|Caribbean|Pacific|Fragile|Heavily|"
                 r"Least developed|Small states|Arab|OECD|Euro area|members|total|blend|only", re.I)
AGG_CODES = set("WLD LMY LIC MIC LMC UMC HIC EAS EAP ECS ECA LCN LAC MEA MNA SAS SSF SSA AFE AFW ARB CEB CSS EAR EMU EUU FCS HPC IBD IBT IDA IDB IDX LDC LTE NAC OED OSS PRE PSS PST SST TEA TEC TLA TMN TSA TSS INX".split())
df = raw[~raw["country"].astype(str).str.contains(AGG) & ~raw["country"].astype(str).isin(AGG_CODES)]
print(f"{len(df):,} rows | {df.country.nunique()} countries | {df.year.min()}-{df.year.max()}")

# --- 3. key indicators -----------------------------------------------------
KEY = {"total_debt": "DT.DOD.DECT.CD", "debt_gni": "DT.DOD.DECT.GN.ZS",
       "debt_exports": "DT.DOD.DECT.EX.ZS", "service_exports": "DT.TDS.DECT.EX.ZS",
       "interest_gni": "DT.INT.DECT.GN.ZS", "short_term_pct": "DT.DOD.DSTC.ZS",
       "multilateral": "DT.DOD.MLAT.ZS", "concessional": "DT.DOD.ALLC.ZS",
       "reserves_debt": "FI.RES.TOTL.DT.ZS"}
inv = {v: k for k, v in KEY.items()}
sub = df[df.indicator_code.isin(KEY.values())].sort_values("year")
latest = (sub.groupby(["country", "indicator_code"]).tail(1)
             .pivot(index="country", columns="indicator_code", values="value").rename(columns=inv))
latest.to_csv(out / "latest_country_indicators.csv")
print("Indicators found:", list(latest.columns))

# --- 4. top / bottom countries --------------------------------------------
for col, label in [("total_debt", "Total external debt (US$)"),
                   ("debt_gni", "Debt (% of GNI)"), ("service_exports", "Debt service (% of exports)")]:
    if col in latest:
        s = latest[col].dropna().sort_values(ascending=False)
        print(f"\n--- {label}: TOP 10 ---\n{s.head(10).to_string()}")
        print(f"\n--- {label}: BOTTOM 10 ---\n{s.tail(10).to_string()}")
        fig, ax = plt.subplots(1, 2, figsize=(14, 5))
        s.head(10)[::-1].plot.barh(ax=ax[0], color="firebrick", title="Highest")
        s.tail(10)[::-1].plot.barh(ax=ax[1], color="seagreen", title="Lowest")
        fig.suptitle(label); plt.tight_layout(); fig.savefig(out / f"rank_{col}.png", dpi=130); plt.show()

# --- 5. distribution + summary statistics ---------------------------------
desc = latest.describe(percentiles=[.25, .5, .75, .9]).T
desc["skew"] = latest.skew(); desc["cv"] = desc["std"] / desc["mean"]
print("\n--- Summary statistics ---\n", desc.round(2).to_string()); desc.to_csv(out / "summary_stats.csv")
if "total_debt" in latest:
    s = latest.total_debt.dropna(); x = np.sort(s.values); n = len(x)
    print(f"\nTop-10 share of total debt: {s.nlargest(10).sum()/s.sum()*100:.1f}%")
    print(f"Gini of debt distribution: {(2*np.sum(np.arange(1,n+1)*x)/(n*x.sum()))-(n+1)/n:.3f}")
    fig, ax = plt.subplots(1, 2, figsize=(13, 4.5))
    sns.histplot(np.log10(s[s > 0]), bins=30, kde=True, ax=ax[0]); ax[0].set_title("log10 total debt")
    sns.boxplot(x=s / 1e9, ax=ax[1]); ax[1].set_xscale("log"); ax[1].set_title("US$ bn (log)")
    plt.tight_layout(); fig.savefig(out / "distribution.png", dpi=130); plt.show()

# --- 6. relationships ------------------------------------------------------
corr = latest.corr(method="spearman")
fig, ax = plt.subplots(figsize=(9, 7))
sns.heatmap(corr, annot=True, fmt=".2f", cmap="RdBu_r", center=0, ax=ax)
ax.set_title("Spearman correlations"); plt.tight_layout(); fig.savefig(out / "correlations.png", dpi=130); plt.show()
rows = []
for a, b in [("debt_gni", "reserves_debt"), ("short_term_pct", "service_exports"),
             ("debt_exports", "service_exports"), ("concessional", "debt_gni")]:
    if a in latest and b in latest:
        d = latest[[a, b]].dropna()
        if len(d) > 5:
            r, p = stats.spearmanr(d[a], d[b]); rows.append(dict(x=a, y=b, n=len(d), rho=r, p=p))
if rows: print("\n--- Pairwise tests ---\n", pd.DataFrame(rows).round(4).to_string(index=False))

# --- 7. trends -------------------------------------------------------------
t = df[df.indicator_code == KEY["total_debt"]].pivot_table(index="year", columns="country", values="value")
if not t.empty:
    g = t.sum(axis=1)
    print("\n--- Aggregate debt (US$ bn) & YoY % ---\n",
          pd.DataFrame({"US$bn": g/1e9, "yoy_%": g.pct_change()*100}).tail(10).round(1).to_string())
    last = t.index.max()
    if last - 10 in t.index:
        cagr = (((t.loc[last] / t.loc[last-10]) ** 0.1 - 1) * 100).replace([np.inf, -np.inf], np.nan).dropna()
        print(f"\n--- Fastest growing debtors, CAGR {last-10}-{last} ---\n{cagr.nlargest(10).round(1).to_string()}")
    fig, ax = plt.subplots(1, 2, figsize=(14, 5))
    (g/1e12).plot(ax=ax[0], title="Total external debt (US$ tn)")
    (t[t.loc[last].nlargest(5).index]/1e9).plot(ax=ax[1], title="Top 5 debtors (US$ bn)")
    plt.tight_layout(); fig.savefig(out / "trends.png", dpi=130); plt.show()

# --- 8. comparison by debt-size quartile ----------------------------------
if "total_debt" in latest:
    d = latest.dropna(subset=["total_debt"]).copy()
    d["tier"] = pd.qcut(d.total_debt, 4, labels=["Q1 low", "Q2", "Q3", "Q4 high"])
    cols = [c for c in ["debt_gni", "service_exports", "short_term_pct", "concessional", "reserves_debt"] if c in d]
    print("\n--- Median by debt-size quartile ---\n", d.groupby("tier", observed=True)[cols].median().round(1).to_string())
    for c in cols:
        gs = [g[c].dropna() for _, g in d.groupby("tier", observed=True)]
        if all(len(g) > 2 for g in gs):
            h, p = stats.kruskal(*gs); print(f"Kruskal-Wallis {c}: H={h:.2f}, p={p:.4f}")
print("\nDone. Files saved in:", out.resolve())
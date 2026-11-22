import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 1. Page & Seaborn Global Theme Configuration
st.set_page_config(page_title="International Debt Analysis (Seaborn)", layout="wide")
sns.set_theme(style="whitegrid", palette="deep")

st.title("🌍 International Debt Analysis System")

# 2. Connect to MySQL (debt_db)
conn = st.connection("mysql", type="sql")

# Helper to find exact column names in your MySQL tables
@st.cache_data(ttl=600)
def get_schema_info():
    c_sample = conn.query("SELECT * FROM countries LIMIT 1;")
    i_sample = conn.query("SELECT * FROM indicators LIMIT 1;")
    d_sample = conn.query("SELECT * FROM ids_debt_long LIMIT 1;")
    return c_sample.columns.tolist(), i_sample.columns.tolist(), d_sample.columns.tolist()

c_cols, i_cols, d_cols = get_schema_info()

def find_col(cols, candidates, fallback_idx=0):
    for col in cols:
        if col.lower().strip().replace(" ", "_") in candidates:
            return col
    for col in cols:
        for cand in candidates:
            if cand in col.lower().strip().replace(" ", "_"):
                return col
    return cols[fallback_idx] if len(cols) > abs(fallback_idx) else cols

c_code_debt = find_col(d_cols, ["country_code", "countrycode", "iso3"], 0)
c_code_ref  = find_col(c_cols, ["country_code", "countrycode", "iso3"], 0)
c_name_ref  = find_col(c_cols, ["country_name", "countryname", "short_name", "table_name", "country", "name"], -1)

i_code_debt = find_col(d_cols, ["indicator_code", "indicatorcode", "series_code"], 1)
i_code_ref  = find_col(i_cols, ["indicator_code", "indicatorcode", "series_code"], 0)
i_name_ref  = find_col(i_cols, ["indicator_name", "indicatorname", "series_name", "indicator", "description", "name"], -1)

year_col    = find_col(d_cols, ["year", "years", "date", "time"], 2)
val_col     = find_col(d_cols, ["value", "debt", "amount", "debt_value", "val"], -1)

# 3. Load Full Lookup Lists (Countries A-Z, All Indicators, All Years)
@st.cache_data(ttl=600)
def load_filters():
    countries = conn.query("SELECT * FROM countries;")
    indicators = conn.query("SELECT * FROM indicators;")
    years_df = conn.query(f"SELECT DISTINCT `{year_col}` FROM ids_debt_long ORDER BY `{year_col}`;")
    return countries, indicators, years_df[year_col].dropna().tolist()

df_countries, df_indicators, all_years = load_filters()

# Create mapping dictionaries for fast lookup
country_map = dict(zip(df_countries[c_code_ref], df_countries[c_name_ref])) if c_name_ref in df_countries.columns else {}
indicator_map = dict(zip(df_indicators[i_code_ref], df_indicators[i_name_ref])) if i_name_ref in df_indicators.columns else {}

# Reverse map from Name -> Code for SQL filtering
ind_name_to_code = {v: k for k, v in indicator_map.items()} if indicator_map else {}

# 4. Sidebar Filters (Now includes ALL countries A-Z!)
st.sidebar.header("🔍 Filter Analysis")

all_indicator_names = sorted(list(indicator_map.values())) if indicator_map else sorted(df_indicators[i_code_ref].dropna().unique())
selected_indicator_name = st.sidebar.selectbox("Select Debt Indicator", all_indicator_names)
selected_indicator_code = ind_name_to_code.get(selected_indicator_name, selected_indicator_name)

all_country_names = sorted(df_countries[c_name_ref].dropna().unique()) if c_name_ref in df_countries.columns else sorted(df_countries[c_code_ref].dropna().unique())
default_countries = [c for c in ["India", "China", "Brazil", "Indonesia", "Mexico"] if c in all_country_names]
if not default_countries:
    default_countries = all_country_names[:5]

selected_countries = st.sidebar.multiselect(
    "Select Countries (A–Z)",
    all_country_names,
    default=default_countries
)

selected_year = st.sidebar.select_slider("Select Year", options=all_years, value=all_years[-1])

# 5. Query MySQL specifically for the selected Indicator & Year (fast & complete!)
@st.cache_data(ttl=600)
def query_indicator_data(ind_code):
    q = f"SELECT * FROM ids_debt_long WHERE `{i_code_debt}` = :ind_code;"
    df = conn.query(q, params={"ind_code": ind_code})
    df[val_col] = pd.to_numeric(df[val_col], errors="coerce")
    df = df.dropna(subset=[val_col])
    df["Country"] = df[c_code_debt].map(country_map).fillna(df[c_code_debt])
    df["Indicator"] = df[i_code_debt].map(indicator_map).fillna(df[i_code_debt])
    return df

@st.cache_data(ttl=600)
def query_year_all_indicators(yr):
    q = f"""
        SELECT `{i_code_debt}`, SUM(`{val_col}`) AS total_debt
        FROM ids_debt_long
        WHERE `{year_col}` = :yr
        GROUP BY `{i_code_debt}`
        ORDER BY total_debt DESC
        LIMIT 10;
    """
    df = conn.query(q, params={"yr": yr})
    df["Indicator"] = df[i_code_debt].map(indicator_map).fillna(df[i_code_debt])
    return df

df_ind_filtered = query_indicator_data(selected_indicator_code)
df_country_filtered = df_ind_filtered[df_ind_filtered["Country"].isin(selected_countries)]
df_year_filtered = df_ind_filtered[df_ind_filtered[year_col] == selected_year]

# 6. KPI Summary Row
col1, col2, col3 = st.columns(3)
col1.metric("Total Countries (A–Z)", len(all_country_names))
col2.metric("Total Indicators", len(all_indicator_names))
col3.metric(f"Global Total for Indicator ({selected_year})", f"${df_year_filtered[val_col].sum():,.0f}")

st.divider()

# 7. Dashboard Tabs
tab_country, tab_indicator, tab_data = st.tabs([
    "📊 Country-Wise Analysis",
    "📈 Indicator-Wise Analysis",
    "🗄️ Filtered Data Preview"
])

# --- TAB 1: COUNTRY-WISE SEABORN CHARTS ---
with tab_country:
    c1, c2 = st.columns(2)

    with c1:
        st.subheader(f"Top 10 Countries ({selected_year})")
        top10 = (
            df_year_filtered.groupby("Country", as_index=False)[val_col]
            .sum()
            .sort_values(by=val_col, ascending=False)
            .head(10)
        )
        fig1, ax1 = plt.subplots(figsize=(8, 5))
        sns.barplot(
            data=top10,
            x=val_col,
            y="Country",
            hue="Country",
            palette="Blues_r",
            legend=False,
            ax=ax1
        )
        ax1.set_title(f"Top 10 Debtors in {selected_year}")
        ax1.set_xlabel("Debt Value (USD)")
        ax1.set_ylabel("Country")
        sns.despine()
        st.pyplot(fig1)
        plt.close(fig1)

    with c2:
        st.subheader("Historical Trend (Selected Countries)")
        if not df_country_filtered.empty:
            trend_df = (
                df_country_filtered.groupby([year_col, "Country"], as_index=False)[val_col]
                .sum()
                .sort_values(by=year_col)
            )
            fig2, ax2 = plt.subplots(figsize=(8, 5))
            sns.lineplot(
                data=trend_df,
                x=year_col,
                y=val_col,
                hue="Country",
                marker="o",
                linewidth=2.2,
                ax=ax2
            )
            ax2.set_title("Debt Trajectory Over Time")
            ax2.set_xlabel("Year")
            ax2.set_ylabel("Debt Value (USD)")
            ax2.legend(title="Country", bbox_to_anchor=(1.02, 1), loc="upper left")
            sns.despine()
            st.pyplot(fig2)
            plt.close(fig2)
        else:
            st.info("Select at least one country in the sidebar to view historical trends.")

    st.subheader("Country vs. Year Debt Intensity Heatmap")
    if not df_country_filtered.empty:
        pivot_df = df_country_filtered.pivot_table(
            index="Country", columns=year_col, values=val_col, aggfunc="sum"
        )
        fig3, ax3 = plt.subplots(figsize=(14, 4))
        sns.heatmap(pivot_df, cmap="YlOrRd", linewidths=0.5, ax=ax3)
        ax3.set_title(f"Heatmap: {selected_indicator_name}")
        ax3.set_xlabel("Year")
        ax3.set_ylabel("Country")
        st.pyplot(fig3)
        plt.close(fig3)

# --- TAB 2: INDICATOR-WISE SEABORN CHARTS ---
with tab_indicator:
    i1, i2 = st.columns(2)

    with i1:
        st.subheader(f"Top 10 Indicators Overall ({selected_year})")
        top_ind = query_year_all_indicators(selected_year)
        top_ind["short_ind"] = top_ind["Indicator"].astype(str).str.slice(0, 38) + "..."

        fig4, ax4 = plt.subplots(figsize=(8, 5))
        sns.barplot(
            data=top_ind,
            x="total_debt",
            y="short_ind",
            hue="short_ind",
            palette="viridis",
            legend=False,
            ax=ax4
        )
        ax4.set_title(f"Highest Debt Indicators in {selected_year}")
        ax4.set_xlabel("Total Debt (USD)")
        ax4.set_ylabel("Indicator")
        sns.despine()
        st.pyplot(fig4)
        plt.close(fig4)

    with i2:
        st.subheader("Debt Distribution Across Selected Countries")
        if not df_country_filtered.empty:
            fig5, ax5 = plt.subplots(figsize=(8, 5))
            sns.boxplot(
                data=df_country_filtered,
                x=val_col,
                y="Country",
                hue="Country",
                palette="Set2",
                legend=False,
                ax=ax5
            )
            ax5.set_title("Multi-Year Debt Spread per Country")
            ax5.set_xlabel("Debt Value (USD)")
            ax5.set_ylabel("Country")
            sns.despine()
            st.pyplot(fig5)
            plt.close(fig5)
        else:
            st.info("Select countries in the sidebar to view distribution.")

# --- TAB 3: RAW DATA ---
with tab_data:
    st.dataframe(df_ind_filtered.head(5000), use_container_width=True)

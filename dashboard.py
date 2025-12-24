import streamlit as st
import pandas as pd
import sqlite3
import plotly.express as px

def load_validated_data():
    conn = sqlite3.connect("zeronorth_fleet.db")
    df = pd.read_sql_query("SELECT * FROM verified_reports", conn)
    conn.close()
    return df

st.set_page_config(page_title="ZeroNorth AI Auditor", layout="wide")
st.title("ZeroNorth: AI-Verified Decarbonization Dashboard")

df = load_validated_data()

if not df.empty:
    total_tax = df['Tax_Bill_EUR'].sum()
    total_co2 = df['CO2_Emissions'].sum()
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Total Fleet Tax", f"€{total_tax:,.2f}")
    col2.metric("Total CO2 (Verified)", f"{total_co2:,.1f} mt")
    col3.metric("Ships on Chain", len(df))

    
    fig = px.scatter(df, 
                     x="Vessel_Name", 
                     y="CO2_Emissions",
                     size="Tax_Bill_EUR", 
                     color="Grade",
                     text="Grade",
                     title="CII Grade vs. Tax Liability (Bubble Size = Euro Cost)",
                     color_discrete_map={'A':'green', 'B':'lightgreen', 'C':'yellow', 'D':'orange', 'E':'red'},
                     category_orders={"Grade": ["A", "B", "C", "D", "E"]})

    fig.update_traces(textposition='top center')  
    st.plotly_chart(fig, use_container_width=True)

    st.subheader("Llama Audit Logs")
    st.dataframe(df[['Vessel_Name', 'AI_Status', 'Grade', 'Tax_Bill_EUR']])

else:
    st.error("No data found. Please run the main engine first to validate records.")
    
    
# python3 -m streamlit run dashboard.py

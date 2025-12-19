import pandas as pd
import ollama
import logging
import sqlite3
import os
import json
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_defunct
import time
import requests

load_dotenv()

logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class ZeroNorthDecarbonizationEngine:
    def __init__(self, model="tinyllama", db_name="zeronorth_fleet.db"):
        self.model = model
        self.db_name = db_name
        self.carbon_tax_rate = 85  
        self.emission_factor = 3.114
        
        self.w3 = Web3(Web3.HTTPProvider(os.getenv("RPC_URL")))
        
        self.private_key = os.getenv("PRIVATE_KEY")
        self.account = Account.from_key(self.private_key)
        self.contract_address = os.getenv("CONTRACT_ADDRESS")
        self.tg_token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.tg_chat_id = os.getenv("TELEGRAM_CHAT_ID")
        
        with open(os.getenv("ABI_PATH")) as f:
            artifact = json.load(f)
            self.abi = artifact["abi"]        
        
        self.contract = self.w3.eth.contract(address=self.contract_address, abi=self.abi)
        
        logging.info(f"ZeroNorth Engine Initialized. Model: {self.model} | DB: {self.db_name}")
        self._init_database()

    def _init_database(self):
        try:
            conn = sqlite3.connect(self.db_name)
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS raw_fleet_data (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Vessel_Name TEXT,
                    DWT INTEGER,
                    Distance_Sailed INTEGER,
                    Fuel_Consumed INTEGER
                )
            ''')
            cursor.execute("DELETE FROM raw_fleet_data")
            raw_data = [
                ('Arctic Star', 80000, 15000, 1200),
                # ('Pacific Runner', 50000, 12000, 950),
                # ('Atlantic Giant (Anomaly)', 120000, 18000, 5),
                # ('Indian Breeze', 75000, 10000, 800)
            ]
            cursor.executemany('''
                INSERT INTO raw_fleet_data (Vessel_Name, DWT, Distance_Sailed, Fuel_Consumed)
                VALUES (?, ?, ?, ?)
            ''', raw_data)
            conn.commit()
            conn.close()
            logging.info("Database initialized and seeded.")
        except Exception as e:
            logging.error(f"Database Initialization Error: {e}")

    def load_data_from_db(self):
        try:
            conn = sqlite3.connect(self.db_name)
            df = pd.read_sql_query("SELECT * FROM raw_fleet_data", conn)
            conn.close()
            return df
        except Exception as e:
            logging.error(f"Data Load Error: {e}")
            return pd.DataFrame()
        
    def save_report_to_db(self, report_df):
        """Saves report only if it contains data to prevent schema errors."""
        if report_df is None or report_df.empty:
            logging.warning("No verified data to save to database.")
            return

        try:
            conn = sqlite3.connect(self.db_name)
            report_df[['Vessel_Name', 'AI_Status', 'Grade', 'Tax_Bill_EUR','CO2_Emissions']].to_sql(
                'verified_reports', conn, if_exists='replace', index=False
            )
            conn.commit()
            conn.close()
            logging.info("Final report saved to 'verified_reports' table.")
        except Exception as e:
            logging.error(f"Error saving report: {e}")

    def ai_data_auditor(self, row):
        """Calibrated prompt for higher accuracy with small models."""
        prompt = f"""
        [SYSTEM] You are a Maritime Data Integrity Auditor. 
        [USER] Analyze this report:
        Ship: {row['Vessel_Name']}
        Size: {row['DWT']} DWT
        Voyage: {row['Distance_Sailed']} nm
        Fuel Used: {row['Fuel_Consumed']} metric tons

        CRITICAL LOGIC: 
        A ship of this size usually consumes 20-50 tons of fuel PER DAY. 
        If the total fuel is less than 100 tons for a long voyage (>1000 nm), it is physically IMPOSSIBLE.

        Is this report realistic or is it a sensor error?
        Respond with ONLY one word: 'PASS' if realistic, 'FAIL' if impossible.
        """
        try:
            response = ollama.chat(model=self.model, messages=[{'role': 'user', 'content': prompt}])
            status = response['message']['content'].strip().upper()
            return "FAIL" if "FAIL" in status else "PASS"
        except Exception as e:
            logging.error(f"AI Connection Error: {e}")
            return "AI_OFFLINE"

    def calculate_cii_and_tax(self, df):
        if df.empty:
            return pd.DataFrame()

        logging.info("Step 1: Running AI Validation...")
        df['AI_Status'] = df.apply(self.ai_data_auditor, axis=1)

        valid_df = df[df['AI_Status'] == "PASS"].copy()
        
        if valid_df.empty:
            logging.warning("AI rejected all data as unrealistic.")
            return pd.DataFrame()

        logging.info(f"Step 2: Calculating metrics for {len(valid_df)} vessels.")
        valid_df['CO2_Emissions'] = valid_df['Fuel_Consumed'] * self.emission_factor
        valid_df['CII_Score'] = (valid_df['CO2_Emissions'] * 1e6) / (valid_df['DWT'] * valid_df['Distance_Sailed'])
        valid_df['Tax_Bill_EUR'] = valid_df['CO2_Emissions'] * self.carbon_tax_rate

        def get_imo_grade(score):
            if score < 2.5: return 'A'
            elif score < 3.5: return 'B'
            elif score < 4.5: return 'C'
            elif score < 5.5: return 'D'
            else: return 'E'

        valid_df['Grade'] = valid_df['CII_Score'].apply(get_imo_grade)
        return valid_df
    
    def anchor_report_on_chain(self, vessel_name, co2, grade, user_private_key):
        """Uses the private key provided via Telegram to sign the transaction."""
        temp_account = Account.from_key(user_private_key)
        
        signature = self.generate_signature_with_key(vessel_name, co2, grade, user_private_key)
        
        nonce = self.w3.eth.get_transaction_count(temp_account.address)
        
        tx = self.contract.functions.updateVesselGrade(
            vessel_name, int(co2), grade, signature
        ).build_transaction({
            "from": temp_account.address,
            "nonce": nonce,
            "gas": 300_000,
            "gasPrice": self.w3.to_wei("1", "gwei")
        })

        signed_tx = temp_account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        return receipt

    def generate_signature_with_key(self, vessel_name, co2, grade, pk):
        message_hash = self.w3.solidity_keccak(["string", "uint256", "string"], [vessel_name, int(co2), grade])
        eth_message = encode_defunct(message_hash)
        return Account.sign_message(eth_message, private_key=pk).signature
    
    def send_telegram_message(self, text):
        url = f"https://api.telegram.org/bot{self.tg_token}/sendMessage"
        requests.post(url, data={"chat_id": self.tg_chat_id, "text": text})

    def wait_for_telegram_approval(self, vessel_name, co2, grade):
        """Waits for user to send 'approved <private_key>' in Telegram."""
        self.send_telegram_message(
            f"🔔 AUDIT REQUIRED\nShip: {vessel_name}\nCO2: {co2}mt\nGrade: {grade}\n\n"
            f"Reply with: 'approved <your_private_key>' to anchor to blockchain."
        )
        
        logging.info(f"Waiting for Telegram approval for {vessel_name}...")
        
        while True:
            url = f"https://api.telegram.org/bot{self.tg_token}/getUpdates"
            response = requests.get(url).json()
            
            if response["result"]:
                last_msg = response["result"][-1]["message"]["text"]
                
                if "approved" in last_msg.lower():
                    parts = last_msg.split()
                    if len(parts) > 1:
                        pk = parts[1]
                        self.send_telegram_message(f"🚀 Approval received for {vessel_name}. Processing TX...")
                        return pk
            
            time.sleep(5)

if __name__ == "__main__":
    engine = ZeroNorthDecarbonizationEngine(model="tinyllama") 

    fleet_df = engine.load_data_from_db()
    report = engine.calculate_cii_and_tax(fleet_df)
    
    engine.save_report_to_db(report)
    
    if not report.empty:
        for idx, row in report.iterrows():
            vname, vco2, vgrade = row['Vessel_Name'], row['CO2_Emissions'], row['Grade']

            try:
                provided_pk = engine.wait_for_telegram_approval(vname, vco2, vgrade)
                
                receipt = engine.anchor_report_on_chain(vname, vco2, vgrade, provided_pk)
                engine.send_telegram_message(f"Confirmed: {vname} in block {receipt.blockNumber}")
                
                print(f"Confirmed: {vname} in block {receipt.blockNumber}")
            except Exception as e:
                logging.error(f"Sync Failed: {e}")

    print("\n" + "="*60)
    print("ZERO NORTH VERIFIED EMISSIONS REPORT (FROM SQLITE)")
    print("="*60)
    if report is not None and not report.empty:
        print(report[['Vessel_Name', 'AI_Status', 'Grade', 'Tax_Bill_EUR']])
        total_tax = report['Tax_Bill_EUR'].sum()
        print("-" * 60)
        print(f"FLEET TOTAL TAX LIABILITY: €{total_tax:,.2f}")
    else:
        print("CRITICAL: AI Audit results yielded no valid records.")
    print("="*60)
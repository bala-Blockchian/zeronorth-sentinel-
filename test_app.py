import unittest
import sqlite3
import pandas as pd
from app import ZeroNorthDecarbonizationEngine

class TestZeroNorthEngine(unittest.TestCase):
    def setUp(self):
        self.db_name = "zeronorth_fleet.db"
        self.engine = ZeroNorthDecarbonizationEngine(model="phi3", db_name=self.db_name)

    def test_co2_calculation(self):
        """Test the mathematical constant for fuel to CO2 conversion."""
        fuel = 1000
        expected_co2 = 3114.0
        calculated_co2 = fuel * self.engine.emission_factor
        self.assertEqual(calculated_co2, expected_co2)

    def test_tax_calculation(self):
        """Test the carbon tax logic based on CO2 volume."""
        co2 = 3114
        expected_tax = 264690.0
        calculated_tax = co2 * self.engine.carbon_tax_rate
        self.assertEqual(calculated_tax, expected_tax)
        
    def test_database_persistence(self):
        """Verify that dataframes are correctly mapped to SQL tables."""
        data = {'Vessel_Name': ['Test Ship'], 'AI_Status': ['PASS'], 'Grade': ['A'], 'Tax_Bill_EUR': [5000.0]}
        df = pd.DataFrame(data)
        
        self.engine.save_report_to_db(df)
        
        conn = sqlite3.connect(self.db_name)
        db_data = pd.read_sql_query("SELECT * FROM verified_reports", conn)
        conn.close()
        
        self.assertEqual(len(db_data), 1)
        self.assertEqual(db_data['Vessel_Name'].iloc[0], 'Test Ship')

    def test_ai_anomaly_rejection(self):
        """
        CRITICAL INTEGRATION TEST:
        Ensures the AI Auditor identifies and rejects the fuel anomaly.
        """
        print("\nRunning AI Anomaly Rejection Test...")
        
        raw_df = self.engine.load_data_from_db()
        report = self.engine.calculate_cii_and_tax(raw_df)
        self.engine.save_report_to_db(report)
        
        anomaly_ship = 'Atlantic Giant (Anomaly)'
        is_present = anomaly_ship in report['Vessel_Name'].values
        
        self.assertFalse(is_present, f"FAILURE: {anomaly_ship} passed the AI guardrail but should have been rejected.")
        print(f"SUCCESS: {anomaly_ship} was correctly filtered out.")

if __name__ == "__main__":
    unittest.main()
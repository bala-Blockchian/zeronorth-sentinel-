# Maritime Emissions Audit Engine

How do we trust carbon emission reports? We don't—we verify. 

This project demonstrates an autonomous engine that uses local AI to detect fuel consumption anomalies and a Telegram-based approval system to secure verified maritime data on an immutable blockchain ledger.

## 📺 Live Demo
Watch the system in action, from AI validation to Telegram approval and Blockchain finality:
**[AI & Blockchain for Green Shipping - Watch on YouTube](https://youtu.be/ugOxat6TajQ?si=5QbDHkWktDMJ4rP8)**

## System Flow

1. Data Ingestion
The system loads raw vessel data (DWT, Distance, Fuel) from a local SQLite database.

2. AI Audit Layer
A local LLM (Phi-3) analyzes each vessel record. It acts as a physics-based guardrail, identifying impossible fuel-to-distance ratios (e.g., sensor errors or manual manipulation).

3. Human-in-the-Loop (HITL) Gate
Verified records are sent to a Telegram Bot. The system pauses and waits for an authorized user to provide a signature/approval via a secure chat interface.

4. Blockchain Anchoring
Upon approval, the data is cryptographically signed and broadcasted to a Smart Contract (deployed via Foundry/Anvil). This creates a permanent, transparent audit trail.

## Technology Stack

- AI: Ollama / Phi-3
- Blockchain: Solidity / Foundry / Web3.py
- Database: SQLite / Pandas
- Messaging: Telegram Bot API
- Language: Python 3.9+

## Security Note

Don't worry about the keys on screen—they are just **Anvil test keys**. Never share or commit your real Private Key. Keep it safe!s
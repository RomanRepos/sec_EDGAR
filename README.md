# sec_EDGAR
**SEC EDGAR XBRL Data & Analytics**

A personal portfolio project for downloading, parsing, and analyzing SEC EDGAR financial data.

> This project is currently in the first half of its development. Many features and much of the documentation are still a work in progress.

---

## Data Overview

| Metric | Value |
|---|---|
| Companies covered | ~17,000 |
| Date range | 2010-08-31 to 2026-05-11 |
| Financial Data (Flattened Facts Files) | ~122M rows |
| Taxonomy Cacluclation | ~44M rows |
| Taxonomy Cacluclation Flattened Hierarchy | ~91M rows |
| Key Statements Values & Hierarchy | ~75M rows |
| Filings | ~330,000 |
| Clean Filings | ~220,000 |
---

## ✅ Mostly Developed

- Download XBRL data from EDGAR
- Parse XBRL company facts and submissions into flat tables
- Create dimension tables for SEC entities
- Download Calculation Taxonomies
- Parse and flatten Calculation Taxonomy hierarchies
- Classify XBRL roles into key financial statements (Balance Sheet, Income Statement, Cash Flow Statement)
- Identify submissions where data is clean and numbers reconcile
- Standardization of financial concepts for a sample of clean submissions using an LLM (Claude)

---

## Challenges & Solutions

### Challenge: 
**Solution:**

### Challenge: 
**Solution:**

---

## 🔧 Work in Progress
- Assigning standardized concepts from a sample of filings to filings outside of the sample. 

---

## 📋 To Be Developed

- Detailed documentation
- Organize data extraction and clean up scripts into a consitant data pipeline
- A streamlined pipeline to build EDGAR datasets and analytics using this project
- Storage of standardized metrics, concepts, and ratios
- Grouping of entities by industry, sector, and peer group across time
- Analytics, time-series analysis, and data visualization (Power BI as front end)
- Implement Data Change Capture (CDC) to efficiently ingest new submissions

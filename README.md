# sec_EDGAR
**SEC EDGAR XBRL Data & Analytics**

A personal portfolio project for downloading, parsing, and analyzing SEC EDGAR financial data.

> This project is currently in the first half of its development. Many features and much of the documentation are still a work in progress.

---

## Data Overview

| Metric | Value |
|---|---|
| Companies covered | ~16,000 |
| Date range | 2010-08-31 to 2026-05-11 |
| Financial Data (Flattened Facts Files) | ~122M rows |
| Taxonomy Calculation | ~44M rows |
| Taxonomy Calculation Flattened Hierarchy | ~91M rows |
| Key Statements Values & Hierarchy | ~75M rows |
| Filings | ~390,000 |
| Clean Filings | ~223,000 |
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

### Challenge 1: XBRL Data Lacks Concept Relationships and Statement Context

Raw XBRL facts in EDGAR submissions do not describe how line items relate to one another or which financial statement they belong to.

**Solution:** Every EDGAR submission includes a calculation taxonomy file that defines the hierarchical relationships specific to that filing. Despite being time-consuming to download at scale and imperfect in some cases, this per-submission approach was chosen for its broader coverage and filer-specific accuracy.

---

### Challenge 2: Identifying the Three Key Financial Statements Across Filings

Each calculation taxonomy contains multiple named roles — effectively different views of the data — and role names vary wildly across companies. Reliably identifying the Balance Sheet, Income Statement, and Statement of Cash Flows requires automated classification.

**Solution:** A keyword-based scoring system filters and ranks roles by their name and the number of concepts they contain. The highest-scoring candidate for each statement type is selected. See [queries/DeterminePrimaryStatements.sql](queries/DeterminePrimaryStatements.sql) for the full logic.

---

### Challenge 3: Normalizing Company-Specific Concepts into Standard Metrics

Different companies use different names and structures to represent the same financial items. Normalizing these into consistent, comparable metrics — such as Net Income, Revenue, or Total Assets — is the core analytical challenge of the project.

**Solution:** A representative sample of filings is sent to an LLM (Claude) along with each filing's hierarchical concept structure, allowing the model to infer the correct standard metric for each concept. Running this across all 300,000+ submissions is too costly, so the mappings derived from the sample are extrapolated to the full population by finding the most structurally similar sample match for each unseen filing. Results are promising but imperfect — achieving a reliable mapping at this scale remains an open problem.

---

## 🔧 Work in Progress
- Assigning standardized concepts from a sample of filings to filings outside of the sample. 

---

## 📋 To Be Developed

- Detailed documentation
- Organize data extraction and cleanup scripts into a consistent data pipeline
- A streamlined pipeline to build EDGAR datasets and analytics using this project
- Storage of standardized metrics, concepts, and ratios
- Grouping of entities by industry, sector, and peer group across time
- Analytics, time-series analysis, and data visualization (Power BI as front end)
- Implement Data Change Capture (CDC) to efficiently ingest new submissions

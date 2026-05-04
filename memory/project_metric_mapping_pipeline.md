---
name: Metric Mapping Pipeline Architecture
description: End-to-end design for mapping SEC EDGAR filing concepts to standard financial metrics (EBITDA, FCF, etc.) using Claude API at scale
type: project
---

## Goal
Map company-reported XBRL concepts from SEC filings to standard financial metrics (EBITDA, FCF, Inventory Turnover, etc.). Companies report differently — same underlying metric, different concept names/structures. Claude handles the semantic mapping; code handles the arithmetic.

## Key Data Sources (DuckDB: secFilingsDb.duckdb)

- **`calculationTaxonomyHierarchy`** — 90M+ rows. Transitive closure of XBRL calculation relationships per filing. Key columns: `cik`, `accessionNumber`, `linkRole`, `ancestor`, `descendant`, `relativeDepth`, `arcWeight` (+1/-1 sign), `highestParent`, `lowestChild`, `keyStatementRole` (IncomeStatement / BalanceSheet / CashFlow)
- **`financialData`** — Reported values per concept per filing. Key columns: `cik`, `accessionNumber`, `name` (joins to ancestor/descendant), `value`, `units`, `endDate`, `financialYear`, `financialPeriod`
- **`submissions`** — Filing metadata. Key columns: `cik`, `accessionNumber`, `form` (10-K/10-Q), `reportDate`, `filingDate`

## Core Design Decisions

### 1. Concept Vocabulary (not per-filing mapping)
- us-gaap concepts are standardized — `DepreciationAndAmortization` means the same thing across all filings
- Build a **concept mapping vocabulary** once: `concept → {metric, component_role}`
- For any new filing: join its concepts against vocabulary — no Claude call needed
- Only call Claude for concepts not yet in the vocabulary
- Converges fast — common metric concepts are a small, frequently reused subset of the ~17k us-gaap taxonomy

### 2. Query to build per-filing Claude input
Use `relativeDepth = 1` (direct parent-child only) from `calculationTaxonomyHierarchy`.
Join `financialData` filtered by `submissions.reportDate = financialData.endDate` to get period-correct values.
Include all three statements (IncomeStatement, BalanceSheet, CashFlow) in one table per filing.
Key columns to send Claude: `keyStatementRole`, `parent_concept`, `concept`, `arcWeight`, `value`.
Do NOT include `description` — us-gaap/ifrs-full concept names are sufficient for Claude.
Only use `us-gaap` and `ifrs-full` prefix concepts for metric mapping.

```sql
WITH direct AS (
    SELECT h.keyStatementRole, h.ancestor AS parent_concept, h.descendant AS concept, h.arcWeight
    FROM calculationTaxonomyHierarchy h
    WHERE h.cik = ? AND h.accessionNumber = ? AND h.relativeDepth = 1
),
facts AS (
    SELECT DISTINCT ON (name) name, value, units
    FROM financialData f
    JOIN submissions s ON s.cik = f.cik AND s.accessionNumber = f.accessionNumber
                       AND s.reportDate = f.endDate
    WHERE f.cik = ? AND f.accessionNumber = ? AND f.units = 'USD'
    ORDER BY name, endDate DESC
)
SELECT d.keyStatementRole AS statement, d.parent_concept AS parent,
       d.concept, d.arcWeight AS weight, f.value
FROM direct d
LEFT JOIN facts f ON f.name = d.concept
ORDER BY d.keyStatementRole, d.parent_concept, d.arcWeight DESC
```

### 3. Metric recipes in system prompt
Each metric recipe specifies formula + which statement to find each component in.
Critical rule: D&A for EBITDA is found in CashFlow (non-cash adjustment under NetCashProvidedByUsedInOperatingActivities), NOT IncomeStatement.
CapEx has arcWeight=-1; use absolute value.
Metrics requiring average balances (ROA, ROE, Inventory Turnover, DSO, DPO, DIO, CCC) need two consecutive filings.

### 4. Claude API at scale
- **Batch API** — async, up to 10,000 requests per batch, 50% cost reduction. Submit → store batch_id → poll → retrieve results.
- **Prompt caching** — system prompt (metric recipes) is identical per request; mark with `cache_control: {type: ephemeral}`. Only concept table changes per request.
- **Output** — Claude returns JSON; Python code parses and writes to vocabulary table in DuckDB via read-write connection (separate from read-only MCP server).
- **custom_id** — use `{cik}_{accessionNumber}` for result lookup.

### 5. Vocabulary table schema (to be finalized)
Columns needed: `concept`, `metric`, `component_role`, `source_filing` (audit trail), `confidence`

## Pipeline Phases

### Discovery phase
- Run Claude on a small diverse sample (mix of 10-K/10-Q, industries, filing sizes)
- Populate the concept vocabulary
- Validate mapping quality, iterate on metric recipes before scaling

### Scale phase
1. Query DuckDB → chunk filings into batches of ~5,000
2. For each chunk: submit to Batch API → store batch_id
3. Poll until `processing_status == "ended"`
4. Parse JSON responses → validate schema → write to vocabulary table
5. For subsequent filings: lookup join against vocabulary (no Claude call)

### Ongoing / incremental
- For each new filing: identify unmapped concepts → batch to Claude → extend vocabulary

## Metric Definitions File
`/home/roman/Documents/EDGAR_Analytics/Analytics/financial_metrics.json`
Contains all KPI definitions with formula, component roles, source statements, concept_hints (ordered most-common-first), and requires_average flag.
Categories: Profitability, Liquidity, Leverage, Efficiency, CashFlow, PerShare.

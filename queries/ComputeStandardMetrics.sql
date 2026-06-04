
WITH
-- Filtered standardized concepts — id_set_size precomputed here once per standardLabelID,
-- avoiding array_agg across submissions later.
-- conceptName ∈ standardLabelID by construction, so Jaccard = matched_count / id_set_size.
sc AS (
    SELECT DISTINCT
        sc.conceptName,
        sc.standardLabel,
        sc.standardLabelID,
        sc.conceptsPerStandardLabel,
        sc.confidenceScore,
        len(list_distinct(string_split(sc.standardLabelID, '|'))) AS id_set_size
    FROM standardizedConcepts sc
    INNER JOIN standardLineItems sli ON sli.standardLabel = sc.standardLabel
    WHERE
        sc.standardLabel = ?
        AND sc.confidenceScore >= 2
        AND sc.conceptsPerStandardLabel <= sli.maxComponents
    QUALIFY NOT list_contains(
        list(sc.sign) OVER (
            PARTITION BY sc.cik, sc.accessionNumber, sc.keyStatementRole, sc.standardLabelID
        ),
        '-'
    )
),
-- Raw financial data joined with filtered concepts and submissions
raw_data AS (
    SELECT
        fd.prefix,
        fd.cik,
        fd.accessionNumber,
        fd.name AS conceptName,
        fd.units,
        fd.endDate,
        s.form,
        sc.conceptsPerStandardLabel,
        sc.standardLabel,
        sc.standardLabelID,
        sc.id_set_size,
        sc.confidenceScore,
        fd.value
    FROM financialData fd
    INNER JOIN sc ON sc.conceptName = fd.name
    INNER JOIN submissions s ON
        s.accessionNumber = fd.accessionNumber
        AND fd.cik = s.cik
        AND s.reportDate = fd.endDate
    WHERE
        fd.isPrimarySubmissionDateRange = TRUE
        AND fd.isPrimaryPrefix = TRUE
        AND fd.isPrimaryUnits = TRUE
        AND s.form IN ('10-K', '20-F', '40-F', '10-K/A', '20-F/A', '40-F/A', '10-Q', '10-Q/A')
        AND fd.prefix IN ('us-gaap', 'ifrs-full')
),
-- Aggregate per (submission + label_keys) using scalar counts — no array_agg.
-- id_set_size and confidenceScore are constant per standardLabelID so MAX() carries them through.
concept_agg AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, standardLabelID, conceptsPerStandardLabel, confidenceScore,
        MAX(id_set_size)            AS id_set_size,
        COUNT(DISTINCT conceptName) AS matched_count,
        SUM(value)                  AS total_value
    FROM raw_data
    GROUP BY ALL
),
-- Jaccard = matched_count / id_set_size (valid because conceptName ⊆ id_set by construction)
with_jaccard AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, standardLabelID, conceptsPerStandardLabel, total_value, confidenceScore,
        matched_count * 1.0 / NULLIF(id_set_size, 0) AS similarity
    FROM concept_agg
),
-- Step 1: keep only standardLabelIDs with the best Jaccard similarity per (submission + standardLabel)
best_similarity AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, standardLabelID, conceptsPerStandardLabel, total_value, confidenceScore
    FROM with_jaccard
    QUALIFY similarity = MAX(similarity) OVER (
        PARTITION BY prefix, cik, accessionNumber, form, endDate, units, standardLabel
    )
),
-- Step 2: among similarity ties, keep the standardLabelID with the highest confidence score
best_match AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, conceptsPerStandardLabel, total_value
    FROM best_similarity
    QUALIFY confidenceScore = MAX(confidenceScore) OVER (
        PARTITION BY prefix, cik, accessionNumber, form, endDate, units, standardLabel
    )
),
-- Filter by conceptsPerStandardLabel:
--   exempt labels → keep max components (broadest match)
--   all others    → keep min components (most specific match)
filtered AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, conceptsPerStandardLabel, total_value
    FROM best_match
    QUALIFY (
        standardLabel IN (
            'Intangible Assets', 'Total Debt', 'Cash and Cash Equivalents',
            'Stock-based Compensation',
            'Operating Expenses', 'Research and Development Expenses', 'Total Current Assets',
            'Total Current Liabilities', 'Accounts Payable', 'Current Portion of Long-term Debt',
            'Depreciation and Amortization',
            'Long-term Debt', 'Capital Expenditures', 'Accounts Receivable',
            'Short-term Borrowings', 'Dividends Paid', 'Inventory',
            'Property, Plant and Equipment, Net'
        )
        AND conceptsPerStandardLabel = MAX(conceptsPerStandardLabel) OVER (
            PARTITION BY prefix, cik, accessionNumber, form, endDate, units, standardLabel
        )
    ) OR (
        standardLabel NOT IN (
            'Intangible Assets', 'Total Debt', 'Cash and Cash Equivalents',
           'Stock-based Compensation',
            'Operating Expenses', 'Research and Development Expenses', 'Total Current Assets',
            'Total Current Liabilities', 'Accounts Payable', 'Current Portion of Long-term Debt',
            'Depreciation and Amortization',
            'Long-term Debt', 'Capital Expenditures', 'Accounts Receivable',
            'Short-term Borrowings', 'Dividends Paid', 'Inventory',
            'Property, Plant and Equipment, Net'
        )
        AND conceptsPerStandardLabel = MIN(conceptsPerStandardLabel) OVER (
            PARTITION BY prefix, cik, accessionNumber, form, endDate, units, standardLabel
        )
    )
),
-- Keep the row with the largest absolute value per (submission + standardLabel)
max_per_label AS (
    SELECT
        prefix, cik, accessionNumber, form, endDate, units,
        standardLabel, total_value
    FROM filtered
    QUALIFY ABS(total_value) = MAX(ABS(total_value)) OVER (
        PARTITION BY prefix, cik, accessionNumber, form, endDate, units, standardLabel
    )
)
-- Apply sign rules: allow negative values only for income/flow labels
SELECT
    prefix,
    cik,
    accessionNumber,
    form,
    endDate,
    units,
    standardLabel,
    CASE
        WHEN standardLabel IN (
            'Gross Profit', 'Operating Income', 'Pre-tax Income',
            'Net Income', 'Retained Earnings', 'Operating Cash Flow', 'Interest Income', 'Interest Expense'
        ) THEN total_value
        ELSE ABS(total_value)
    END AS value
FROM max_per_label;

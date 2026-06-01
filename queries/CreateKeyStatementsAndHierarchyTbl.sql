SET max_temp_directory_size = '50GB';
SET threads = 2;
SET memory_limit = '18GB';
CREATE OR REPLACE TABLE keyStatementsValuesAndHierarchy AS

with
    topLevelParentsSum as (
        SELECT
            fd.prefix,
            fd.units,
            cth.cik,
            cth.accessionNumber,
            cth.linkRole,
            cth.keyStatementRole,
            s.form,
            fd.endDate,
            sum(fd.value) highestLevelParentsTotal
        from
            calculationTaxonomyHierarchy cth
            inner join financialData fd on fd.cik = cth.cik
            AND fd.accessionNumber = cth.accessionNumber
            AND fd.name = cth.descendant
            AND cth.relativeDepth = 0
            AND cth.highestParent = TRUE
            AND fd.isPrimaryPrefix = TRUE
            AND fd.isPrimarySubmissionDateRange = TRUE
            and fd.isPrimaryUnits = TRUE
            inner join (
                select distinct
                    cik,
                    accessionNumber,
                    linkRole
                from
                    calculationTaxonomy
                where
                    isPrimaryRole = TRUE
            ) ct ON ct.cik = cth.cik
            AND ct.accessionNumber = cth.accessionNumber
            AND ct.linkRole = cth.linkRole
            INNER JOIN submissions s ON fd.cik = s.cik
            AND fd.accessionNumber = s.accessionNumber
            AND s.reportDate = fd.endDate
            AND s.form in ('10-K', '20-F', '40-F', '10-K/A', '20-F/A', '40-F/A', '10-Q', '10-Q/A')
        GROUP BY
            fd.prefix,
            fd.units,
            cth.cik,
            cth.accessionNumber,
            cth.linkRole,
            cth.keyStatementRole,
            s.form,
            fd.endDate
    ),
    firstLevelNodestSum as (
        SELECT
            fd.prefix,
            fd.units,
            cth.cik,
            cth.accessionNumber,
            cth.linkRole,
            cth.keyStatementRole,
            s.form,
            fd.endDate,
            sum(fd.value * cth.arcWeight) firstLevelNodesTotal
        from
            calculationTaxonomyHierarchy cth
            inner join financialData fd on fd.cik = cth.cik
            AND fd.accessionNumber = cth.accessionNumber
            AND fd.name = cth.descendant
            AND cth.relativeDepth = 1
            AND fd.isPrimaryPrefix = TRUE
            AND fd.isPrimarySubmissionDateRange = TRUE
            and fd.isPrimaryUnits = TRUE
            inner join (
                select distinct
                    cik,
                    accessionNumber,
                    linkRole
                from
                    calculationTaxonomy
                where
                    isPrimaryUnits = TRUE
            ) ct ON ct.cik = cth.cik
            AND ct.accessionNumber = cth.accessionNumber
            AND ct.linkRole = cth.linkRole
            INNER JOIN submissions s ON fd.cik = s.cik
            AND fd.accessionNumber = s.accessionNumber
            AND s.reportDate = fd.endDate
            AND s.form in ('10-K', '20-F', '40-F', '10-K/A', '20-F/A', '40-F/A', '10-Q', '10-Q/A')
            INNER JOIN calculationTaxonomyHierarchy ctht ON ctht.cik = cth.cik
            AND ctht."accessionNumber" = cth."accessionNumber"
            AND cth.ancestor = ctht.ancestor
            AND ctht."relativeDepth" = 0
            AND ctht.highestParent = TRUE
        GROUP BY
            fd.prefix,
            fd.units,
            cth.cik,
            cth.accessionNumber,
            cth.linkRole,
            cth.keyStatementRole,
            s.form,
            fd.endDate
    ),
    subs as (
        select
            DISTINCT
            tlp.prefix,
            tlp.units,
            tlp.cik,
            tlp.accessionNumber,
            tlp.form,
            tlp.endDate,
            count(distinct tlp.keyStatementRole) OVER (PARTITION BY tlp.prefix,
            tlp.units,
            tlp.cik,
            tlp.accessionNumber,
            tlp.form,
            tlp.endDate) = 3 AS allKeyStatementsPresent,
            sum(tlp.highestLevelParentsTotal) OVER (PARTITION BY tlp.prefix,
            tlp.units,
            tlp.cik,
            tlp.accessionNumber,
            tlp.form,
            tlp.endDate) = sum(fln.firstLevelNodesTotal) OVER (PARTITION BY tlp.prefix,
            tlp.units,
            tlp.cik,
            tlp.accessionNumber,
            tlp.form,
            tlp.endDate) AS rollUpIsAccurate
        from
            topLevelParentsSum tlp
            INNER JOIN firstLevelNodestSum fln on tlp.cik = fln.cik
            and tlp.accessionNumber = fln.accessionNumber
            and tlp.linkRole = fln.linkRole
            and tlp.keyStatementRole = fln.keyStatementRole
            and tlp.form = fln.form
            and tlp.endDate = fln.endDate
            and tlp.units = fln.units
            inner join (
                select distinct
                    cik,
                    accessionNumber,
                    prefix
                from
                    financialData
                where
                    isPrimaryUnits = TRUE
            ) pu on pu.cik = tlp.cik
            AND pu.accessionNumber = tlp.accessionNumber
            AND pu.prefix = tlp.prefix
        WHERE
            tlp.keyStatementRole in (
                'BalanceSheet',
                'IncomeStatement',
                'StatementOfCashFlows'
            )
            
    )


SELECT
    subs.prefix,
    subs.cik,
    subs.accessionNumber,
    subs.form,
    fd.frame,
    fd.startDate,
    subs.endDate,
    subs.units,
    cth.keyStatementRole,
    cth.ancestor,
    cth.descendant,
    fd.value,
    cth.arcWeight,
    cth.relativeDepth,
    subs.allKeyStatementsPresent,
    subs.rollUpIsAccurate,
    cth.highestParent,
    cth.lowestChild
    
FROM
    financialData fd
    INNER JOIN submissions s ON fd.cik = s.cik
    AND fd.accessionNumber = s.accessionNumber
    AND s.reportDate = fd.endDate
    AND s.form in ('10-K', '20-F', '40-F', '10-K/A', '20-F/A', '40-F/A', '10-Q', '10-Q/A')
    INNER JOIN calculationTaxonomyHierarchy cth ON cth.cik = fd.cik
    AND cth.accessionNumber = fd.accessionNumber
    AND fd.name = cth.descendant
    /*
    AND (
        cth."relativeDepth" = 1
        OR (
            cth."relativeDepth" = 0
            AND cth.highestParent = TRUE
        )
    )*/
    and cth."keyStatementRole" IN (
        'BalanceSheet',
        'IncomeStatement',
        'StatementOfCashFlows'
    )
    INNER JOIN subs ON fd.prefix = subs.prefix
    AND fd.cik = subs.cik
    AND fd.accessionNumber = subs.accessionNumber
    AND s.form = subs.form
    AND fd.endDate = subs.endDate
   
    AND fd.isPrimarySubmissionDateRange = TRUE
    AND fd.isPrimaryUnits = TRUE
    AND fd.isPrimaryPrefix = TRUE
    AND fd.units = subs.units;

    CHECKPOINT;
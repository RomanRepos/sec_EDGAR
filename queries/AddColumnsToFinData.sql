
alter table financialData add column IF NOT EXISTS isPrimarySubmissionDateRange boolean;
alter table financialData add column IF NOT EXISTS isPrimaryUnits boolean;
alter table financialData add column IF NOT EXISTS isPrimaryPrefix boolean;
                                        
UPDATE financialData fd  
Set isPrimarySubmissionDateRange = 
    CASE 
        WHEN startDate IS NULL THEN TRUE
        ELSE 
            -- Calculate precise month difference based on days
            ((ceil(date_diff('day', fd.startDate, fd.endDate) / 30.436875) BETWEEN 11 AND 14) AND s.form in ('10-K', '20-F', '40-F', '10-K/A', '20-F/A', '40-F/A')) OR 
            ((ceil(date_diff('day', fd.startDate, fd.endDate) / 30.436875) BETWEEN 2 AND 5) AND s.form in ('10-Q', '10-Q/A'))
    END
FROM submissions s
where s.accessionNumber = fd.accessionNumber;


UPDATE financialData
SET isPrimaryUnits = (units = subquery.primaryUnits)
FROM (
    SELECT
        rowid AS rid,
        FIRST_VALUE(units) OVER (
            PARTITION BY prefix, cik, accessionNumber
            ORDER BY COALESCE(
                list_position(['USD','EUR','CAD','GBP','JPY','AUD','CNY','KRW','CHF','CNY'], units),
                999
            )
        ) AS primaryUnits
    FROM financialData
) AS subquery
WHERE financialData.rowid = subquery.rid;    


UPDATE financialData
SET isPrimaryPrefix = (prefix = subquery.primaryPrefix)
FROM (
    SELECT
        rowid AS rid,
        FIRST_VALUE(prefix) OVER (
            PARTITION BY cik, accessionNumber
            ORDER BY COALESCE(
                list_position(['us-gaap', 'ifrs-full'], prefix),
                999
            )
        ) AS primaryPrefix
    FROM financialData
) AS subquery
WHERE financialData.rowid = subquery.rid;   


CHECKPOINT;
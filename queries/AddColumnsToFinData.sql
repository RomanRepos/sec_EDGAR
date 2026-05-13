alter table financialData add column IF NOT EXISTS isStandardPeriodLength boolean;
alter table financialData add column IF NOT EXISTS isPrimarySubmissionDateRange boolean;
alter table financialData add column IF NOT EXISTS isPrimaryUnits boolean;
                                        
UPDATE financialData   
Set isStandardPeriodLength = 
    CASE 
        WHEN startDate IS NULL THEN TRUE
        ELSE 
            -- Calculate precise month difference based on days
            (ceil(date_diff('day', startDate, endDate) / 30.436875) BETWEEN 11 AND 14) OR 
            (ceil(date_diff('day', startDate, endDate) / 30.436875) BETWEEN 2 AND 5)
    END;

UPDATE financialData
SET isPrimarySubmissionDateRange = (subquery.rn = 1)
FROM (
    SELECT 
        rowid AS rid, -- Hidden unique ID provided by DuckDB
        ROW_NUMBER() OVER (
            PARTITION BY prefix, units, cik, accessionNumber, endDate, Name 
            ORDER BY isStandardPeriodLength DESC
        ) AS rn
    FROM financialData
) AS subquery
WHERE financialData.rowid = subquery.rid;

UPDATE financialData
SET isPrimaryUnits = (units = subquery.pirmaryUnits)
FROM (
    SELECT 
        rowid AS rid,
        CASE 
    WHEN list_position(['USD','EUR','CAD','GBP','JPY','AUD','CNY','KRW','CHF'], units) IS NULL 
        THEN 'Other'
    WHEN ROW_NUMBER() OVER (
        PARTITION BY prefix, cik, accessionNumber, endDate, Name
        ORDER BY list_position(['USD','EUR','CAD','GBP','JPY','AUD','CNY','KRW','CHF'], units)
    ) = 1 
        THEN units
    ELSE NULL
END AS pirmaryUnits
    FROM financialData
) AS subquery
WHERE financialData.rowid = subquery.rid;                 


CHECKPOINT;
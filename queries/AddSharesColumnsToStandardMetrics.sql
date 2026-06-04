ALTER TABLE standardMetrics
ADD COLUMN IF NOT EXISTS "Weighted Averages Shares Outsanding Basic" bigint;

ALTER TABLE standardMetrics
ADD COLUMN IF NOT EXISTS "Weighted Averages Shares Outsanding Diluted" bigint;

ALTER TABLE standardMetrics
ADD COLUMN IF NOT EXISTS "Common Stock Shares Outstanding" bigint;

ALTER TABLE standardMetrics
ADD COLUMN IF NOT EXISTS "Preferred Stock Shares Outstanding Basic" bigint;

Update standardMetrics sm
set
    "Weighted Averages Shares Outsanding Basic" = fdb.value
from
    financialData fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm.endDate = fdb.endDate
    and sm.prefix = fdb.prefix
    and fdb.name in (
        'WeightedAverageNumberOfSharesOutstandingBasic',
        'WeightedAverageShares',
        'WeightedAverageNumberOfSharesOutstandingBasicAndDiluted'
    );

Update standardMetrics sm
set
    "Weighted Averages Shares Outsanding Diluted" = fdb.value
from
    financialData fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm.endDate = fdb.endDate
    and sm.prefix = fdb.prefix
    and fdb.name in (
        'WeightedAverageNumberOfDilutedSharesOutstanding',
        'WeightedAverageShares',
        'WeightedAverageNumberOfSharesOutstandingBasicAndDiluted'
    );

Update standardMetrics sm
set
    "Common Stock Shares Outstanding" = fdb.value
from
    financialData fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm.endDate = fdb.endDate
    and sm.prefix = fdb.prefix
    and fdb.name in (
        'CommonStockSharesOutstanding',
        'SharesOutstanding',
        'EntityCommonStockSharesOutstanding',
        'NumberOfSharesOutstanding'
    );

Update standardMetrics sm
set
    "Preferred Stock Shares Outstanding Basic" = fdb.value
from
    financialData fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm.endDate = fdb.endDate
    and sm.prefix = fdb.prefix
    and fdb.name = 'PreferredStockSharesOutstanding';

CHECKPOINT;




Update standardMetrics sm
set
    "Weighted Averages Shares Outsanding Basic" = fdb.value
from (
    select prefix, cik, "accessionNumber", name, value, endDate
    from financialData
    where name in (
        'WeightedAverageNumberOfSharesOutstandingBasic',
        'WeightedAverageShares',
        'WeightedAverageNumberOfSharesOutstandingBasicAndDiluted'
    )
    QUALIFY endDate = max(endDate) over (PARTITION by cik, accessionNumber, name)
) fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm."Weighted Averages Shares Outsanding Basic" is null;

Update standardMetrics sm
set
    "Weighted Averages Shares Outsanding Diluted" = fdb.value
from (
    select prefix, cik, "accessionNumber", name, value, endDate
    from financialData
    where name in (
        'WeightedAverageNumberOfDilutedSharesOutstanding',
        'WeightedAverageShares',
        'WeightedAverageNumberOfSharesOutstandingBasicAndDiluted'
    )
    QUALIFY endDate = max(endDate) over (PARTITION by cik, accessionNumber, name)
) fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm."Weighted Averages Shares Outsanding Diluted" is null;

Update standardMetrics sm
set
    "Common Stock Shares Outstanding" = fdb.value
from (
    select prefix, cik, "accessionNumber", name, value, endDate
    from financialData
    where name in (
        'CommonStockSharesOutstanding',
        'SharesOutstanding',
        'EntityCommonStockSharesOutstanding',
        'NumberOfSharesOutstanding'
    )
    QUALIFY endDate = max(endDate) over (PARTITION by cik, accessionNumber, name)
) fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm."Common Stock Shares Outstanding" is null;

Update standardMetrics sm
set
    "Preferred Stock Shares Outstanding Basic" = fdb.value
from (
    select prefix, cik, "accessionNumber", name, value, endDate
    from financialData
    where name = 'PreferredStockSharesOutstanding'
    QUALIFY endDate = max(endDate) over (PARTITION by cik, accessionNumber, name)
) fdb
where
    sm.cik = fdb.cik
    and sm.accessionNumber = fdb.accessionNumber
    and sm."Preferred Stock Shares Outstanding Basic" is null;

CHECKPOINT;
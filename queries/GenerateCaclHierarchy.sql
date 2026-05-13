
SELECT ct.cik, ct.accessionNumber, ct.linkRole, crc.keyStatementRole as keyStatementRole, 
                        ct.fromConcept, ct.toConcept, ct.arcOrder,
    ct.arcWeight from calculationTaxonomy ct 
    inner join calcTaxRolesClassified crc on crc.linkRole = ct.linkRole
    anti join calculationTaxonomyHierarchy cth on cth.cik = ct.cik and cth.accessionNumber = ct.accessionNumber
        and ct.linkRole = cth.linkRole
    where ct.isPrimaryRole=TRUE
    and ct.fromConcept IS NOT NULL and ct.toConcept IS NOT NULL and ct.fromConcept<>ct.toConcept;


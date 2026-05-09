import re
import duckdb as ddb
from dotenv import load_dotenv
from pathlib import Path
import os

def normalize(s):
    return re.sub(r'[^a-z]', '', s.lower())

SPECIFIC_DISCARD = ['disclosure', 'schedule', 'changes', 'credit', 'derivative', 'complement',
                    'detailsdetails', 'changein', 'changes', 'rsoconsolidated', 'divest', 'offset']
INCOME_STATEMENT_DISCARD = ['disclosure', 'schedule', 
                            'equity', 'changes', 'credit',
                            'derivative', 'othercomprehensiveincomelossdetails',
                            'othercomprehensiveincomedetails',
                            'othercomprehensivelossdetails', 'change']
CASH_FLOW_DISCARD = ['disclosure', 'schedule', 'credit', 'derivative', 'complement']

DISCARD_PATTERNS = [
    'parenthetical',
    'supplemental',
    'calc',
    'rollforward',
    'guarantor',
    'nonguarantor',
    'consolidating',   # catches CondensedConsolidating*
    'selectedbalancesheet',
    'selectedquarterly',
    'quarterly',
    'segment',
    'geographic',
    'reconciliation',
    'chapter',
    'note',            # catches Note, DisclosureNote
    'table',
    'policy',
    'policies',
    'description',
    'organization',
    'acquisition'
    'offset',
    'reclassification',
    'discontinued',
    'taxschedule'
    'taxesschedule',
    'lease',
    'tax',
    'financing',
    'component',
    'future',
    'productiondetail',
    'project',
    'selected'
    'informationsummary',
    'informationdetails',
    'logistics',
    'detaildetail',
    'detailsdetail',
    'assumption',
    'fairvalue'
]

SHARES_DISCLOSURE_PATTERNS = [
    'earningspershare',
    'earningspershares',
    'earningspersharedetail',
    'earningslosspersha',
    'losspershare',
    'losspersha',
    'netincomepershare',
    'netincomelosspersha',
    'netlosspershare',
    'incomepershare',
    'incomelosspershare',
    'dilutedearnings',
    'basicanddiluted',
    'weightedaverageshar',
    'weightedaveragecommonsha',
    'computationofbasic',
    'computationofearningsper',
    'reconciliationofbasicper',
    'reconciliationofearningsper',
    'earningsperu',             # per unit variants
    'netincomeperunit',                    # employee stock ownership plan
    'employeestockownership',
    'changesinequity',
    'changesinnetassets',
    'changesinsharehold',
    'statementofstockholders',
    'statementofshareholders',
    'statementsofstockholders',
    'statementsofsharehold',
    'statementofmembers',
    'statementofpartners',
    'partnercapital',
    'partnerscapital',
    'membercapital',
    'membersequity',
    'redeemablecapital',
    'commonstock',              # common stock details/reserves
    'sharesreserved',
    'stockreserved',
    'sharesoutstanding',
    'sharetransactions',
    'sharecapital',
    'disclosureshareholdersequitydetails'
]
# Equity statement patterns — exclude from our 3 targets
EQUITY_PATTERNS = [
    'stockholdersequity',
    'shareholdersequity',
    'partnerscapital',
    'partnercapital',
    'changesinequity',
    'changesinnetassets',
    'changesinmembercapital',
    'membercapital', 
    'statementsofequity',
    'statementofequity'
]

CASH_FLOW_PATTERNS = [
    'cashflow', 'cashflows',
    'statementofcashflow', 
    'statementsofcashflow',
    'cashflowsindirect', 
    'cashflowsdirect',
    'cashflowstatement'
]

BALANCE_SHEET_PATTERNS = [
    'balancesheet', 
    'balancesheets',
    'financialposition',
    'financialcondition',
    'assetsandliabilities',
    'statementofcondition',
    'statementsofcondition',
    'statementoffinancialcondition',
    'statementsoffinancialcondition',
    'statementoffinancialposition',
    'statementsoffinancialposition',
    'statementsofassetsandliabilities',
    'statementofassetsandliabilities', 
    'statementBalanceSheet',
    'statementoffinancialcondtion', 
    'consolidatedstatementoffinancialposition',
    'consolidatedstatementsoffinancialposition' # investment fund balance sheet equiv
]

INCOME_STATEMENT_PATTERNS = [
    'statementsofoperations', 
    'statementofoperations',
    'incomestatement', 
    'incomestatements',
    'statementofincome', 
    'statementsofincome',
    'statementsofearnings', 
    'statementofearnings',
    'consolidatedincome', 
    'consolidatedstatementsofincome',
    'statementsofconsolidatedincome',
    'consolidatedstatementsofloss',
    'comprehensiveincome',
    'statementsofconsolidatedloss',
    'comprehensiveloss',
    'comprehensiveearnings',
    'statementsofoperationsandcomprehensive',
    'statementofloss', 'statementsofloss',
    'statementsoflosandcomprehensive',
    'statementsofprofitorloss',     # IFRS
    'profitorlossandothercomprehensive',
    'statementsofexpenses',         # investment funds
    'statementsofincomeandexpenses',
    'statementsofnetincome',
    'resultsofoperations',
    'statementsofoperationsandother']

def classify_role(role_tail: str):
    n = normalize(role_tail)

    # Step 1: discard noise
    if any(p in n for p in DISCARD_PATTERNS):
        return None
    
    # Step 3: cash flow (before income — more specific)
    if any(p in n for p in CASH_FLOW_PATTERNS) and not any(p in n for p in CASH_FLOW_DISCARD): 
        return 'StatementOfCashFlows'
    
    # Step 4: balance sheet
    if any(p in n for p in BALANCE_SHEET_PATTERNS) and not any(p in n for p in SPECIFIC_DISCARD): 
        return 'BalanceSheet'
    
    # Step 5: income statement
    if any(p in n for p in INCOME_STATEMENT_PATTERNS) and not any(p in n and n != 'statementofothercomprehensiveincome' and n != 'othercomprehensiveincome' and n != 'othercomprehensiveincomestatement' for p in INCOME_STATEMENT_DISCARD): 
        return 'IncomeStatement'
    
    if any(p in n for p in EQUITY_PATTERNS):
        return 'EquityStatement'
    
    if any(p in n for p in SHARES_DISCLOSURE_PATTERNS):
        return 'SharesDisclosure'
   
    return None

if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or 
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path    = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)

    roles_df = conn.execute('''select distinct linkRole from calculationTaxonomy''').fetch_df()
    
    roles_df['keyStatementRole'] = roles_df['linkRole'].apply(classify_role)
    roles_df = roles_df[roles_df['keyStatementRole'].notna()]

    conn.register('presentation_df', roles_df)
    conn.execute("CREATE OR REPLACE TABLE calcTaxRolesClassified AS SELECT * FROM roles_df; CHECKPOINT;")

    conn.close()
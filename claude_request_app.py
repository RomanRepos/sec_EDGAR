import json                                                                                                                                             
from dotenv import load_dotenv
from pathlib import Path
import duckdb as ddb
import os
                  
def build_system_prompt(metrics_path="financial_metrics.json"):                                                                                         
    with open(metrics_path) as f:
        metrics = json.load(f)                                                                                                                          
                
    lines = [
        "You are a financial concept mapper. You take XBRL concepts from financial statemnts filed to SEC EDGAR",
        "and map how they would be used in calculation of standard financial metrics such as Free Cash Flow, EBITDA, etc",                                                                                                                                             
        "## Metric Definitions",
    ]                                                                                                                                                   
                
    for m in metrics:
        lines.append(f"\n### {m['metric']}")
        lines.append(f"Formula: {m['formula']}")
        lines.append(f"Description: {m['semantic_description']}")                                                                                       
        lines.append("\nComponents:")
        for c in m['components']:                                                                                                                       
            lines.append(f"- role: {c['role']} | statement: {c['statement']} | units: {c['units']}")
            lines.append(f"  {c['semantic_description']}")                                                                                              

    lines += ["", "## Output Format", "..."]                                                                                                            
                
    return "\n".join(lines) 

if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
    db_path = os.path.join(PROJECT_ROOT_PARENT, "Analytics", "secFilingsDb.duckdb")

    metrics_path =  os.path.join(PROJECT_ROOT_PARENT, "Analytics", "financial_metrics.json")
    print(build_system_prompt(metrics_path=metrics_path))
    #conn = ddb.connect(db_path, read_only=True)
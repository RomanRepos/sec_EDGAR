import os
from curl_cffi import requests
import subprocess

def download_and_extract(url, extract_to='extracted_files'):



    zip_path = "temp_archive.zip"
    
    # 1. Download the file
    print(f"Downloading from {url}...")
    response = requests.get(url, impersonate="chrome101", stream=True) # stream=True handles larger files better
    response.raise_for_status()               # Check for download errors
    
    with open(zip_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=16384):
            f.write(chunk)

    # 2. Unzip into a folder
    print(f"Unzipping into '{extract_to}'...")
    
    subprocess.run([
    "python", "-m", "fast_unzip", 
    zip_path, 
    "-d", extract_to,
    "-p", "4", 
    "-t", "8"
])
    # 3. Delete the original ZIP file
    os.remove(zip_path)
    print("Done! Original ZIP deleted.")



def sync_json_files(source_dir, target_dir):
    # 1. Get a set of all .json files in the source directory
    # Using a set allows for efficient comparison
    source_files = {f for f in os.listdir(source_dir) if f.endswith('.json')}
    
    # 2. Iterate through files in the target directory
    for filename in os.listdir(target_dir):
        if filename.endswith('.json'):
            filename_list = filename.split('.')
            filename_formmated = filename_list[0][:13] +'.'+filename_list[1]
        # Only process .json files
        if filename_formmated not in source_files:
            file_path = os.path.join(target_dir, filename)
            try:
                os.remove(file_path)
            except Exception as e:
                print(f"Error deleting {filename}: {e}")
                continue


#factsDir = r'D:\EDGAR_Data_Analytics\Data\companyfacts'
#submDir = r'D:\EDGAR_Data_Analytics\Data\submissions'
#sync_json_files(factsDir, submDir)
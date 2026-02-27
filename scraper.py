import requests
import json
import pandas as pd
from bs4 import BeautifulSoup
import time
import os

def scrape_elmenus():
    print("Scraping ElMenus...")
    url = "https://www.elmenus.com/api/v3/client/discovery/delivery-page?cityAreaUuid=e4b47f7d-2b4a-466d-ad72-c2e914044be2&page=1&pageSize=1000"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "Accept": "application/json",
        "device-type": "web"
    }
    try:
        response = requests.get(url, headers=headers)
        data = response.json()
        
        restaurants = []
        for item in data.get('searchResponse', {}).get('dishes', []):
            restaurant = item.get('restaurant', {})
            info = {
                'Platform': 'ElMenus',
                'Name': restaurant.get('name', ''),
                'Rating': restaurant.get('rating', {}).get('score', ''),
                'Categories': ', '.join(restaurant.get('categories', [])),
                'Delivery Time (mins)': restaurant.get('deliveryTimeStr', ''),
                'Delivery Fee': restaurant.get('deliveryFee', ''),
                'Phone': '',
                'Address': ''
            }
            if restaurant.get('name'):
                restaurants.append(info)
        return restaurants
    except Exception as e:
        print(f"Error scraping ElMenus: {e}")
        return []

def scrape_yellowpages():
    print("Scraping Yellow Pages...")
    restaurants = []
    base_url = "https://yellowpages.com.eg/en/category/maadi-restaurants-home-delivery/3231/p{}"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }
    
    for page in range(1, 42): 
        print(f"  Page {page}...")
        try:
            url = base_url.format(page)
            response = requests.get(url, headers=headers)
            if response.status_code != 200:
                print(f"  HTTP {response.status_code}")
                continue
                
            soup = BeautifulSoup(response.text, 'html.parser')
            
            items = soup.select('.company-name')
            
            if not items:
                print(f"  No items found on page {page}. Checking alternative selectors...")
                items = soup.select('div.item-row')
                
            for item in items:
                name = item.text.strip()
                parent = item.find_parent('div', class_='row')
                
                phone = ""
                addr = ""
                
                if parent:
                    addr_elem = parent.find(class_='address-text')
                    phone_elem = parent.find(class_='phone-text')
                    if addr_elem: addr = addr_elem.text.strip()
                    if phone_elem: phone = phone_elem.text.strip()
                
                restaurants.append({
                    'Platform': 'Yellow Pages',
                    'Name': name,
                    'Rating': '',
                    'Categories': '',
                    'Delivery Time (mins)': '',
                    'Delivery Fee': '',
                    'Phone': phone,
                    'Address': addr
                })
            time.sleep(0.5)
        except Exception as e:
            print(f"Error scraping Yellow Pages page {page}: {e}")
            
    return restaurants

def main():
    print("Starting scraping process...")
    try:
        import pandas as pd
    except ImportError:
        print("Installing pandas and openpyxl...")
        os.system("python3 -m pip install pandas openpyxl beautifulsoup4 requests --quiet")
        import pandas as pd
        
    elmenus_data = scrape_elmenus()
    print(f"Found {len(elmenus_data)} restaurants from ElMenus")
    
    yp_data = scrape_yellowpages()
    print(f"Found {len(yp_data)} restaurants from Yellow Pages")
    
    all_data = elmenus_data + yp_data
    
    if all_data:
        df = pd.DataFrame(all_data)
        output_file = 'maadi_restaurants.xlsx'
        
        print(f"Total rows before deduplication: {len(df)}")
        df['Name_Lower'] = df['Name'].str.lower().str.strip()
        df = df.drop_duplicates(subset=['Name_Lower']).drop(columns=['Name_Lower'])
        print(f"Total rows after deduplication: {len(df)}")
        
        df.to_excel(output_file, index=False)
        print(f"Successfully saved to {os.path.abspath(output_file)}")
    else:
        print("No data was collected!")

if __name__ == "__main__":
    main()

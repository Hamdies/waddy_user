#!/usr/bin/env python3
import json

en_file = './en.json'
ar_file = './ar.json'

# Load and validate JSON
try:
    with open(en_file, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
    print(f'✓ en.json is valid JSON with {len(en_data)} keys')
except Exception as e:
    print(f'✗ en.json error: {e}')
    exit(1)

try:
    with open(ar_file, 'r', encoding='utf-8') as f:
        ar_data = json.load(f)
    print(f'✓ ar.json is valid JSON with {len(ar_data)} keys')
except Exception as e:
    print(f'✗ ar.json error: {e}')
    exit(1)

# Check for missing keys
en_keys = set(en_data.keys())
ar_keys = set(ar_data.keys())

missing_in_ar = en_keys - ar_keys
missing_in_en = ar_keys - en_keys

if not missing_in_ar:
    print(f'✓ All English keys present in Arabic')
else:
    print(f'✗ Missing in Arabic ({len(missing_in_ar)}): {list(missing_in_ar)[:5]}')

if not missing_in_en:
    print(f'✓ No extra keys in Arabic')
else:
    print(f'✗ Extra in Arabic ({len(missing_in_en)}): {list(missing_in_en)[:5]}')

if en_keys == ar_keys:
    print(f'\n✓✓✓ SUCCESS! Both files are complete and synchronized!')
    print(f'    English: {len(en_data)} keys')
    print(f'    Arabic:  {len(ar_data)} keys')
else:
    print(f'\n✗ Files do not match')
    print(f'    Missing in Arabic: {len(missing_in_ar)}')
    print(f'    Extra in Arabic: {len(missing_in_en)}')

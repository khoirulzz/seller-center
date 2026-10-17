"""Reuse a registered app or initialize it using the runner's secret token."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
os.chdir(root)
if not os.environ.get('SHOREBIRD_TOKEN'):
    raise SystemExit('Missing repository secret SHOREBIRD_TOKEN.')
config = root / 'shorebird.yaml'
if not config.exists():
    response = subprocess.run(
        ['shorebird', 'apps', 'list', '--json'],
        check=True, capture_output=True, text=True,
    )
    envelope = json.loads(response.stdout)
    data = envelope.get('data', {})
    apps = data if isinstance(data, list) else data.get('apps', [])
    matches = [a for a in apps if a.get('display_name') == 'Nalaro Seller Center']
    if len(matches) > 1:
        raise SystemExit('Several registered apps share this display name; select the intended app ID.')
    if matches:
        app_id = matches[0].get('id') or matches[0].get('app_id')
        if not app_id:
            raise SystemExit('Registered app response did not include its ID.')
        config.write_text(f'app_id: {app_id}\nauto_update: false\n')
    else:
        subprocess.run(
            ['shorebird', 'init', '--display-name', 'Nalaro Seller Center', '--json'],
            check=True,
        )
text = config.read_text()
if 'auto_update:' not in text:
    text += '\nauto_update: false\n'
else:
    import re
    text = re.sub(r'(?m)^auto_update:.*$', 'auto_update: false', text)
config.write_text(text)
pubspec = root / 'pubspec.yaml'
text = pubspec.read_text()
if '    - shorebird.yaml\n' not in text:
    text = text.replace('  assets:\n', '  assets:\n    - shorebird.yaml\n', 1)
pubspec.write_text(text)
print('Registered public Shorebird configuration is ready.')

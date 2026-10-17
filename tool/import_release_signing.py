"""Import the private release-signing backup into repository secrets using gh.

Run locally after gh auth login:
python3 tool/import_release_signing.py Nalaro-Android-Signing-PRIVATE.zip
Secret values are passed through stdin and are never printed.
"""
import argparse
import base64
import json
import subprocess
import zipfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("backup", type=Path)
parser.add_argument("--repo", default="khoirulzz/seller-center")
args = parser.parse_args()
with zipfile.ZipFile(args.backup) as archive:
    if sum(item.file_size for item in archive.infolist()) > 256 * 1024:
        raise SystemExit("Signing backup is too large.")
    info = json.loads(archive.read("signing.json"))
    key = archive.read("nalaro-seller-release.jks")
values = {
    "ANDROID_KEYSTORE_BASE64": base64.b64encode(key).decode("ascii"),
    "ANDROID_KEYSTORE_PASSWORD": info["store_password"],
    "ANDROID_KEY_ALIAS": info["alias"],
    "ANDROID_KEY_PASSWORD": info["key_password"],
}
for name, value in values.items():
    subprocess.run(
        ["gh", "secret", "set", name, "--repo", args.repo],
        input=value, text=True, check=True,
    )
    print(name + " configured.")
print("Permanent signing secrets are ready; run Sign Android release.")

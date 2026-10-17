"""Configure persistent Android signing without writing secrets into the checkout."""

import base64
import binascii
import os
from pathlib import Path
import sys


REQUIRED = (
    "SHOREBIRD_TOKEN",
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
)


def validate_environment() -> bytes:
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if missing:
        raise ValueError("Missing GitHub Actions secrets: " + ", ".join(missing))
    try:
        data = base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError("ANDROID_KEYSTORE_BASE64 must be valid, single-line base64.") from error
    if not data:
        raise ValueError("The signing keystore is empty.")
    return data


def configure(root: Path, data: bytes) -> None:
    target = Path(os.environ["ANDROID_KEYSTORE_PATH"])
    if not target.is_absolute() or target.is_relative_to(root):
        raise ValueError("ANDROID_KEYSTORE_PATH must be outside the checkout.")
    gradle = root / "android/app/build.gradle.kts"
    content = gradle.read_text()
    debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
    if debug_signing not in content or content.count("    buildTypes {") != 1:
        raise ValueError("Android Gradle template changed; review signing before releasing.")
    content = content.replace(
        "    buildTypes {",
        '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {''',
        1,
    ).replace(debug_signing, 'signingConfig = signingConfigs.getByName("release")')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.touch(mode=0o600, exist_ok=True)
    target.chmod(0o600)
    target.write_bytes(data)
    gradle.write_text(content)


if __name__ == "__main__":
    try:
        data = validate_environment()
        if "--check-only" not in sys.argv:
            configure(Path(__file__).resolve().parent.parent, data)
    except (ValueError, KeyError) as error:
        raise SystemExit(str(error)) from error
    print("Signing configuration checked." if "--check-only" in sys.argv else "Release signing configured.")

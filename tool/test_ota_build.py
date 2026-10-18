import base64
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import configure_android_signing as signing
from prepare_ota import prepare


class OtaBuildTest(unittest.TestCase):
    def test_missing_or_placeholder_app_id_is_rejected_before_modification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for value in ("", "placeholder", "00000000-0000-0000-0000-000000000000"):
                with self.assertRaises(ValueError):
                    prepare(root, value)
            self.assertFalse((root / "shorebird.yaml").exists())

    def test_registered_app_configuration_is_idempotent_and_bundled(self):
        # Synthetic identifier is confined to the test fixture, never a build fallback.
        app_id = "b55111ea-0b37-4b7a-9322-322cd09351f1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = root / "pubspec.yaml"
            pubspec.write_text("flutter:\n  assets:\n    - assets/icons/\n")
            prepare(root, app_id)
            prepare(root, app_id)
            self.assertEqual(pubspec.read_text().count("- shorebird.yaml"), 1)
            self.assertEqual((root / "shorebird.yaml").read_text().count(app_id), 1)
            self.assertIn("auto_update: false", (root / "shorebird.yaml").read_text())

    def test_registered_app_id_cannot_be_replaced_by_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("flutter:\n  assets:\n")
            app_id = "b55111ea-0b37-4b7a-9322-322cd09351f1"
            different_id = "c66111ea-0b37-4b7a-9322-322cd09351f1"
            prepare(root, app_id)
            with self.assertRaisesRegex(ValueError, "conflicts"):
                prepare(root, different_id)
            self.assertIn(app_id, (root / "shorebird.yaml").read_text())

    def test_missing_signing_secret_is_rejected(self):
        with patch.dict("os.environ", {}, clear=True), self.assertRaises(ValueError):
            signing.validate_environment()

    def test_corrupt_keystore_encoding_is_rejected(self):
        values = {key: "test" for key in signing.REQUIRED}
        values["ANDROID_KEYSTORE_BASE64"] = "not base64!"
        with patch.dict("os.environ", values, clear=True), self.assertRaises(ValueError):
            signing.validate_environment()

    def test_release_uses_persistent_key_and_does_not_write_passwords(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            gradle = root / "android/app/build.gradle.kts"
            gradle.parent.mkdir(parents=True)
            gradle.write_text('android {\n    buildTypes {\n        release {\n            signingConfig = signingConfigs.getByName("debug")\n        }\n    }\n}\n')
            key = Path(directory) / "runner/release.jks"
            values = {name: "private-test-value" for name in signing.REQUIRED}
            values["ANDROID_KEYSTORE_BASE64"] = base64.b64encode(b"test-keystore").decode()
            values["ANDROID_KEYSTORE_PATH"] = str(key)
            with patch.dict("os.environ", values, clear=True):
                signing.configure(root, signing.validate_environment())
            self.assertEqual(key.read_bytes(), b"test-keystore")
            self.assertEqual(key.stat().st_mode & 0o777, 0o600)
            self.assertNotIn("private-test-value", gradle.read_text())
            self.assertNotIn('getByName("debug")', gradle.read_text())
            self.assertIn('getByName("release")', gradle.read_text())

    def test_changed_gradle_template_fails_without_leaking_a_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            gradle = root / "android/app/build.gradle.kts"
            gradle.parent.mkdir(parents=True)
            gradle.write_text("unexpected template")
            key = Path(directory) / "runner/release.jks"
            with patch.dict("os.environ", {"ANDROID_KEYSTORE_PATH": str(key)}):
                with self.assertRaises(ValueError):
                    signing.configure(root, b"private")
            self.assertFalse(key.exists())


if __name__ == "__main__":
    unittest.main()

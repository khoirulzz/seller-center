"""Build native launcher layers from the unchanged official transparent mark.

Android owns the launcher mask. Tinting the bitmap drawable keeps the original
silhouette exact, with a separate pink background and a themed monochrome layer.
"""
from pathlib import Path
import shutil

def configure(root: Path) -> None:
    res = root / "android/app/src/main/res"
    for name in ["drawable", "drawable-nodpi", "mipmap-anydpi", "mipmap-anydpi-v26", "mipmap-anydpi-v33"]:
        (res / name).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "assets/brand/nalarostore-mark.png", res / "drawable-nodpi/nalaro_mark_source.png")
    (res / "drawable/nalaro_launcher_background.xml").write_text('''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#FF154F"/></shape>''')
    (res / "drawable/nalaro_launcher_mark.xml").write_text('''<inset xmlns:android="http://schemas.android.com/apk/res/android" android:insetLeft="28dp" android:insetTop="28dp" android:insetRight="28dp" android:insetBottom="28dp"><bitmap android:src="@drawable/nalaro_mark_source" android:gravity="fill" android:tint="#FFFFFFFF" android:filter="true"/></inset>''')
    adaptive='''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/nalaro_launcher_background"/><foreground android:drawable="@drawable/nalaro_launcher_mark"/>{}</adaptive-icon>'''
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(adaptive.format(""))
    (res / "mipmap-anydpi-v33/ic_launcher.xml").write_text(adaptive.format('<monochrome android:drawable="@drawable/nalaro_launcher_mark"/>'))
    (res / "mipmap-anydpi/ic_launcher.xml").write_text('''<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@drawable/nalaro_launcher_background"/><item android:left="10dp" android:top="10dp" android:right="10dp" android:bottom="10dp"><bitmap android:src="@drawable/nalaro_mark_source" android:gravity="fill" android:tint="#FFFFFFFF" android:filter="true"/></item></layer-list>''')

if __name__ == "__main__":
    configure(Path(__file__).resolve().parent.parent)
    print("Native adaptive, monochrome, and legacy launcher layers prepared.")

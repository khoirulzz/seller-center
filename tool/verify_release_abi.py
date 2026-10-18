"""Fail Android release CI if R8 has changed the Pigeon/Kotlin method ABI.

The SharedPreferences plugin calls its Kotlin registrar via a platform channel.
An R8-obfuscated kotlin.coroutines.Continuation descriptor causes a runtime
NoSuchMethodError at login even when Flutter unit tests pass.
"""
from __future__ import annotations

import re
import struct
import sys
from pathlib import Path
from zipfile import ZipFile


REGISTRAR = "Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;"
CONTINUATION = "Lkotlin/coroutines/Continuation;"
EXPECTED_PARAMETERS = (
    "Ljava/lang/String;",
    "Ljava/util/List;",
    CONTINUATION,
)


def has_compatible_registrar(data: bytes) -> bool:
    if data[:4] != b"dex\\n":
        raise ValueError("Invalid DEX header")

    def u16(offset: int) -> int:
        return struct.unpack_from("<H", data, offset)[0]

    def u32(offset: int) -> int:
        return struct.unpack_from("<I", data, offset)[0]

    def string(index: int) -> str:
        offset = u32(u32(0x3C) + index * 4)
        while data[offset] & 0x80:
            offset += 1
        offset += 1
        return data[offset : data.index(0, offset)].decode("utf-8")

    types = [
        string(u32(u32(0x44) + index * 4))
        for index in range(u32(0x40))
    ]

    def parameters(proto_index: int) -> tuple[str, ...]:
        off = u32(u32(0x4C) + proto_index * 12 + 8)
        if not off:
            return ()
        return tuple(types[u16(off + 4 + index * 2)] for index in range(u32(off)))

    offset = u32(0x5C)
    for index in range(u32(0x58)):
        class_idx, proto_idx, name_idx = struct.unpack_from(
            "<HHI", data, offset + index * 8
        )
        if (
            types[class_idx] == REGISTRAR
            and string(name_idx) == "getAll"
            and parameters(proto_idx) == EXPECTED_PARAMETERS
        ):
            return True
    return False


def verify_apk(path: Path) -> None:
    with ZipFile(path) as archive:
        dex_names = [
            name for name in archive.namelist()
            if re.fullmatch(r"classes(?:[0-9]+)?\\.dex", name)
        ]
        if not dex_names:
            raise ValueError("APK contains no Android DEX bytecode")
        if not any(has_compatible_registrar(archive.read(name)) for name in dex_names):
            raise ValueError(
                "Broken SharedPreferences native ABI in " + path.name +
                ": kotlin.coroutines.Continuation was removed or obfuscated. "
                "Disable R8 minification for the release and rebuild."
            )
    print("SharedPreferences native ABI verified: " + path.name)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python3 tool/verify_release_abi.py APK [APK...]")
    for filename in sys.argv[1:]:
        verify_apk(Path(filename))

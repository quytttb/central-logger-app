# ZBar DLLs for Windows (QR Scan QR…)

Central App uses **pyzbar**, which needs native **ZBar** libraries on Windows.

## Files to place here (64-bit)

| File | Required |
|------|----------|
| `libzbar-64.dll` | Yes |
| `libiconv.dll` | Often required by ZBar builds |

**Recommended:** run the staging script (downloads pinned DLLs automatically):

```powershell
.\scripts\stage_zbar_windows.ps1
```

URLs and SHA256 checksums are in [`zbar-dlls.manifest.json`](zbar-dlls.manifest.json) ([barcode-reader-dlls release 0.1](https://github.com/NaturalHistoryMuseum/barcode-reader-dlls/releases/tag/0.1)).

Alternatively copy from a local ZBar install (`-Source "C:\...\bin"`) or vcpkg output. Match **x64** with the Python/app build.

## Development layout

```
central-logger-app/
  resources/native/windows/
    libzbar-64.dll
    libiconv.dll
```

On Linux dev machines you do **not** need these files — use `sudo apt install libzbar0` instead.

## Deployed layout (Nuitka / pyside6-deploy)

DLLs are copied next to the executable as:

```
CentralLogger.exe
native/windows/libzbar-64.dll
native/windows/libiconv.dll
```

The app calls `os.add_dll_directory()` on that folder at runtime.

## Staging script

From repo root on Windows:

```powershell
# Auto-download + verify (default)
.\scripts\stage_zbar_windows.ps1

# Or copy from an existing install
.\scripts\stage_zbar_windows.ps1 -Source "C:\Program Files\ZBar\bin"

# One-shot portable build (stage + rcc + deploy)
.\scripts\build_deploy_windows.ps1

# Build without QR
.\scripts\stage_zbar_windows.ps1 -SkipQr
```

On Linux/WSL (for staging only, before copying tree to Windows build):

```bash
python3 scripts/fetch_zbar_windows.py
```

Then build with `pyside6-deploy` (see root README).

**Runtime on Windows:** some machines need [Visual C++ 2013 Redistributable (x64)](https://www.microsoft.com/en-us/download/details.aspx?id=40784) for these DLLs.

## License

ZBar is LGPL. Ship corresponding license/notice with your installer if you redistribute these DLLs.

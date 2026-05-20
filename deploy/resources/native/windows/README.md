# ZBar DLLs for Windows (QR Scan QR…)

Central App uses **pyzbar**, which needs native **ZBar** libraries on Windows.

## Files to place here (64-bit)

| File | Required |
|------|----------|
| `libzbar-64.dll` | Yes |
| `libiconv.dll` | Often required by ZBar builds |

Obtain from a trusted ZBar Windows build (e.g. [ZBar on SourceForge](https://sourceforge.net/projects/zbar/files/)) or your own vcpkg output. Match **x64** with the Python/app build.

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

From repo root on Windows (after installing ZBar elsewhere):

```powershell
.\scripts\stage_zbar_windows.ps1 -Source "C:\path\to\zbar\bin"
```

Then build with `pyside6-deploy` (see root README).

## License

ZBar is LGPL. Ship corresponding license/notice with your installer if you redistribute these DLLs.

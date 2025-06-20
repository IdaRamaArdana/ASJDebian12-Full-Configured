import os
import shutil
import json
import urllib.request
from pathlib import Path

# ======== KONFIGURASI ========
minecraft_version = "1.20.4"
forge_modloader = "NeoForge"
required_mods = [
    "ThinAir-v20.4.2-1.20.4-NeoForge.jar",
    "diet-quilt-2.1.1+1.20.1.jar",
    "The_Undergarden-1.21.1-0.9.1.jar"
]

minecraft_folder = Path.home() / "AppData/Roaming/.minecraft"
mods_folder = minecraft_folder / "mods"
libraries_folder = minecraft_folder / "libraries"
versions_folder = minecraft_folder / "versions"

# ======== DEPENDENSI TAMBAHAN (fix error download) ========
manual_libraries = {
    "com.google.guava:listenablefuture:9999.0-empty-to-avoid-conflict-with-guava":
        "https://repo1.maven.org/maven2/com/google/guava/listenablefuture/9999.0-empty-to-avoid-conflict-with-guava/listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar",
    "com.google.code.findbugs:jsr305:3.0.2":
        "https://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar",
    "org.checkerframework:checker-qual:3.43.0":
        "https://repo1.maven.org/maven2/org/checkerframework/checker-qual/3.43.0/checker-qual-3.43.0.jar",
    "com.google.j2objc:j2objc-annotations:3.0.0":
        "https://repo1.maven.org/maven2/com/google/j2objc/j2objc-annotations/3.0.0/j2objc-annotations-3.0.0.jar",
    "com.google.code.gson:gson:2.8.9":
        "https://repo1.maven.org/maven2/com/google/code/gson/gson/2.8.9/gson-2.8.9.jar"
}

def ensure_folder(path):
    if not path.exists():
        print(f"[+] Membuat folder: {path}")
        path.mkdir(parents=True, exist_ok=True)

def download_file(url, dest):
    try:
        print(f"[+] Download: {url}")
        urllib.request.urlretrieve(url, dest)
        print(f"    -> Selesai simpan di: {dest}")
    except Exception as e:
        print(f"[!] Gagal download {url}: {e}")

def download_missing_libraries():
    for lib, url in manual_libraries.items():
        parts = lib.split(":")
        group = parts[0].replace(".", "/")
        artifact = parts[1]
        version = parts[2]
        file_name = f"{artifact}-{version}.jar"
        lib_path = libraries_folder / group / artifact / version

        ensure_folder(lib_path)
        target_file = lib_path / file_name

        if not target_file.exists():
            download_file(url, target_file)
        else:
            print(f"[✓] Library sudah ada: {target_file}")

def move_mods():
    ensure_folder(mods_folder)
    local_mod_path = Path(__file__).parent / "mods"

    for mod in required_mods:
        src = local_mod_path / mod
        dst = mods_folder / mod

        if src.exists():
            shutil.copy(src, dst)
            print(f"[+] Mod ditambahkan: {dst}")
        else:
            print(f"[!] Mod tidak ditemukan: {src} (harap taruh manual di folder ./mods/)")

def main():
    print("=== Minecraft NeoForge Fixer ===")
    download_missing_libraries()
    move_mods()
    print("=== Selesai. Silakan buka TLauncher atau Minecraft Launcher ===")

if __name__ == "__main__":
    main()

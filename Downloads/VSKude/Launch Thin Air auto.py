import os
import shutil
import urllib.request
import zipfile
import subprocess

# === Pengaturan ===
minecraft_version = "1.20.4"
neoforge_version = "20.2.68-beta"
game_folder = os.path.expanduser("~/.minecraft/versions/ThinAir_Custom")
mods_folder = os.path.join(game_folder, "mods")

# List mod yang dibutuhkan
mods = {
    "ThinAir": "https://example.com/mods/ThinAir-v20.4.2-1.20.4-NeoForge.jar",
    "Undergarden": "https://example.com/mods/The_Undergarden-1.20.4-compatible.jar",
    "Corpse": "https://example.com/mods/corpse-neoforge-1.20.4-1.1.7.jar",
}

# Pastikan folder game ada
os.makedirs(mods_folder, exist_ok=True)

# Bersihkan mod yang konflik
for root, dirs, files in os.walk(mods_folder):
    for file in files:
        if "diet-quilt" in file or "unsupported" in file:
            os.remove(os.path.join(root, file))

# Download semua mod
for name, url in mods.items():
    mod_path = os.path.join(mods_folder, os.path.basename(url))
    print(f"Mengunduh {name}...")
    urllib.request.urlretrieve(url, mod_path)

print("\n Semua mod telah diunduh dan ditempatkan di:")
print(mods_folder)

# Jalankan Minecraft melalui Java command line (ubah path ini jika perlu)
java_path = "java"  # atau gunakan path absolut: "C:/Program Files/Java/jdk-17/bin/java"
jar_launcher = f"{os.path.expanduser('~')}/.minecraft/libraries/net/neoforged/neoforge/{neoforge_version}/neoforge-{neoforge_version}-universal.jar"

launch_cmd = [
    java_path,
    "-Xmx4G",
    "-jar",
    jar_launcher,
    "--username", "ThinAirPlayer",
    "--version", "ThinAir_Custom",
    "--gameDir", game_folder,
    "--assetsDir", os.path.expanduser("~/.minecraft/assets"),
]

print("\n🚀 Menjalankan Minecraft...")
subprocess.run(launch_cmd)

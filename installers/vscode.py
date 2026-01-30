from util import download_file, install_package
from pathlib import Path

VSCODE_SRC = "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
VSCODE_DST = Path(__file__).resolve().parent / "code.deb"

def install():
    download_file(VSCODE_SRC, VSCODE_DST)
    install_package(f"{VSCODE_DST}")
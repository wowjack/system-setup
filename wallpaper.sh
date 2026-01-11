wallpaper::install() {
    local src="https://github.com/fedoradesign/backgrounds/blob/f40-backgrounds/default/f40-01-night.png?raw=true"
    local dst="/usr/share/backgrounds/f40-01-night.png"

    sudo curl -fL "$src" -o "$dst"

    gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/f40-01-night.png"
    gsettings set org.gnome.desktop.background picture-uri-dark "file:///usr/share/backgrounds/f40-01-night.png"
}
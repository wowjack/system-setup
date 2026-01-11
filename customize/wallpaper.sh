WALLPAPER_DESTINATION="/usr/share/backgrounds/f40-01-night.png"

wallpaper::download() {
    local src=$(cat "$CONFIGS_DIR/wallpaper.txt")
    sudo curl -fL "$src" -o "$WALLPAPER_DESTINATION"
}

wallpaper::install() {
    wallpaper::download

    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DESTINATION"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DESTINATION"
}
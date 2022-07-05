#!/bin/bash
debian_sources=(
    contrib
    non-free
)

apt_package_list=(
    # gui
    xorg
    i3-wm
    dunst
    rofi
    polybar
    picom
    nitrogen
    lxappearance
    # utilities/tools
    pulseaudio
    network-manager
    network-manager-gnome
    kitty
    unzip
    scrot
    obs-studio
    # editors
    emacs
    vim
    gimp
    # programs
    firefox-esr
    anki
    # media
    ranger
    sxiv
    zathura
    vlc
    # other
    flatpak
    # drivers
    firmware-iwlwifi
    linux-headers-amd64
    nvidia-driver
    firmware-misc-nonfree
)

flatpak_package_list=(
    # discord
    com.discordapp.Discord
    # spotify
    com.spotify.Client
)

font_sources=(
    # Fira Code
    https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip
    # Font Awesome 5
    https://github.com/FortAwesome/Font-Awesome/releases/download/5.15.4/fontawesome-free-5.15.4-desktop.zip
)

git_sources=(
    # gtk - dracula theme - other theming done in configs themselves
    https://github.com/dracula/gtk
    # i3-gaps debian
    https://github.com/maestrogerardo/i3-gaps-deb
    # my wallpaper repository
    https://github.com/noncog/wallpapers
)

appended_sources=${debian_sources[@]}
sed -i "/^deb/ s/$/ $appended_sources/" /etc/apt/sources.list

for package in "${apt_package_list[@]}"; do
    sudo apt install -y $package
done

for package in "${flatpak_package_list[@]}"; do
    sudo flatpak install -y flathub $package
done

# create downloads folder
mkdir ${HOME}/Downloads

# download fonts
for url in "${font_sources[@]}"; do
    wget -P ${HOME}/Downloads/fonts $url
done

# unzip fonts
cd ${HOME}/Downloads/fonts
unzip "*.zip"

# create/check fonts directory
fonts_dir="${HOME}/.local/share/fonts"
if [ ! -d "${fonts_dir}" ]; then
    echo "mkdir -p $fonts_dir"
    mkdir -p "${fonts_dir}"
else
    echo "Found fonts dir $fonts_dir"
fi

# find and copy fonts to font directory
find ${HOME}/Downloads/fonts/ -name '*.ttf' -exec cp {} "${fonts_dir}" \;
find ${HOME}/Downloads/fonts/ -name '*.otf' -exec cp {} "${fonts_dir}" \;

# reload font cache
fc-cache -f

# clone git repositories
cd ${HOME}/Downloads
for url in "${git_sources[@]}"; do
    git clone $url
done

# create/check theme directory
themes_dir="${HOME}/.themes"
if [ ! -d "${themes_dir}" ]; then
    echo "mkdir -p $themes_dir"
    mkdir -p "${themes_dir}"
else
    echo "Found themes dir $themes_dir"
fi

# move and copy theme files to where they go
mv ${HOME}/Downloads/gtk $themes_dir

# create/check wallpaper directory
wallpapers_dir="${HOME}/Pictures"
if [ ! -d "${wallpapers_dir}" ]; then
    echo "mkdir -p $wallpapers_dir"
    mkdir -p "${wallpapers_dir}"
else
    echo "Found wallpapers dir $wallpapers_dir"
fi

# move and copy theme files to where they go
mv ${HOME}/Downloads/wallpapers $wallpapers_dir

# clone dotfiles
git clone --bare https://github.com/noncog/.dotfiles $HOME/.dotfiles

# checkout will backup dotfiles in the way
cd ${HOME}
mkdir -p .dotfiles-backup && \
/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
xargs -I{} mv {} .dotfiles-backup/{}

# now check out
/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout

# hide untracked files
/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME config --local status.showUntrackedFiles no

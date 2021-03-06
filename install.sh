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
    neofetch
    borgbackup
    borgmatic
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

directory_list=(
    $HOME/Books
    $HOME/Documents
    $HOME/Downloads
    $HOME/Pictures
    $HOME/Projects
    $HOME/Videos
    $HOME/.emacs.d/file-backups
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

install_debian_sources() {
    # preprocess the user source list
    appended_sources=${debian_sources[@]}
    # add to source list and update
    sudo sed -i "/^deb/ s/$/ $appended_sources/" /etc/apt/sources.list
    sudo apt update
}

install_apt_packages() {
    for package in "${apt_package_list[@]}"; do
        sudo apt install -y $package
    done
}

install_flatpak_packages() {
    for package in "${flatpak_package_list[@]}"; do
        sudo flatpak install -y flathub $package
    done
}

install_directories() {
    for directory in "${directory_list[@]}"; do
        mkdir -p $directory
    done
}

install_fonts() {
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
}

install_git_repositories() {
    # clone git repositories
    cd ${HOME}/Downloads
    for url in "${git_sources[@]}"; do
        git clone $url
    done
}

install_theme() {
    # create/check theme directory
    themes_dir="${HOME}/.themes"
    if [ ! -d "${themes_dir}" ]; then
        echo "mkdir -p $themes_dir"
        mkdir -p "${themes_dir}"
    else
        echo "Found themes dir $themes_dir"
    fi

    # move and copy theme files to where they go
    mv ${HOME}/Downloads/gtk $themes_dir/Dracula
}

install_wallpapers() {
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
}

install_i3-gaps-deb() {
    cd $HOME/Downloads/i3-gaps-deb
    /bin/bash i3-gaps-deb
}

install_dotfiles() {
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
}

# define script - used to specify script to run after restart
script="bash $HOME/debian-autosetup/install.sh"

# check if reboot flag exists
if [ ! -f $HOME/resume-after-reboot ]; then
    # run your installer scripts for pre-reboot:
    install_debian_sources
    install_apt_packages

    # add flathub remote to flatpak before rebooting
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # prepare for reboot
    # add script to .bashrc or .zshrc to resume after reboot
    echo "$script" >> $HOME/.bashrc
    # create flag to signify if resuming from reboot
    sudo touch $HOME/resume-after-reboot
    # reboot
    sudo reboot
else
    # cleanup after reboot
    # remove the script from .bashrc or .zshrc
    sed -i '/^bash/d' $HOME/.bashrc
    # remove temp flag that signifies resuming from reboot
    sudo rm -f $HOME/resume-after-reboot

    # continue with installation post-resume:
    install_flatpak_packages
    install_directories
    install_fonts
    install_git_repositories
    install_theme
    install_wallpapers
    install_i3-gaps-deb
    install_dotfiles
fi

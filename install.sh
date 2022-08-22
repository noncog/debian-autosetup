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
    ffmpeg
    neofetch
    ssh
    borgbackup
    ripgrep
    # editors
    emacs
    emacs-common-non-dfsg
    vim
    libreoffice
    # programs
    firefox-esr
    anki
    # files and media
    ranger
    sxiv
    vlc
    gimp
    # other
    flatpak
    # drivers
    firmware-iwlwifi
    linux-headers-amd64
    nvidia-driver
    firmware-misc-nonfree
)

flatpak_package_list=(
    # spotify
    com.spotify.Client
)

downloads_directory="$HOME/downloads"

directory_list=(
    $HOME/books
    $HOME/documents
    $HOME/downloads
    $HOME/pictures
    $HOME/pictures/archive
    $HOME/pictures/screenshots
    $HOME/projects
    $HOME/videos
    $HOME/videos/archive
)

font_sources=(
    # these should be zip files not repositories for use with wget!
    # Fira Code
    https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip
    # Font Awesome 5
    https://github.com/FortAwesome/Font-Awesome/releases/download/5.15.4/fontawesome-free-5.15.4-desktop.zip
)

git_sources=(
    # gtk - dracula theme
    https://github.com/dracula/gtk
    # grub - dracula theme
    https://github.com/dracula/grub
    # i3-gaps debian
    https://github.com/maestrogerardo/i3-gaps-deb
)

install_debian_sources() {
    # preprocess the user source list
    appended_sources=${debian_sources[@]}
    # add to source list and update
    sudo sed -i "/^deb/ s/$/ $appended_sources/" /etc/apt/sources.list
    sudo apt-get update
}

install_apt_packages() {
    for package in "${apt_package_list[@]}"; do
        sudo apt-get install -y $package
    done
}

install_flatpak_packages() {
    for package in "${flatpak_package_list[@]}"; do
        flatpak install -y flathub $package
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
        wget -P $downloads_directory/fonts $url
    done

    # unzip fonts
    cd $downloads_directory/fonts
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
    find $downloads_directory/fonts/ -name '*.ttf' -exec cp {} "${fonts_dir}" \;
    find $downloads_directory/fonts/ -name '*.otf' -exec cp {} "${fonts_dir}" \;

    # reload font cache
    fc-cache -f
}

install_git_repositories() {
    # clone git repositories
    cd $downloads_directory
    for url in "${git_sources[@]}"; do
        git clone $url
    done
}

install_theme() {
    # create/check .themes directory
    themes_dir="${HOME}/.themes"
    if [ ! -d "${themes_dir}" ]; then
        echo "mkdir -p $themes_dir"
        mkdir -p "${themes_dir}"
    else
        echo "Found themes dir $themes_dir"
    fi

    # create grub theme directory
    sudo mkdir /boot/grub/themes

    # move and copy theme files to where they go
    mv $downloads_directory/gtk $themes_dir/Dracula
    sudo mv $downloads_directory/grub/dracula /boot/grub/themes

    # enable grub theme
    echo "GRUB_THEME=/boot/grub/themes/dracula/theme.txt" | sudo tee -a /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

install_chemacs() {
    [ -f ~/.emacs ] && mv ~/.emacs ~/.emacs.bak
    [ -d ~/.emacs.d ] && mv ~/.emacs.d ~/.emacs.bak
    git clone https://github.com/plexus/chemacs2.git ~/.emacs.d
}

install_doom() {
    mkdir $downloads_directory/doom-emacs
    sudo mv $downloads_directory/doom-emacs /opt
    git clone --depth 1 https://github.com/doomemacs/doomemacs /opt/doom-emacs
    /opt/doom-emacs/bin/doom install
}

install_i3-gaps-deb() {
    cd $downloads_directory/i3-gaps-deb
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
    install_chemacs
    install_doom
    install_i3-gaps-deb
    install_dotfiles
fi

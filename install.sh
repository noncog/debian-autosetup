#!/usr/bin/env bash
debian_sources=(
    contrib
    non-free
)

apt_package_list=(
    anki
    barrier
    blender
    borgbackup
    cmake
    cura
    curl
    dunst
    dvipng
    emacs
    emacs-common-non-dfsg
    ffmpeg
    firefox-esr
    firmware-iwlwifi
    firmware-misc-nonfree
    flatpak
    fonts-jetbrains-mono
    gimp
    gnome-themes-standard
    gnuplot
    gtk2-engines-murrine
    gtk2-engines-pixbuf
    i3-wm
    inkscape
    kicad
    kitty
    latexmk
    libreoffice
    linux-headers-amd64
    lxappearance
    neofetch
    network-manager
    network-manager-gnome
    nitrogen
    nvidia-driver
    obs-studio
    pavucontrol
    picom
    plantuml
    polybar
    pulseaudio
    ranger
    ripgrep
    rofi
    scrot
    ssh
    sxiv
    texlive
    texlive-latex-extra
    unzip
    vim
    vlc
    xdotool
    xorg
    zathura
)

flatpak_package_list=(
    # spotify
    com.spotify.Client
)

downloads_directory="$HOME/Downloads"

directory_list=(
    $HOME/Books
    $HOME/Documents
    $HOME/Downloads
    $HOME/Pictures
    $HOME/Pictures/archive
    $HOME/Pictures/screenshots
    $HOME/Projects
    $HOME/Videos
    $HOME/Videos/archive
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

doom_directory="$HOME/.config/emacs"

install_doom() {
    git clone --depth 1 https://github.com/doomemacs/doomemacs $doom_directory
    $doom_directory/bin/doom install
}

install_i3-gaps-deb() {
    cd $downloads_directory/i3-gaps-deb
    /bin/bash i3-gaps-deb
}

install_dotfiles() {
    # define details about your dotfiles
    # DO NOT USE a trailing '/' for the following variables
    dotfiles_repo="https://github.com/noncog/.dotfiles"
    dotfiles_dir="$HOME/.dotfiles"
    dotfiles_backup_dir="$HOME/.dotfiles-backup"

    recursive_yes_or_no() {
        read -p "$1" -n 1 -r
        echo    # (optional) move to a new line
        case "$REPLY" in
            y|Y ) return 0;;
            n|N ) return 1;;
            * ) recursive_yes_or_no "$1";;
        esac
    }

    finish_install() {
        # create backups directory
        mkdir -p "$dotfiles_backup_dir"

        # move dotfiles in the way to the backups directory.
        IFS=$'\n' read -r -d '' -a dotfile_list < \
        <(/usr/bin/git --git-dir="$dotfiles_dir/" --work-tree="$HOME" checkout 2>&1 | \
        grep -E "^\s" | awk '{print $1}' && printf '\0')

        echo "Backing up dotfiles!"
        for file in "${dotfile_list[@]}"; do
            mkdir -p "$dotfiles_backup_dir"/"$file"
            echo "Moving $HOME/$file to $dotfiles_backup_dir/$file"
            mv "$HOME"/"$file" "$dotfiles_backup_dir"/"$file"
        done

        # now check out
        /usr/bin/git --git-dir="$dotfiles_dir" --work-tree="$HOME" checkout

        # hide untracked files
        /usr/bin/git --git-dir="$dotfiles_dir" --work-tree="$HOME" config --local status.showUntrackedFiles no

        echo "Dotfiles install complete!"
    }

    reinstall() {
        echo
        echo "It looks like you're trying to reinstall dotfiles from: '$dotfiles_repo'"
        if recursive_yes_or_no "Would you like to reinstall by overwriting '$dotfiles_dir'? (y/n): "; then
            echo "Removing '$dotfiles_dir'"
            rm -rf "$dotfiles_dir"
            echo "Cloning from: '$dotfiles_repo'"
            git clone --bare "$dotfiles_repo" "$dotfiles_dir"
            finish_install
        else
            echo "Aborting dotfiles install!"
        fi
    }

    # clone dotfiles
    if git clone --bare "$dotfiles_repo" "$dotfiles_dir"; then
        finish_install
    else
        reinstall
    fi
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
    install_doom
    install_i3-gaps-deb
    install_dotfiles
fi

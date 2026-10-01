# about: One package-manager syntax for apt, dnf, pacman, zypper, apk
cmd_pkg_help() {
    cat <<'H'
Usage: yayap pkg <install|remove|update|search|info|list> [PACKAGES...]
  Detects your distro's package manager and translates for you.
H
}

_pkg_manager() {
    local m
    for m in apt-get dnf yum pacman zypper apk xbps-install; do
        has "$m" && { echo "$m"; return; }
    done
    return 1
}

cmd_pkg() {
    local action="${1:-}"; shift || true
    local pm
    pm="$(_pkg_manager)" || die "no supported package manager found"
    [[ -n "$action" ]] || { cmd_pkg_help; return 1; }

    case "$pm:$action" in
        apt-get:install) as_root apt-get install -y "$@" ;;
        apt-get:remove)  as_root apt-get remove -y "$@" ;;
        apt-get:update)  as_root apt-get update && as_root apt-get upgrade -y ;;
        apt-get:search)  apt-cache search "$@" ;;
        apt-get:info)    apt-cache show "$@" ;;
        apt-get:list)    dpkg-query -W -f='${Package}\t${Version}\n' ;;

        dnf:install|yum:install) as_root "$pm" install -y "$@" ;;
        dnf:remove|yum:remove)   as_root "$pm" remove -y "$@" ;;
        dnf:update|yum:update)   as_root "$pm" upgrade -y ;;
        dnf:search|yum:search)   "$pm" search "$@" ;;
        dnf:info|yum:info)       "$pm" info "$@" ;;
        dnf:list|yum:list)       "$pm" list --installed ;;

        pacman:install) as_root pacman -S --needed --noconfirm "$@" ;;
        pacman:remove)  as_root pacman -Rns --noconfirm "$@" ;;
        pacman:update)  as_root pacman -Syu --noconfirm ;;
        pacman:search)  pacman -Ss "$@" ;;
        pacman:info)    pacman -Si "$@" ;;
        pacman:list)    pacman -Q ;;

        zypper:install) as_root zypper -n install "$@" ;;
        zypper:remove)  as_root zypper -n remove "$@" ;;
        zypper:update)  as_root zypper -n refresh && as_root zypper -n update ;;
        zypper:search)  zypper search "$@" ;;
        zypper:info)    zypper info "$@" ;;
        zypper:list)    zypper search --installed-only ;;

        apk:install) as_root apk add "$@" ;;
        apk:remove)  as_root apk del "$@" ;;
        apk:update)  as_root apk update && as_root apk upgrade ;;
        apk:search)  apk search "$@" ;;
        apk:info)    apk info -a "$@" ;;
        apk:list)    apk info -v ;;

        xbps-install:install) as_root xbps-install -y "$@" ;;
        xbps-install:remove)  as_root xbps-remove -y "$@" ;;
        xbps-install:update)  as_root xbps-install -Syu ;;
        xbps-install:search)  xbps-query -Rs "$@" ;;
        xbps-install:info)    xbps-query -R "$@" ;;
        xbps-install:list)    xbps-query -l ;;

        *) die "unknown action '$action' (try: yayap help pkg)" ;;
    esac
}

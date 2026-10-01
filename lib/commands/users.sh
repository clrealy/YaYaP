# about: User and Group Management
# category: Security and Users
cmd_users_help() {
    cat <<'H'
Usage: yayap users <list|info|add|del|passwd|addgroup|groups> [USER] [GROUP]
  list               human users (UID >= 1000) plus root
  info USER          uid, groups, home, shell
  add USER           create a user with a home directory, then set a password
  del USER           delete a user and their home directory
  passwd USER        change a password
  addgroup USER GRP  add USER to group GRP
  groups             list all groups
H
}

_valid_name() { [[ "$1" =~ ^[a-z_][a-z0-9_.-]*\$?$ && ${#1} -le 32 ]] || die "invalid name: $1"; }

cmd_users() {
    local action="${1:-list}" user="${2:-}" group="${3:-}"
    case "$action" in
        info|add|del|passwd|addgroup) [[ -n "$user" ]] || die "which user?"; _valid_name "$user" ;;
    esac
    case "$action" in
        list)
            printf '%-16s %-6s %-28s %s\n' USER UID HOME SHELL
            awk -F: '$3 == 0 || ($3 >= 1000 && $3 < 60000) {printf "%-16s %-6s %-28s %s\n", $1, $3, $6, $7}' /etc/passwd ;;
        info)
            grep -q "^$user:" /etc/passwd || die "no such user: $user"
            id "$user"
            awk -F: -v u="$user" '$1 == u {print "home:  " $6 "\nshell: " $7}' /etc/passwd ;;
        add)
            if has useradd; then as_root useradd -m -s /bin/bash "$user"
            else as_root adduser -D "$user"
            fi || die "couldn't create $user"
            ok "created $user"
            as_root passwd "$user" ;;
        del)
            confirm "delete user $user AND their home directory?" || return 1
            if has userdel; then as_root userdel -r "$user"
            else as_root deluser --remove-home "$user"
            fi && ok "deleted $user" ;;
        passwd) as_root passwd "$user" ;;
        addgroup)
            [[ -n "$group" ]] || die "which group?"; _valid_name "$group"
            if has usermod; then as_root usermod -aG "$group" "$user"
            else as_root addgroup "$user" "$group"
            fi && ok "$user added to $group (log out and back in to apply)" ;;
        groups) cut -d: -f1,3,4 /etc/group | awk -F: '{printf "%-20s %-6s %s\n", $1, $2, $3}' ;;
        *) cmd_users_help; return 1 ;;
    esac
}

cmd_users_actions() {
    cat <<'A'
List users|list
User details|info {Username}
Add a user|add {New_username}
Delete a user|del {Username}
Change a password|passwd {Username}
Add a user to a group|addgroup {Username} {Group}
List groups|groups
A
}

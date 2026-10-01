function fish_greeting
    if test -e ~/.config/no-show-user-motd
        return
    end
    if test -n "$UWELCOME_SHOWN"
        return
    end
    if not set -q UWELCOME_SHOWN
        set -gx UWELCOME_SHOWN 1
        type -q ublue-fastfetch; and ublue-fastfetch
    end
end

set -l commands status check start stop help
complete -c caffeine-watch -f
complete -c caffeine-watch -n "not __fish_seen_subcommand_from $commands" -a status -d 'show what is keeping the Mac awake'
complete -c caffeine-watch -n "not __fish_seen_subcommand_from $commands" -a check -d 'exit 0 if caffeinate is running'
complete -c caffeine-watch -n "not __fish_seen_subcommand_from $commands" -a start -d 'start caffeinate in the background'
complete -c caffeine-watch -n "not __fish_seen_subcommand_from $commands" -a stop -d 'stop one caffeinate, or all'
complete -c caffeine-watch -n "not __fish_seen_subcommand_from $commands" -a help -d 'show usage'
complete -c caffeine-watch -n "__fish_seen_subcommand_from start" -a '30m 1h 2h 4h 8h --display'
complete -c caffeine-watch -n "__fish_seen_subcommand_from stop" -a '(pgrep -x caffeinate)'

_caffeine_watch() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "status check start stop help" -- "$cur"))
    return
  fi
  case ${COMP_WORDS[1]} in
    start) COMPREPLY=($(compgen -W "30m 1h 2h 4h 8h --display" -- "$cur")) ;;
    stop) COMPREPLY=($(compgen -W "$(pgrep -x caffeinate)" -- "$cur")) ;;
  esac
}
complete -F _caffeine_watch caffeine-watch

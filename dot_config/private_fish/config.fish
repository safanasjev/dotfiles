if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

## Abbreviations

### obsidian
abbr --add obs obsidian


### eza
abbr --add ls eza -F
abbr --add ll eza -F -lh
abbr --add la eza -F -alh

### tmux
abbr --add tks tmux kill-session -t
abbr --add tls tmux ls
abbr --add ta tmux a
abbr --add tat tmux a -t
abbr --add tns tmux new -s

### chezmoi
abbr --add chez chezmoi

## Environment variables

### For bashrc syntax (export VARIABLE=value) use (set -x VARIABLE_NAME value)
set -x DYLD_LIBRARY_PATH /usr/local/lib

### Set github username
set -x GITHUB_USERNAME safanasjev

### Locale
set -x LC_CTYPE en_US.UTF-8
set -x LC_ALL en_US.UTF-8

### GPG
set -x GPG_TTY (tty)

if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

# Abbreviations
abbr --add tks tmux kill-session -t
abbr --add tls tmux ls
abbr --add tla tmux a -t

# for bashrc syntax (export VARIABLE=value) use (set -x VARIABLE_NAME value)
set -x HOMEBREW_ASK 1
set -x DYLD_LIBRARY_PATH /usr/local/lib

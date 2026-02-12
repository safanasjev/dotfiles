if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

### Abbreviations
# TMUX
abbr --add tks tmux kill-session -t
abbr --add tls tmux ls
abbr --add ta tmux a -t
abbr --add tns tmux new -s

# cd
abbr --add .. cd ..
abbr --add ... cd ../..

# for bashrc syntax (export VARIABLE=value) use (set -x VARIABLE_NAME value)
set -x DYLD_LIBRARY_PATH /usr/local/lib

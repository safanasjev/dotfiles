# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/saveli/.docker/bin"
# End of Docker Desktop section.

if status is-interactive
    # GPG
    set -gx GPG_TTY (tty)
    # Tools setup
    starship init fish | source
    zoxide init fish | source
    # Enable autosuggestions from builtin cd
    complete -c z -e
    complete -c z --wraps cd
end

# Abbreviations

## Obsidian
abbr -a obs obsidian

## Zoxide
abbr -a cd z
abbr -a cdi zi

## Eza
# eza always shows file-type indicators; abbreviations expand to it
alias eza="eza -F=always"
abbr -a ls eza
abbr -a ll eza -l
abbr -a la eza -al
abbr -a lst eza -T

## Git
abbr -c git graph 'log --all --graph --decorate --oneline'

# From https://github.com/jonhoo/configs/blob/master/shell/.config/fish/config.fish
abbr -c git spp 'stash; and git pull --rebase; and git stash pop' 

## Tmux
abbr -a tks tmux kill-session -t
abbr -a tls tmux ls
abbr -a ta tmux attach
abbr -a tat tmux attach -t
abbr -a tns tmux new -s

## Chezmoi
abbr -a cz chezmoi
abbr -c chezmoi up 'update --exclude=scripts'
abbr -c chezmoi ra 're-add'

# Environment variables

## Set Github username
set -gx GITHUB_USERNAME safanasjev

## Locale
set -gx LANG en_US.UTF-8

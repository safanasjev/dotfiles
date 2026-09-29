# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/saveli/.docker/bin"
# End of Docker Desktop section.

if status is-interactive
    # GPG
    set -gx GPG_TTY (tty)
    # Tools setup
    starship init fish | source
    zoxide init fish | source
end

# Abbreviations

## obsidian
abbr --add obs obsidian

## Eza
abbr --add ls eza
abbr --add ll eza -l
abbr --add la eza -al
abbr --add lst eza -T

## Tmux
abbr --add tks tmux kill-session -t
abbr --add tls tmux ls
abbr --add ta tmux attach
abbr --add tat tmux attach -t
abbr --add tns tmux new -s

## Chezmoi
abbr --add cz chezmoi
abbr --add czup chezmoi update --exclude=scripts
abbr --add czra chezmoi re-add
abbr --add czcd chezmoi cd

## Git
# From https://github.com/jonhoo/configs/blob/master/shell/.config/fish/config.fish
abbr -a gah 'git stash; and git pull --rebase; and git stash pop' 

# Environment variables

## Set Github username
set -gx GITHUB_USERNAME safanasjev

## Locale
set -gx LANG en_US.UTF-8

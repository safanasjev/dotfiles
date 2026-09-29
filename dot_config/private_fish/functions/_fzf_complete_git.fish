# Customize git completion
function _fzf_complete_git
  # Show header text with active branch for all git completions
  set -lx -- FZF_COMPLETION_OPTS --header="'"(git branch --show-current 2>/dev/null)"'"

  # No other changes when less than 3 arguments, or when completing options
  if not set -q argv[3]; or string match -q -- '-*' $argv[-1]
    fzf_complete
    return
  end

  # Check subcommand
  switch $argv[2]
    case checkout diff log show
      # Set preview and display all branches and commits for subcommands: checkout, diff, log, show
      begin
        git branch --all --format='%(refname:short)'
        git log --all --oneline --color=always
      end | fzf_complete --no-multi --ansi --accept-nth=1 --query=$argv[-1] --preview='git show --color=always {1}'

    case add rm mv
      # Only set preview for subcommands: add, rm, mv
      # Special characters in fish completion lists are escaped, so the r flag must be used.
      fzf_complete --preview="git diff --color=always {r1}"

    case '*'
      # No changes for other subcommands
      fzf_complete
  end
end

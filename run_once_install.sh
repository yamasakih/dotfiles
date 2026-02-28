#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

# zoxide (smarter cd)
if ! command -v zoxide &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then
    brew install zoxide
  else
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi
fi

# git completions for zsh
mkdir -p "$HOME/.zsh/completions"
if [ ! -f "$HOME/.zsh/completions/git-completion.bash" ]; then
  curl -fsSL -o "$HOME/.zsh/completions/git-completion.bash" \
    https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
fi
if [ ! -f "$HOME/.zsh/completions/_git" ]; then
  curl -fsSL -o "$HOME/.zsh/completions/_git" \
    https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh
fi

# zsh-autosuggestions
if [ ! -d "$HOME/.zsh/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
fi

# fzf
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  yes | "$HOME/.fzf/install"
fi

# bat (cat with syntax highlighting)
if ! command -v bat &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then
    brew install bat
  else
    sudo apt-get update && sudo apt-get install -y bat
  fi
fi

# starship (cross-shell prompt)
if ! command -v starship &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then
    brew install starship
  else
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
fi

# yazi (terminal file manager)
if ! command -v yazi &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then
    brew install yazi
  elif command -v cargo &>/dev/null; then
    cargo install --locked yazi-fm yazi-cli
  else
    echo "WARN: cargo not found, skipping yazi installation" >&2
  fi
fi

# keifu (git worktree manager)
if ! command -v keifu &>/dev/null; then
  if command -v cargo &>/dev/null; then
    cargo install keifu
  else
    echo "WARN: cargo not found, skipping keifu installation" >&2
  fi
fi

# gh (GitHub CLI)
if ! command -v gh &>/dev/null; then
  if [ "$OS" = "Darwin" ]; then
    brew install gh
  else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update && sudo apt-get install -y gh
  fi
fi

# git-wt
if command -v brew >/dev/null 2>&1; then
    echo "Installing git-wt..."
    brew install k1LoW/tap/git-wt
else
    echo "Homebrew is not installed. Skipping git-wt installation."
fi

# rtk
brew install rtk


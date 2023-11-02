#!/usr/bin/env bash
# set -euo pipefail

# .zshrc
cd ~/
ln -fs ~/dotfiles/.zshrc .

# .vimrc
cd ~/
ln -fs ~/dotfiles/.vimrc .

# .gitconfig
cd ~/
ln -fs ~/dotfiles/.gitconfig .

# powerline_shell
if ! command -v pip &> /dev/null; then
  apt update && apt install pipx
  pip install pipx
  pipx ensurepath
  pipx completions
  pipx install powerline_shell
else
  pip install powerline_shell
fi
echo 'export PATH=$PATH:/root/.local/bin' >> ~/.zshrc

# z
git clone git@github.com:rupa/z.git ~/z

# git completions
mkdir -p ~/.zsh/completions
cd ~/.zsh/completions
wget --version &> /dev/null
if [ $? -ne 0 ] ; then
  apt update && apt install -y --no-install-recommends wget
fi
wget https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
wget -O _git https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh

# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions

# fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
yes | ~/.fzf/install
apt update && apt install -y --no-install-recommends locales-all

# install gh
gh -version &> /dev/null
if [ $? -ne 0 ] ; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --no-tty --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install -y --no-install-recommends gh
fi

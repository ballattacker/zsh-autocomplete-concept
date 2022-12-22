If you want to try this out, first make sure [fzf](https://github.com/junegunn/fzf) and zsh are installed on your system. Then type the following commands in your terminal:
```bash
# this will put the config in /tmp/zsh
git clone --recurse-submodules https://github.com/ballattacker/zsh-autocomplete-concept.git /tmp/zsh
echo 'export ZDOTDIR=/tmp/zsh' >> ~/.zshenv
exec zsh
```

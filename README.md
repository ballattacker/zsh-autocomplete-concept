This config combine [fzf-tab](https://github.com/Aloxaf/fzf-tab) with [zsh-autosuggestion](https://github.com/zsh-users/zsh-autosuggestions) to imitate auto-completion seen in modern code editors.

This is just for demonstration purpose, so everything is extremely messy and unorganized. Expect to meet some bugs.

If you want to try this out, first make sure [fzf](https://github.com/junegunn/fzf) and zsh are installed on your system. Then type the following commands in your terminal:
```bash
# this will put the config in /tmp/zsh
git clone --recurse-submodules https://github.com/ballattacker/zsh-autocomplete-concept.git /tmp/zsh
```
```bash
env ZDOTDIR=/tmp/zsh zsh
```

Use `Ctrl` + `h`, `j`, `k`, `l` or `<Up>`, `<Down>`, `<Tab>` to navigate.

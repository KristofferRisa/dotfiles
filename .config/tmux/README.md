
# TMUX Configuration

This is a simple yet powerful TMUX configuration designed to enhance your terminal multiplexer experience. It includes intuitive keybindings, mouse support, and a clean status bar.

## 📦 Installation

This config is part of the dotfiles and is linked with the rest of them:

```bash
curl -fsSL https://kristoffer.dev/dotfiles/install | bash
```

That links `~/.config/tmux/` to this folder. tmux 3.1+ reads `~/.config/tmux/tmux.conf` on its own.

## 🎯 Key Features

- **Mouse Mode:** Scroll, select text, and switch panes using your mouse.
- **Vim Key Bindings:** Navigate in copy mode using Vim-style keys (`h`, `j`, `k`, `l`).
- **Custom Prefix Key:** Uses `Ctrl + a` as the prefix key instead of `Ctrl + b`.
- **Intuitive Pane Splitting:**
  - `|` to split vertically (left/right)
  - `-` to split horizontally (top/bottom)
- **Easy Pane Navigation:** Quickly move between panes using:
  - `Ctrl + a` then `h` (left)
  - `Ctrl + a` then `j` (down)
  - `Ctrl + a` then `k` (up)
  - `Ctrl + a` then `l` (right)
- **Pane Resizing:** `Ctrl + a` then `H`, `J`, `K` or `L` (Shift), 5 cells at a time — repeatable
- **Clean Status Bar:** Displays the user and session name.
- **OSC 52 Clipboard:** Yanks reach the local clipboard, even over SSH.
- **256-Color Support:** Ensures a better visual experience with true-color terminals.

## 🚀 Usage Tips

- **Reload TMUX Configuration:**
  `Ctrl + a`, `r` — or from a shell:
  ```bash
  tmux source-file ~/.config/tmux/tmux.conf
  ```

- **Detach from Session:**
  ```bash
  Ctrl + a, d
  ```

- **List Sessions:**
  ```bash
  tmux ls
  ```

- **Attach to Session:**
  ```bash
  tmux attach-session -t <session_name>
  ```

- **Kill Session:**
  ```bash
  tmux kill-session -t <session_name>
  ```

## 🛠️ Customization

Feel free to modify `tmux.conf` to suit your preferences. Here are some suggested tweaks:

- Change the prefix key back to `Ctrl + b` if preferred:
  ```bash
  set-option -g prefix C-b
  unbind C-a
  bind C-b send-prefix
  ```

- Increase the scrollback buffer size:
  ```bash
  set-option -g history-limit 20000
  ```

## 📚 Resources

- [Official TMUX Documentation](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [A Quick and Practical Guide to TMUX](https://tmuxcheatsheet.com/)

## 💬 Support

If you encounter any issues or have suggestions for improvements, please open an issue on the [GitHub repository](https://github.com/kristofferrisa/dotfiles/issues).

## 📄 License

This TMUX configuration is open-source and available under the [MIT License](./LICENSE).

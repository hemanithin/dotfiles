# dotfiles

Personal config backup.

- `shell/`   – .bashrc, .profile, .bash_logout
- `git/`     – .gitconfig etc.
- `docker/`  – docker-compose.yml files (one subfolder per stack)
- `nginx/`   – nginx configs
- `configs/` – other app configs

Run `./install.sh` to symlink shell files into `$HOME`.
Never commit secrets (.env, keys) – see `.gitignore`.

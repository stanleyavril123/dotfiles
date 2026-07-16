#!/usr/bin/env bash

set -Eeuo pipefail

readonly DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly NVIM_VERSION="0.10.3"
readonly KITTY_VERSION="0.32.2"
readonly NERD_FONT_VERSION="3.3.0"
readonly NVIM_DIR="$HOME/.local/opt/nvim-v${NVIM_VERSION}"
readonly FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont-${NERD_FONT_VERSION}"

LINK_ONLY=false
INSTALL_AGENTS=true

usage() {
	cat <<EOF
Usage: $(basename -- "$0") [options]

Options:
  --link-only  Only link configuration files; do not install software
  --no-agents  Skip installation of optional coding-agent CLIs
  -h, --help   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--link-only) LINK_ONLY=true ;;
		--no-agents) INSTALL_AGENTS=false ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
	shift
done

log() {
	printf '\n==> %s\n' "$*"
}

link_dotfile() {
	local source="$1"
	local target="$2"
	local backup

	mkdir -p "$(dirname -- "$target")"
	if [[ -L "$target" ]] && [[ "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
		printf 'Already linked: %s\n' "$target"
		return
	fi

	if [[ -e "$target" || -L "$target" ]]; then
		backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
		mv -- "$target" "$backup"
		printf 'Backed up %s to %s\n' "$target" "$backup"
	fi

	ln -s -- "$source" "$target"
	printf 'Linked %s -> %s\n' "$target" "$source"
}

install_packages() {
	local -a elevate=()

	if ! command -v apt-get >/dev/null 2>&1; then
		printf 'Automatic package installation supports Ubuntu/Debian only. Use --link-only on this system.\n' >&2
		exit 1
	fi
	if [[ $EUID -ne 0 ]]; then
		if ! command -v sudo >/dev/null 2>&1; then
			printf 'sudo is required to install system packages.\n' >&2
			exit 1
		fi
		elevate=(sudo)
	fi

	log "Installing Ubuntu dependencies"
	"${elevate[@]}" apt-get update
	"${elevate[@]}" apt-get install -y \
		build-essential ca-certificates curl fd-find fontconfig git jq libxcb-xkb1 nodejs \
		python3 python3-venv ripgrep tmux unzip wl-clipboard xclip xz-utils

	# NodeSource bundles npm with nodejs and conflicts with Debian's separate npm package.
	# The Ubuntu/Debian nodejs package does not bundle it, so install it only when needed.
	if ! command -v npm >/dev/null 2>&1; then
		"${elevate[@]}" apt-get install -y npm
	fi
}

install_claude() {
	if command -v claude >/dev/null 2>&1; then
		printf 'Claude Code is already installed.\n'
		return
	fi

	log "Installing Claude Code (stable channel)"
	curl --fail --silent --show-error --location https://claude.ai/install.sh | bash -s stable
}

install_neovim() {
	local archive
	local asset_arch
	local temp_dir

	case "$(uname -m)" in
		x86_64) asset_arch="64" ;;
		aarch64 | arm64) asset_arch="arm64" ;;
		*)
			printf 'Unsupported CPU architecture: %s\n' "$(uname -m)" >&2
			exit 1
			;;
	esac

	if [[ -x "$NVIM_DIR/bin/nvim" ]] && "$NVIM_DIR/bin/nvim" --version | head -1 | grep -q "v${NVIM_VERSION}"; then
		printf 'Neovim %s is already installed.\n' "$NVIM_VERSION"
	else
		log "Installing Neovim ${NVIM_VERSION}"
		temp_dir="$(mktemp -d)"
		archive="$temp_dir/nvim.tar.gz"
		curl --fail --location --retry 3 \
			"https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux${asset_arch}.tar.gz" \
			--output "$archive"
		mkdir -p "$NVIM_DIR"
		tar -xzf "$archive" --strip-components=1 -C "$NVIM_DIR"
		rm -rf -- "$temp_dir"
	fi

	mkdir -p "$HOME/.local/bin"
	ln -sfn -- "$NVIM_DIR/bin/nvim" "$HOME/.local/bin/nvim"
}

install_kitty() {
	if [[ -x "$HOME/.local/kitty.app/bin/kitty" ]] && \
		"$HOME/.local/kitty.app/bin/kitty" --version | grep -q " ${KITTY_VERSION} "; then
		printf 'Kitty %s is already installed.\n' "$KITTY_VERSION"
	else
		log "Installing Kitty ${KITTY_VERSION}"
		curl --fail --location --retry 3 https://sw.kovidgoyal.net/kitty/installer.sh | \
			sh /dev/stdin "installer=version-${KITTY_VERSION}" launch=n
	fi

	mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
	ln -sfn -- "$DOTFILES_DIR/bin/kitty" "$HOME/.local/bin/kitty"
	ln -sfn -- "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
	cp -- "$HOME/.local/kitty.app/share/applications/kitty.desktop" \
		"$HOME/.local/share/applications/kitty.desktop"
	sed -i \
		-e "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
		-e "s|Exec=kitty|Exec=$HOME/.local/bin/kitty|g" \
		"$HOME/.local/share/applications/kitty.desktop"
}

install_font() {
	local archive
	local temp_dir

	if [[ -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]]; then
		printf 'JetBrainsMono Nerd Font %s is already installed.\n' "$NERD_FONT_VERSION"
		return
	fi

	log "Installing JetBrainsMono Nerd Font ${NERD_FONT_VERSION}"
	temp_dir="$(mktemp -d)"
	archive="$temp_dir/JetBrainsMono.tar.xz"
	curl --fail --location --retry 3 \
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/JetBrainsMono.tar.xz" \
		--output "$archive"
	mkdir -p "$FONT_DIR"
	tar -xJf "$archive" -C "$FONT_DIR"
	rm -rf -- "$temp_dir"
	fc-cache -f
}

link_configs() {
	log "Linking dotfiles"
	link_dotfile "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
	link_dotfile "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"
	link_dotfile "$DOTFILES_DIR/.config/git/ignore" "$HOME/.config/git/ignore"
	link_dotfile "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
	link_dotfile "$DOTFILES_DIR/bin/agent-hooks" "$HOME/.local/bin/agent-hooks"
}

check_path() {
	case ":$PATH:" in
		*":$HOME/.local/bin:"*) ;;
		*)
			printf '\nNote: add %s to PATH, then log out and back in:\n' "$HOME/.local/bin"
			printf '  export PATH="$HOME/.local/bin:$PATH"\n'
			;;
	esac
}

restore_neovim() {
	log "Restoring Neovim plugins"
	"$HOME/.local/bin/nvim" --headless "+Lazy! restore" +qa
	"$HOME/.local/bin/nvim" --headless "+TSUpdateSync" +qa
	"$HOME/.local/bin/nvim" --headless "+MasonToolsInstallSync" +qa
}

main() {
	if [[ "$LINK_ONLY" == false ]]; then
		install_packages
		install_neovim
		install_kitty
		install_font
		if [[ "$INSTALL_AGENTS" == true ]]; then
			install_claude
		fi
	fi

	link_configs
	check_path

	if [[ "$LINK_ONLY" == false ]]; then
		restore_neovim
	fi

	log "Dotfiles installation complete"
	printf 'Restart Kitty, then start tmux and Neovim normally.\n'
}

main

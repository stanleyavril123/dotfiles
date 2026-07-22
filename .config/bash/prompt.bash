# Shell prompt shared by interactive Bash sessions.
export STARSHIP_CONFIG="$HOME/.config/starship.toml"

if command -v starship >/dev/null 2>&1 && [[ -z ${STARSHIP_SESSION_KEY:-} ]]; then
	eval "$(starship init bash)"
fi

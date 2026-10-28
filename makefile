setup: os wezterm herdr ghostty nix ghtkn

.PHONY: help setup mac uv-check
os:bootstrap/setup.pm
	perl bootstrap/setup.pm

wezterm:bootstrap/wezterm.pm
	perl bootstrap/wezterm.pm

herdr:bootstrap/herdr.pm
	perl bootstrap/herdr.pm

ghostty:bootstrap/ghostty.pm
	perl bootstrap/ghostty.pm

nix:bootstrap/nix.pm
	perl bootstrap/nix.pm

ghtkn:bootstrap/ghtkn.pm
	perl bootstrap/ghtkn.pm

mac: os
linux: os

.PHONY: help setup os wezterm herdr ghostty nix ghtkn nix-repair nix-update nix-sync mac linux

help:
	@echo "Available targets:"
	@echo "  make setup    # Setup dotfiles for current OS (macOS / Linux)"
	@echo "  make os       # Alias of setup"
	@echo "  make wezterm  # Link WezTerm config (~/.config/wezterm)"
	@echo "  make herdr    # Link herdr config (~/.config/herdr/config.toml)"
	@echo "  make ghostty  # Link Ghostty config (~/.config/ghostty/config)"
	@echo "  make nix      # Link Nix config (~/.config/nix/nix.conf)"
	@echo "  make ghtkn    # Link ghtkn config (~/.config/ghtkn/ghtkn.yaml)"
	@echo "  make nix-repair # Repair /nix mount after macOS upgrade (needs sudo)"
	@echo "  make nix-update # Update nix/flake.lock, build, and upgrade the profile (primary Mac)"
	@echo "  make nix-sync   # Reinstall dotfiles-tools from the committed lock (other Macs)"
	@echo "  make mac      # Alias of setup"
	@echo "  make linux    # Alias of setup"
	@echo "  make uv-check # Check uv via Nix flake shell"

nix-repair: nix-repair.sh
	sudo bash nix-repair.sh

uv-check:
	@nix develop ./nix -c uv --version

# 普段使いの Mac で実行: lock を進めてビルド確認し、profile を入れ直す。
# 終わったら nix/flake.lock を commit / push する。
nix-update:
	nix flake update --flake ./nix
	nix build ./nix#dotfiles-tools --no-link
	nix profile upgrade nix
	nix profile list

# 他の Mac で実行: git pull 済みの lock のまま profile を入れ直す。
nix-sync:
	nix profile upgrade nix
	nix profile list

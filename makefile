setup: os wezterm herdr ghostty

.PHONY: help setup mac uv-check
os:bootstrap/setup.pm
	perl bootstrap/setup.pm

wezterm:bootstrap/wezterm.pm
	perl bootstrap/wezterm.pm

herdr:bootstrap/herdr.pm
	perl bootstrap/herdr.pm

ghostty:bootstrap/ghostty.pm
	perl bootstrap/ghostty.pm

mac: os
linux: os

.PHONY: help setup os wezterm herdr ghostty mac linux

help:
	@echo "Available targets:"
	@echo "  make setup    # Setup dotfiles for current OS (macOS / Linux)"
	@echo "  make os       # Alias of setup"
	@echo "  make wezterm  # Link WezTerm config (~/.config/wezterm)"
	@echo "  make herdr    # Link herdr config (~/.config/herdr/config.toml)"
	@echo "  make ghostty  # Link Ghostty config (~/.config/ghostty/config)"
	@echo "  make mac      # Alias of setup"
	@echo "  make linux    # Alias of setup"
	@echo "  make uv-check # Check uv via Nix flake shell"

uv-check:
	@nix develop ./nix -c uv --version

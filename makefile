setup: os wezterm herdr ghostty nix ghtkn cmux

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

cmux:bootstrap/cmux.pm
	perl bootstrap/cmux.pm

mac: os
linux: os

.PHONY: help setup os wezterm herdr ghostty nix ghtkn cmux nix-repair nix-update nix-sync mac linux \
	check lint lint-workflows fmt fmt-check build rollback outdated

help:
	@echo "Available targets:"
	@echo "  make setup    # Setup dotfiles for current OS (macOS / Linux)"
	@echo "  make os       # Alias of setup"
	@echo "  make wezterm  # Link WezTerm config (~/.config/wezterm)"
	@echo "  make herdr    # Link herdr config (~/.config/herdr/config.toml)"
	@echo "  make ghostty  # Link Ghostty config (~/.config/ghostty/config)"
	@echo "  make nix      # Link Nix config (~/.config/nix/nix.conf)"
	@echo "  make ghtkn    # Link ghtkn config (~/.config/ghtkn/ghtkn.yaml)"
	@echo "  make cmux     # Link cmux config and the Nix app (Apple Silicon macOS)"
	@echo "  make nix-repair # Repair /nix mount after macOS upgrade (needs sudo)"
	@echo "  make nix-update # Update nix/flake.lock, build, and upgrade the profile (primary Mac)"
	@echo "  make nix-sync   # Reinstall dotfiles-tools from the committed lock (other Macs)"
	@echo "  make check      # Run everything CI runs (lint + nix flake check)"
	@echo "  make lint       # Perl syntax check of bootstrap/*.pm (+ lint-workflows)"
	@echo "  make lint-workflows # Fail if a workflow uses a *-latest runner label"
	@echo "  make fmt        # Format nix/**/*.nix with nixfmt"
	@echo "  make fmt-check  # Fail if any nix/**/*.nix is not formatted"
	@echo "  make build      # Build dotfiles-tools without touching the profile"
	@echo "  make rollback   # Roll the Nix profile back one generation"
	@echo "  make outdated   # List flake inputs / pinned packages that may be outdated"
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

# ---- 検査・整形（CI の check workflow も `make check` を実行する） ----

NIX_FILES_CMD = find . -name '*.nix' -not -path './result*'

# push 前に手元で確認する。CI と同じ内容。
check: lint
	nix flake check ./nix --all-systems --no-build
	nix flake check ./nix -L

lint: lint-workflows
	@for f in bootstrap/*.pm; do perl -c "$$f" || exit 1; done

# runner は `ubuntu-26.04` のように版を固定する。`*-latest` は OS が知らないうちに上がるため禁止。
lint-workflows:
	@if grep -rnE '(ubuntu|macos|windows)-latest' .github/workflows; then \
		echo 'error: runs-on に *-latest は使わず、ubuntu-26.04 のように版を固定してください' >&2; \
		exit 1; \
	fi

fmt:
	cd nix && $(NIX_FILES_CMD) -print0 | xargs -0 nix fmt --

fmt-check:
	cd nix && $(NIX_FILES_CMD) -print0 | xargs -0 nix fmt -- --check

build:
	nix build ./nix#dotfiles-tools --no-link -L

# nix-update / nix-sync で入れた profile がおかしいときに 1 世代戻す。
rollback:
	nix profile rollback
	nix profile list

outdated:
	@perl scripts/outdated

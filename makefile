# シェルの PATH から Nix が抜けていても動くよう、nix は固定パスにフォールバックする。
# (macOS 標準の GNU Make 3.81 は export した PATH をコマンド探索に使わないので、
#  PATH を足す方法では直らない)
NIX := $(shell command -v nix 2>/dev/null || echo /nix/var/nix/profiles/default/bin/nix)

setup: os wezterm herdr ghostty nix ghtkn ssh cmux raycast karabiner lazyvim

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

ssh:bootstrap/ssh.pm
	perl bootstrap/ssh.pm

cmux:bootstrap/cmux.pm
	perl bootstrap/cmux.pm

raycast:bootstrap/raycast.pm
	perl bootstrap/raycast.pm

karabiner:bootstrap/karabiner.pm
	perl bootstrap/karabiner.pm

lazyvim:bootstrap/lazyvim.pm
	perl bootstrap/lazyvim.pm

# setup には含めない（任意機能）。docs/spotify-cache.md を参照。
spotify-cache-monitor:bootstrap/spotify-cache-monitor.pm
	perl bootstrap/spotify-cache-monitor.pm

spotify-cache-monitor-uninstall:bootstrap/spotify-cache-monitor.pm
	perl bootstrap/spotify-cache-monitor.pm uninstall

mac: os
linux: os

.PHONY: help setup os wezterm herdr ghostty nix ghtkn ssh cmux raycast karabiner lazyvim spotify-cache-monitor spotify-cache-monitor-uninstall nix-repair nix-doctor nix-update nix-sync mac linux \
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
	@echo "  make ssh      # Use the 1Password SSH agent (adds one Include line to ~/.ssh/config if missing)"
	@echo "  make cmux     # Link cmux config and the Nix app (Apple Silicon macOS)"
	@echo "  make raycast  # Link the Nix Raycast app and restart it if running (Apple Silicon macOS)"
	@echo "  make karabiner # Link Karabiner-Elements config and install the pinned official pkg (Apple Silicon macOS, may need sudo)"
	@echo "  make lazyvim  # Link the separate LazyVim config"
	@echo "  make spotify-cache-monitor # Enable the weekly Spotify cache size notification (macOS, not in setup)"
	@echo "  make spotify-cache-monitor-uninstall # Disable it and remove the LaunchAgent plist"
	@echo "  make nix-repair # Repair /nix mount after macOS upgrade (needs sudo)"
	@echo "  make nix-doctor # Diagnose why nix is missing from this shell (changes nothing)"
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

nix-doctor:
	@bash scripts/nix-doctor

uv-check:
	@$(NIX) develop ./nix -c uv --version

# 普段使いの Mac で実行: lock を進めてビルド確認し、profile を入れ直す。
# 終わったら nix/flake.lock を commit / push する。
nix-update:
	$(NIX) flake update --flake ./nix
	$(NIX) build ./nix#dotfiles-tools --no-link
	entry=$$(perl scripts/nix-profile-entry $(NIX)) && $(NIX) profile upgrade "$$entry"
	$(NIX) profile list

# 他の Mac で実行: git pull 済みの lock のまま profile を入れ直す。
# profile の entry 名は端末ごとに違う（`nix` / `nix-1` など）ので、flake attribute から探す。
nix-sync:
	entry=$$(perl scripts/nix-profile-entry $(NIX)) && $(NIX) profile upgrade "$$entry"
	$(NIX) profile list

# ---- 検査・整形（CI の check workflow も `make check` を実行する） ----

NIX_FILES_CMD = find . -name '*.nix' -not -path './result*'

# push 前に手元で確認する。CI と同じ内容。
check: lint
	$(NIX) flake check ./nix --all-systems --no-build
	$(NIX) flake check ./nix -L

lint: lint-workflows
	@for f in bootstrap/*.pm; do perl -c "$$f" || exit 1; done

# runner は `ubuntu-26.04` のように版を固定する。`*-latest` は OS が知らないうちに上がるため禁止。
lint-workflows:
	@if grep -rnE '(ubuntu|macos|windows)-latest' .github/workflows; then \
		echo 'error: runs-on に *-latest は使わず、ubuntu-26.04 のように版を固定してください' >&2; \
		exit 1; \
	fi

fmt:
	cd nix && $(NIX_FILES_CMD) -print0 | xargs -0 $(NIX) fmt --

fmt-check:
	cd nix && $(NIX_FILES_CMD) -print0 | xargs -0 $(NIX) fmt -- --check

build:
	$(NIX) build ./nix#dotfiles-tools --no-link -L

# nix-update / nix-sync で入れた profile がおかしいときに 1 世代戻す。
rollback:
	$(NIX) profile rollback
	$(NIX) profile list

outdated:
	@perl scripts/outdated

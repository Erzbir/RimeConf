.DEFAULT_GOAL := update

SCHEME_PACKAGES := packages/rime-ice packages/rime-kagiroi

RSYNC := rsync
RSYNC_FLAGS := -avcm
RULE_DIR := rules
DENY := $(RULE_DIR)/deny.txt
ICE := $(RULE_DIR)/ice.txt
KAGIROI := $(RULE_DIR)/kagiroi.txt
BACKUP := .scheme-backups/last
UPDATE_STATE := .scheme-backups/update

.PHONY: sync update update-all help rules backup backup-all copy-pulled copy-changed copy-all restore

sync: $(DENY) $(ICE) $(KAGIROI)
	@set -eu; \
	state="$(UPDATE_STATE)"; \
	rm -rf "$$state"; \
	mkdir -p "$$state"
	git pull --ff-only
	git submodule sync --recursive
	git submodule update --init --recursive
	@set -eu; \
	state="$(UPDATE_STATE)"; \
	mkdir -p "$$state/empty"; \
	collect_pulled() { \
		package="$$1"; \
		name="$$2"; \
		branch="$$3"; \
		before=$$(git -C "$$package" rev-parse --verify HEAD 2>/dev/null || true); \
		printf '%s\n' "$$before" > "$$state/$$name.before"; \
		printf '\n== pull: %s ==\n' "$$package"; \
		git -C "$$package" pull --ff-only origin "$$branch"; \
		after=$$(git -C "$$package" rev-parse --verify HEAD 2>/dev/null || true); \
		printf '%s\n' "$$after" > "$$state/$$name.after"; \
		: > "$$state/$$name.pulled"; \
		if [ -z "$$after" ] || [ "$$before" = "$$after" ]; then \
			return; \
		fi; \
		if [ -z "$$before" ]; then \
			git -C "$$package" ls-files; \
		else \
			tab=$$(printf '\t'); \
			git -C "$$package" diff --name-status --find-renames "$$before" "$$after" | \
			while IFS="$$tab" read -r change path rest; do \
				case "$$change" in \
					D*) continue ;; \
					R*|C*) path="$$rest" ;; \
				esac; \
				[ -n "$$path" ] || continue; \
				[ -f "$$package/$$path" ] || continue; \
				printf '%s\n' "$$path"; \
			done; \
		fi | sort -u > "$$state/$$name.pulled"; \
	}; \
	filter_pulled() { \
		package="$$1"; \
		allow="$$2"; \
		name="$$3"; \
		allowed="$$state/$$name.allowed"; \
		raw="$$state/$$name.pulled"; \
		paths="$$state/$$name.paths"; \
		$(RSYNC) -rcmn --out-format='%n' --exclude-from=$(DENY) --include='*/' --include-from="$$allow" --exclude='*' "$$package"/ "$$state/empty"/ > "$$allowed.tmp"; \
		while IFS= read -r path; do \
			case "$$path" in ''|*/) continue ;; esac; \
			printf '%s\n' "$$path"; \
		done < "$$allowed.tmp" | sort -u > "$$allowed"; \
		if [ -s "$$raw" ]; then \
			grep -Fxf "$$allowed" "$$raw" > "$$paths" || true; \
		else \
			: > "$$paths"; \
		fi; \
		count=$$(wc -l < "$$paths" | tr -d ' '); \
		printf '%s: %s allowed pulled file(s)\n' "$$package" "$$count"; \
	}; \
	collect_pulled packages/rime-ice rime-ice main; \
	collect_pulled packages/rime-kagiroi rime-kagiroi main; \
	filter_pulled packages/rime-ice "$(ICE)" rime-ice; \
	filter_pulled packages/rime-kagiroi "$(KAGIROI)" rime-kagiroi; \
	cat "$$state/rime-ice.paths" "$$state/rime-kagiroi.paths" | sort -u > "$$state/paths"; \
	rm -rf "$$state/empty" "$$state"/*.tmp; \
	total=$$(wc -l < "$$state/paths" | tr -d ' '); \
	printf 'copy candidate(s): %s\n' "$$total"

update:
	@$(MAKE) sync
	@$(MAKE) backup
	@$(MAKE) copy-pulled

update-all:
	@$(MAKE) sync
	@$(MAKE) backup-all
	@$(MAKE) copy-all

copy-pulled:
	@set -eu; \
	state="$(UPDATE_STATE)"; \
	copy_package() { \
		package="$$1"; \
		name="$$2"; \
		list="$$state/$$name.paths"; \
		if [ ! -s "$$list" ]; then \
			printf '\n== copy: %s -> . (no pulled files) ==\n' "$$package"; \
			return; \
		fi; \
		if [ ! -d "$$package" ]; then printf 'missing package: %s\n' "$$package" >&2; exit 1; fi; \
		printf '\n== copy: %s -> . ==\n' "$$package"; \
		$(RSYNC) $(RSYNC_FLAGS) --itemize-changes --files-from="$$list" "$$package"/ ./; \
	}; \
	if [ ! -f "$$state/paths" ]; then printf 'missing change list: run make sync first\n' >&2; exit 1; fi; \
	copy_package packages/rime-ice rime-ice; \
	copy_package packages/rime-kagiroi rime-kagiroi

copy-changed: copy-pulled

copy-all: $(DENY) $(ICE) $(KAGIROI)
	@if [ ! -d packages/rime-ice ]; then printf 'missing package: %s\n' packages/rime-ice >&2; exit 1; fi
	@printf '\n== copy: packages/rime-ice -> . ==\n'
	@$(RSYNC) $(RSYNC_FLAGS) --itemize-changes --exclude-from=$(DENY) --include='*/' --include-from=$(ICE) --exclude='*' packages/rime-ice/ ./
	@if [ ! -d packages/rime-kagiroi ]; then printf 'missing package: %s\n' packages/rime-kagiroi >&2; exit 1; fi
	@printf '\n== copy: packages/rime-kagiroi -> . ==\n'
	@$(RSYNC) $(RSYNC_FLAGS) --itemize-changes --exclude-from=$(DENY) --include='*/' --include-from=$(KAGIROI) --exclude='*' packages/rime-kagiroi/ ./

rules: $(DENY) $(ICE) $(KAGIROI)
	@printf '%s\n' 'Packages: $(SCHEME_PACKAGES)'
	@printf '%s\n' 'Deny: $(DENY)'
	@sed 's/^/  /' $(DENY)
	@printf '%s\n' 'Allow for packages/rime-ice: $(ICE)'
	@sed 's/^/  /' $(ICE)
	@printf '%s\n' 'Allow for packages/rime-kagiroi: $(KAGIROI)'
	@sed 's/^/  /' $(KAGIROI)

backup:
	@set -eu; \
	state="$(UPDATE_STATE)"; \
	paths="$$state/paths"; \
	backup="$(BACKUP)"; \
	if [ ! -f "$$paths" ]; then printf 'missing change list: run make sync first\n' >&2; exit 1; fi; \
	if [ ! -s "$$paths" ]; then printf 'backup: no pulled files\n'; exit 0; fi; \
	rm -rf "$$backup"; \
	mkdir -p "$$backup/files"; \
	cp "$$paths" "$$backup/paths"; \
	: > "$$backup/manifest"; \
	while IFS= read -r path; do \
		[ -n "$$path" ] || continue; \
		if [ -e "$$path" ]; then \
			mkdir -p "$$backup/files/$$(dirname "$$path")"; \
			cp -p "$$path" "$$backup/files/$$path"; \
			printf 'present\t%s\n' "$$path" >> "$$backup/manifest"; \
		else \
			printf 'absent\t%s\n' "$$path" >> "$$backup/manifest"; \
		fi; \
	done < "$$backup/paths"; \
	printf 'backup: %s\n' "$$backup"

backup-all: $(DENY) $(ICE) $(KAGIROI)
	@set -eu; \
	backup="$(BACKUP)"; \
	empty="$$backup/empty"; \
	rm -rf "$$backup"; \
	mkdir -p "$$backup/files" "$$empty"; \
	: > "$$backup/touched"; \
	collect() { \
		package="$$1"; \
		allow="$$2"; \
		if [ ! -d "$$package" ]; then printf 'missing package: %s\n' "$$package" >&2; exit 1; fi; \
		$(RSYNC) -rcmn --out-format='%n' --exclude-from=$(DENY) --include='*/' --include-from="$$allow" --exclude='*' "$$package"/ "$$empty"/ > "$$backup/list"; \
		while IFS= read -r path; do \
			case "$$path" in ''|*/) continue ;; esac; \
			printf '%s\n' "$$path" >> "$$backup/touched"; \
		done < "$$backup/list"; \
	}; \
	collect packages/rime-ice "$(ICE)"; \
	collect packages/rime-kagiroi "$(KAGIROI)"; \
	sort -u "$$backup/touched" > "$$backup/paths"; \
	: > "$$backup/manifest"; \
	while IFS= read -r path; do \
		[ -n "$$path" ] || continue; \
		if [ -e "$$path" ]; then \
			mkdir -p "$$backup/files/$$(dirname "$$path")"; \
			cp -p "$$path" "$$backup/files/$$path"; \
			printf 'present\t%s\n' "$$path" >> "$$backup/manifest"; \
		else \
			printf 'absent\t%s\n' "$$path" >> "$$backup/manifest"; \
		fi; \
	done < "$$backup/paths"; \
	rm -rf "$$empty" "$$backup/list" "$$backup/touched"; \
	printf 'backup: %s\n' "$$backup"

restore:
	@set -eu; \
	backup="$(BACKUP)"; \
	if [ ! -f "$$backup/manifest" ]; then printf 'missing backup: %s\n' "$$backup" >&2; exit 1; fi; \
	tab=$$(printf '\t'); \
	while IFS="$$tab" read -r state path; do \
		[ -n "$$path" ] || continue; \
		case "$$state" in \
			present) \
				if [ ! -f "$$backup/files/$$path" ]; then printf 'missing backup file: %s\n' "$$path" >&2; exit 1; fi; \
				mkdir -p "$$(dirname "$$path")"; \
				cp -p "$$backup/files/$$path" "$$path"; \
				;; \
			absent) \
				rm -f "$$path"; \
				dir=$$(dirname "$$path"); \
				while [ "$$dir" != "." ] && [ "$$dir" != "/" ]; do \
					rmdir "$$dir" 2>/dev/null || break; \
					dir=$$(dirname "$$dir"); \
				done; \
				;; \
			*) \
				printf 'bad manifest entry: %s %s\n' "$$state" "$$path" >&2; \
				exit 1; \
				;; \
		esac; \
	done < "$$backup/manifest"; \
	printf 'restored: %s\n' "$$backup"

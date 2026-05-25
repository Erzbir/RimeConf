.DEFAULT_GOAL := update

SCHEME_PACKAGES := packages/rime-ice packages/rime-kagiroi

RSYNC := rsync
RSYNC_FLAGS := -avcm
RULE_DIR := rules
DENY := $(RULE_DIR)/deny.txt
ICE := $(RULE_DIR)/ice.txt
KAGIROI := $(RULE_DIR)/kagiroi.txt
BACKUP := .scheme-backups/last

.PHONY: sync update help rules backup restore

sync:
	git pull --ff-only --recurse-submodules
	git submodule sync --recursive
	git submodule update --init --recursive

update: backup sync $(DENY) $(ICE) $(KAGIROI)
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

backup: $(DENY) $(ICE) $(KAGIROI)
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

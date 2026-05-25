.DEFAULT_GOAL := update

.PHONY: update help

update:
	git pull --ff-only --recurse-submodules
	git submodule sync --recursive
	git submodule update --init --recursive

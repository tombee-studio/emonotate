.PHONY: setup help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  setup   Configure local git hooks (run once after cloning)"

setup:
	git config core.hooksPath .githooks
	@echo "Git hooks configured. (.githooks/commit-msg, .githooks/pre-push are now active)"

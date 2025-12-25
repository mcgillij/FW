.PHONY: test test-verbose docs

# Headless smoke/CI run (exit code is controlled by tests/TestBootstrap.gd)
test:
	./scripts/test_headless.sh

test-verbose:
	./scripts/test_headless.sh --verbose

# Regenerate API docs
docs:
	python3 scripts/generate_api_docs.py
	@echo "Wrote docs/api/generated.md"

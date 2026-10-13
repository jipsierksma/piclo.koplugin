# Development tasks; run from the repo root.
LUA ?= luajit

# Files that ship in the plugin zip; tools/, spec/, docs/ and dotfiles don't.
RUNTIME := _meta.lua main.lua piclo LICENSE CREDITS.md
DIST := piclo.koplugin.zip

.PHONY: test validate stats dist clean

test:
	$(LUA) spec/run.lua spec/*_spec.lua

validate:
	$(LUA) tools/validate.lua

stats:
	$(LUA) tools/stats.lua

dist: test validate
	rm -rf build $(DIST)
	mkdir -p build/piclo.koplugin
	cp -R $(RUNTIME) build/piclo.koplugin/
	find build -name '.*' -exec rm -rf {} +
	cd build && zip -qrX ../$(DIST) piclo.koplugin
	rm -rf build
	@unzip -l $(DIST) | tail -1

clean:
	rm -rf build $(DIST)

# Development tasks; run from the repo root.
LUA ?= luajit

# Files that ship in the plugin zip; tools/, spec/, docs/ and dotfiles don't.
RUNTIME := _meta.lua main.lua piclo l10n LICENSE CREDITS.md
DIST := piclo.koplugin.zip

.PHONY: test validate stats dist clean pot lint

test:
	$(LUA) spec/run.lua spec/*_spec.lua

validate:
	$(LUA) tools/validate.lua

# Needs luacheck (e.g. brew install luacheck); settings in .luacheckrc.
lint:
	luacheck --no-color --formatter plain .

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

# Collects every translatable string into l10n/piclo.pot and merges it into
# each language's piclo.po (new strings appear there untranslated).
pot:
	xgettext --language=Lua --from-code=UTF-8 --keyword=_ --keyword=N_:1,2 --keyword=C_:1c,2 \
		--sort-by-file --package-name=Piclo --output=l10n/piclo.pot \
		main.lua $$(find piclo -name '*.lua' | sort)
	for po in l10n/*/piclo.po; do [ -f "$$po" ] && msgmerge --quiet --update --backup=none $$po l10n/piclo.pot || true; done

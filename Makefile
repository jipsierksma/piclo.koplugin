# Development tasks; run from the repo root.
LUA ?= luajit

.PHONY: test validate stats

test:
	$(LUA) spec/run.lua spec/*_spec.lua

validate:
	$(LUA) tools/validate.lua

stats:
	$(LUA) tools/stats.lua

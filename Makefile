# Development tasks. Runtime files are the plugin root Lua files and piclogic/.
LUA ?= luajit

.PHONY: test

test:
	$(LUA) spec/run.lua spec/*_spec.lua

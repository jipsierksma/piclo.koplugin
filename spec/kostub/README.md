Minimal stand-ins for the KOReader modules the UI uses, so the real plugin
code can run headless under LuaJIT (see spec/ui_smoke_spec.lua). They mimic
the API shapes checked in the KOReader source, not its behaviour in full.
The blitbuffer is a real 8-bit pixel buffer so screens can be inspected.

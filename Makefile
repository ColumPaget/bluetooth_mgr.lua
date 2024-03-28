PREFIX=/usr/local

all:
	cat common.lua devices.lua settings.lua bluetoothctl.lua controller.lua controllers.lua bluealsa.lua  mainscreen.lua devicescreen.lua helpscreen.lua ui.lua main.lua > bluetooth_mgr.lua
	chmod a+x bluetooth_mgr.lua

install:
	cp -f bluetooth_mgr.lua $(PREFIX)/bin

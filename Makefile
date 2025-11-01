PREFIX=/usr/local

all:
	cat common.lua devices.lua settings.lua bluetoothctl.lua controller.lua controllers.lua bluealsa.lua device_names.lua main_screen.lua device_screen.lua device_name_screen.lua help_screen.lua ui.lua main.lua > bluetooth_mgr.lua
	chmod a+x bluetooth_mgr.lua

install:
	cp -f bluetooth_mgr.lua $(PREFIX)/bin

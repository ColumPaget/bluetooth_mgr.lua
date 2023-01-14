all:
	cat common.lua devices.lua settings.lua bluetoothctl.lua controller.lua controllers.lua mainscreen.lua devicescreen.lua ui.lua main.lua > bluetooth_mgr.lua
	chmod a+x bluetooth_mgr.lua

install:
	cp -f bluetooth_mgr.lua /usr/local/bin

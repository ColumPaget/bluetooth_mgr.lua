bluetooth_mgr.lua - terminal interface bluetooth manager
--------------------------------------------------------

bluetooth_mgr.lua is a terminal-menu based frontend to bluetoothctl. It can control scanning for devices, and pairing, trusting and connecting to devices.


Requirements
------------

bluetooth_mgr.lua requires lua, libUseful (https://github.com/ColumPaget/libUseful) version 4.13 and above, and libUseful-lua (https://github.com/ColumPaget/libUseful-lua) version 2.9 and above to have been installed. Building libUseful-lua requires SWIG.


Installation
------------

The program script 'bluetooth_mgr.lua' is the executable. It can be rebuilt with 'make' and installed in /usr/local/bin with 'make install'. It can be run with 'lua bluetooth_mgr.lua'.  On linux the 'binfmt_misc' feature can be used to automatically run bluetooth_mgr.lua without specifying the lua interpreter.


Usage
-----

The program is menu driven, with arrowkeys or wasd or ikjl being used to navigage menus.




-- must do this to ensure that we get standard english
-- messages back from all programs we talk to
process.setenv("LANG", "C")
process.setenv("LC_ALL", "C")


SettingsInit(arg)

Term=terminal.TERM(nil, "wheelmouse rawkeys save")
Term:clear()
Term:move(0,0)
ui=UI_Init(Term)

bt=BTInit()
controllers=ControllersInit()

poll=stream.POLL_IO()
poll:add(Term:get_stream())
poll:add(bt.S)

Term:puts("~R~wBluetooth_mgr 0.1   LOADING DEVICES~>~0\r")
controllers:poweron()


ui:start()
while true
do
	if bt.reload_devices==true then ui:loaddevs() end
  if process.sigcheck(process.SIGWINCH) == true then ui:resize() end
  process.sigwatch(process.SIGWINCH)


	S=poll:select(10)
	if S==bt.S
	then
		bt:handle_input()
 	elseif S==Term:get_stream() then
		key=Term:getc()
		if key=="S" then controllers:toggle_scan()
		elseif key=="b" 
		then 
			if config.show_beacons == true then config.show_beacons=false
			else config.show_beacons=true
			end
			ui:draw()
		elseif key=="Q" then break
		elseif key=="?" then ui:switchscreen("help")
		else
		str=ui:onkey(key) 
		if str == "exit" then break end
		end

  end

	ui:refresh()
end

bt:stopscan() 
Term:clear()
Term:reset()

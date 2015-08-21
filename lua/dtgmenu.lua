-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in DTGMENU.CFG. Open the file for descript of the details.
--
-- programmer: Jos van der Zande
-- version: 0.1.150821
-- =====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
-- these are the different formats of reply_markup. looksimple but needed a lot of testing before it worked :)
--
-- >show the custom keyboard and stay up after option selection first 3 on the first line and menu on the second
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]]}
-- >show the custom keyboard and minimises after option selection
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"one_time_keyboard":true}
-- >Remove the custom keyboard
--	reply_markup={"hide_keyboard":true}
--	reply_markup={"hide_keyboard":true,"selective":false}
-- >force normal keyboard to ask for input
--	reply_markup={"force_reply":true}
--	reply_markup={"force_reply":true,"selective":false}
-- >Resize the keyboard
--	reply_markup={"keyboard":[["menu"]],"resize_keyboard":true}
--  reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"resize_keyboard":true}


--------------------------------------
-- Include config
--------------------------------------
local config = assert(loadfile(BotHomePath.."lua/dtgmenu.cfg"))();
local http = require "socket.http";

-- definition used by DTGBOT
local dtgmenu_module = {};

-------------------------------------------------------------------------------
-- Start Functions to SORT the TABLE
-- Copied from internet location: -- http://lua-users.org/wiki/SortedIteration
-- These are used to sort the items on the menu alphabetically
-------------------------------------------------------------------------------
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function table.map_length(t)
    local c = 0
    for k,v in pairs(t) do
         c = c+1
    end
    return c
end

function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    key = nil
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        -- fetch the next value
        for i = 1,table.map_length(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    return orderedNext, t, nil
end
-------------------------------------------------------------------------------
-- END Functions to SORT the TABLE
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Start Function to set the new devicestatus.
-------------------------------------------------------------------------------
function SwitchName(DeviceName, DeviceType, SwitchType,idx,state)
  local status
  if idx == nil then
       response = 'Device '..DeviceName..'  not found.'
  else
    local subgroup = "light"
    if DeviceType == "scenes" then
      subgroup = "scene"
    end
    if string.lower(state) == "on" then
          state = "On";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
        elseif string.lower(state) == "off" then
          state = "Off";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
    elseif string.lower(string.sub(state,1,9)) == "set level" then
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd=Set%20Level&level="..string.sub(state,11)
        else
          return "state must be on, off or Set Level!";
        end
        print_to_log(1,"JSON request <"..t..">");
        jresponse, status = http.request(t)
        print_to_log(1,"JSON feedback: ", jresponse)
        response = dtgmenu_lang[language].text["Switched"] .. ' ' ..DeviceName..' => '..state
  end
  print_to_log(0,"   -< SwitchName:",DeviceName,idx, status,response)
  return response, status
end

-------------------------------------------------------------------------------
--- START Build the reply_markup functions.
--  this function will build the requested menu layout and calls the function to retrieve the devices/scenes  details.
-------------------------------------------------------------------------------
function makereplymenu(SendTo, Level, submenu, devicename)
  -- These are the possible menu level's ..
  -- mainmenu   -> will show all first level static and dynamic (rooms) options
  -- submenu    -> will show the second level menu for the select option on the main menu
  -- devicemenu -> will show the same menu as the previous but now add the possible action at the top of the menu
  --
  if submenu == nil then
    submenu = ""
  end
  if devicename == nil then
    devicename = ""
  end
  print_to_log(1,"Start makereplymenu:",SendTo, Level, submenu, devicename)

  ------------------------------------------------------------------------------
  -- First build the dtgmenu_submenus table with the required level information
  ------------------------------------------------------------------------------
  PopulateMenuTab(Level,submenu)

  ------------------------------------------------------------------------------
  -- start the build of the 3 levels of the keyboard menu
  ------------------------------------------------------------------------------
  print_to_log(1,"  -> makereplymenu  Level:",Level,"submenu",submenu,"devicename",devicename)
  local t=1
  local l1menu=""
  local l2menu=""
  local l3menu=""
--~   Sort & Loop through the compiled options returned by PopulateMenuTab
  for i,get in orderedPairs(dtgmenu_submenus) do
    -- ==== Build mainmenu - level 1 which is the bottom part of the menu, showing the Rooms and static definitins
    -- Avoid adding start and menu as these are handled separately.
    if i ~= "menu" and i ~= "start" then
      if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
        l1menu=l1menu .. i .. "|"
      end
    end
  end
-- ==== Build Submenu - showing the Devices from the selected room of static config
--                      This will also add the device status when showdevstatus=true for the option.
  print_to_log(1,'submenu: '..submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil
    and dtgmenu_submenus[submenu].buttons ~= nil then
      -- loop through all devined "buttons in the Config
      for i,get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
        print_to_log(1," Submenu item:",i,get.submenu)
        -- process all found devices in  dtgmenu_submenus buttons table
        if i ~= "" then
          local switchstatus = ""
          print_to_log(1,"   - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            -- add the device status to the button when requested
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              switchstatus = get.status
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
                switchstatus = tostring(switchstatus)
                switchstatus = switchstatus:gsub("Set Level: ", "")
                switchstatus = " - " .. switchstatus
--~ 							print_to_log(0,switchstatus)
              end
            end
            -- add to the total menu string for later processing
            l2menu=l2menu .. i .. switchstatus .. "|"
            -- show the actions menu immediately for this devices since that is requested in the config
            -- this can avoid having the press 2 button before getting to the actions menu
            if get.showactions then
              print_to_log(1,"  - Changing to Device action level due to showactions:",i)
              Level = "devicemenu"
              devicename = i
            end
          end
        end
				print_to_log(1,l2menu)
        -- ==== Build DeviceActionmenu
        -- do not build the actions menu when NoDevMenu == true. EG temp devices have no actions
        if dtgmenu_submenus[submenu].NoDevMenu ~= true
        and Level == "devicemenu" and i == devicename then
          -- set reply markup to the override when provide
          l3menu = get.actions
          SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
          print_to_log(1," ---< ",SwitchType," using replymarkup:",l3menu)
          -- else use the default reply menu for the SwitchType
          if l3menu == nil or l3menu == "" then
            l3menu = dtgmenu_lang[language].devices_options[SwitchType]
            if l3menu == nil then
              print_to_log(1,"  !!! No default dtgmenu_lang[language].devices_options for SwitchType:",SwitchType)
              l3menu = "Aan,Uit"
            end
          end
          print_to_log(1,"   -< " .. SwitchType .. " using replymarkup:",l3menu)
        end
      end
    end
  end
  -------------------------------------------------------------------
  -- Start building the proper layout for the 3 levels of menu items
  -------------------------------------------------------------------
  -- Always add "menu" as last option to level1 menu
  l1menu=l1menu .. "menu"
  ------------------------------
  -- start build total replymarkup
  local replymarkup = '{"keyboard":['
  ------------------------------
  -- Add level 3 first if needed
  ------------------------------
  if l3menu ~= "" then
    replymarkup = replymarkup .. buildmenu(l3menu,ActMenuwidth,"") .. ","
    l1menu = "menu"
  end
  ------------------------------
  -- Add level 2 next if needed
  ------------------------------
  if l2menu ~= "" then
    local mwitdh=DevMenuwidth
    if dtgmenu_submenus[submenu].Menuwidth ~= nil then
      if tonumber(dtgmenu_submenus[submenu].Menuwidth) >= 2 then
        mwitdh=tonumber(dtgmenu_submenus[submenu].Menuwidth)
      end
    end
    replymarkup = replymarkup .. buildmenu(l2menu,mwitdh,"") .. ","
    l1menu = "menu"
  end
  -------------------------------
  -- Add level 1 -- the main menu
  --------------------------------
  replymarkup = replymarkup .. buildmenu(l1menu,SubMenuwidth,"") .. ']'
  -- add the resize menu option when desired. this sizes the keyboard menu to the size required for the options
  if AlwaysResizeMenu then
    replymarkup = replymarkup .. ',"resize_keyboard":true'
  end
  -- Close the total statement
  replymarkup = replymarkup .. '}'

  -- save the full replymarkup and only send it again when it changed to minimize traffic to the TG client
  if LastCommand[SendTo]["replymarkup"] == replymarkup then
    print_to_log(0,"  -< replymarkup: No update needed")
    replymarkup=""
  else
    print_to_log(0,"  -< replymarkup:"..replymarkup)
    LastCommand[SendTo]["replymarkup"] = replymarkup
  end
-- save menus
  LastCommand[SendTo]["l1menu"] = l1menu  -- rooms or submenu items
  LastCommand[SendTo]["l2menu"] = l2menu  -- Devices scenes or commands
  LastCommand[SendTo]["l3menu"] = l3menu  -- actions
  return replymarkup, devicename
end
-- convert the provided menu options into a proper format for the replymenu
function buildmenu(menuitems,width,extrachar)
  local replymenu=""
  local t=0
	print_to_log(1," process buildmenu:",menuitems," w:",width)
  for dev in string.gmatch(menuitems, "[^|,]+") do
    if t == width then
      replymenu = replymenu .. '],'
      t = 0
    end
    if t == 0 then
      replymenu = replymenu .. '["' .. extrachar .. '' .. dev .. '"'
    else
      replymenu = replymenu .. ',"' .. extrachar .. '' .. dev .. '"'
    end
    t = t + 1
  end
  if replymenu ~= "" then
    replymenu = replymenu .. ']'
  end
  print_to_log(1,"    -< buildmenu:",replymenu)
  return replymenu
end
-----------------------------------------------
--- END Build the reply_markup functions.
-----------------------------------------------

-----------------------------------------------
--- START population the table which runs at each menu update -> makereplymenu
-----------------------------------------------
--
-- this function will rebuild the dtgmenu_submenus table each time it is called.
-- It will first read through the static menu items defined in DTGMENU.CRG in table static_dtgmenu_submenus
-- It will then call the MakeRoomMenus() function to add the dynamic options from Domoticz Room configuration
function PopulateMenuTab(iLevel,iSubmenu)
  print_to_log(1,"####  Start populating menuarray")

  dtgmenu_submenus = {}

  if iLevel ~= "mainmenu" then
    -- get IDX device table only one time
    Deviceslist = device_list("devices&used=true")
    -- get IDX scenes table only one time
    Sceneslist = device_list("scenes")
  end
  --
  print_to_log(1,"Submenu table including buttons defined in menu.cfg:",iLevel,iSubmenu)
  for submenu,get in pairs(static_dtgmenu_submenus) do
		print_to_log(1,"=>",submenu, get.whitelist, get.showdevstatus,get.Menuwidth)
    if static_dtgmenu_submenus[submenu].buttons ~= nil then
      buttons = {}
      if iLevel ~= "mainmenu" and iSubmenu == string.lower(submenu) then
        for button,dev in pairs(static_dtgmenu_submenus[submenu].buttons) do
            -- Get device/scene details
            idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(9999,button,Deviceslist,Sceneslist)
            -- fill the button table records with all required fields
            buttons[button]={}
            buttons[button].whitelist = dev.whitelist   -- specific for the static config: Whitelist number(s) for this device, blank is ALL
            buttons[button].actions=dev.actions         -- specific for the static config: Hardcoded Actions for the device
            buttons[button].prompt=dev.prompt           -- specific for the static config: Prompt TG cleint for the variable text
            buttons[button].showactions=dev.showactions -- specific for the static config: Show Device action menu right away when its menu is selected
            buttons[button].Name=DeviceName
            buttons[button].idx=idx
            buttons[button].DeviceType=DeviceType
            buttons[button].SwitchType=SwitchType
            buttons[button].Type=Type
            buttons[button].MaxDimLevel=MaxDimLevel     -- Level required to calculate the percentage for devices that do not use 100 for 100%
            buttons[button].status=status
            print_to_log(1," static ->",submenu,button,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
        end
      end
    -- Save the subment entry with optionally all its devices/sceens
      dtgmenu_submenus[submenu] = {whitelist=get.whitelist,buttons=buttons}
    end
  end
  -- Add the room/plan menu's after the statis is populated
  MakeRoomMenus(iLevel,iSubmenu,Deviceslist,Sceneslist)
  print_to_log(1,"####  End populating menuarray")
  return
end
--
-- Create a button per room.
function MakeRoomMenus(iLevel,iSubmenu,Deviceslist,Sceneslist)
  iSubmenu = tostring(iSubmenu)
  print_to_log(1,"Creating Room Menus:",iLevel,iSubmenu)
  room_number = 0
  -- get device table in case it's not provided through the parameter
  if Deviceslist == nil then
    Deviceslist = device_list("devices&used=true")
  end
  -- get scene table in case it's not provided through the parameterif Sceneslist == nil then
  if Sceneslist == nil then
    Sceneslist = device_list("scenes")
  end
  -- retrieve all available Rooms / plan's from Domoticz
  Roomlist = device_list("plans")
  planresult = Roomlist["result"]
  ------------------------------------
  -- process all found Room records
  ------------------------------------
  for p,precord in pairs(planresult) do
    room_name = precord.Name
    room_number = precord.idx
    local rbutton = string.lower(room_name:gsub(" ", "_"))
    --
    -- only get all details per Room in case we are not building the Mainmenu.
    -- Else
    if iLevel ~= "mainmenu"
    and iSubmenu == string.lower(rbutton) or "[scene] ".. iSubmenu == string.lower(rbutton) then
      -----------------------------------------------------------
      -- retrieve all devices/scenes for this plan from Domoticz
      -----------------------------------------------------------
      Devsinplan = device_list("command&param=getplandevices&idx="..room_number)
      DIPresult = Devsinplan["result"]
      if DIPresult ~= nil then
        print_to_log(1,'For room '..room_name..' got some devices and/or scenes')
        dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons={}}
        -----------------------------------------------------------
        -- process all found entries in the plan record
        -----------------------------------------------------------
        buttons = {}
        for d,DIPrecord in pairs(DIPresult) do
          if type(DIPrecord) == "table" then
            local DeviceType="devices"
            local SwitchType
            local Type
            local status=""
            local MaxDimLevel=100
            local idx=DIPrecord.devidx
            local name=DIPrecord.Name
            print_to_log(1," - Plan record:",DIPrecord.Name,DIPrecord.devidx,DIPrecord.type)
            if DIPrecord.type == 1 then
              print_to_log(1,"--> scene record")
              idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(idx,"",Deviceslist,Sceneslist)
            else
              print_to_log(1,"--> device record")
              idx,DeviceName, DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(idx,"",Deviceslist,Sceneslist)
            end
            -- Remove the name of the room from the device if it is present
            button = string.gsub(DeviceName,room_name.."%s+","")
            -- But reinstate it if lees than 3 letters are left
            if #button < 3 then
              button = DeviceName
            end
            -- Remove any spaces from the device name
            button = string.gsub(button,"%s+", "_")
            -- Get device/scene details
            idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(9999,DeviceName,Deviceslist,Sceneslist)
            -- fill the button table records with all required fields
            buttons[button]={}
            buttons[button].whitelist=""               -- Not implemented for Dynamic menu: Whitelist number(s) for this device, blank is ALL
            buttons[button].actions=""                 -- Not implemented for Dynamic menu: Hardcoded Actions for the device
            buttons[button].prompt=false               -- Not implemented for Dynamic menu: Prompt TG cleint for the variable text
            buttons[button].showactions=false          -- Not implemented for Dynamic menu: Show Device action menu right away when its menu is selected
            buttons[button].Name=DeviceName            -- Original devicename needed to be able to perform the "Set new status" commands
            buttons[button].idx=idx
            buttons[button].DeviceType=DeviceType
            buttons[button].SwitchType=SwitchType
            buttons[button].Type=Type
            buttons[button].MaxDimLevel=MaxDimLevel     -- Level required to calculate the percentage for devices that do not use 100 for 100%
            buttons[button].status=status
            print_to_log(1," Dynamic ->",rbutton,button,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
          end
        end
      end
    end
    -- Save the Room entry with optionally all its devices/sceens
    dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons=buttons}
  end
end
--
-- support function to scan through the provided Devices and Scenes tables to retrieve the required information for it.
function devinfo_from_name(idx,DeviceName,Devlist,Scenelist)
  local k, record, Type,DeviceType,SwitchType
  local found = 0
  local rDeviceName=""
  local status=""
  local MaxDimLevel=100
  local ridx=0
  -- Check for Devices
	print_to_log(2,"==> start devinfo_from_name", idx,DeviceName)
  result = Devlist["result"]
  for k,record in pairs(result) do
		print_to_log(2,k,DeviceName,record.Name,idx,record.idx)
    if type(record) == "table" then
      if string.lower(record.Name) == string.lower(DeviceName) or idx == record.idx then
        ridx = record.idx
        rDeviceName = record.Name
        DeviceType="devices"
        Type=record.Type
        if Type == "Temp" then
          SwitchType="temp"
          status = tostring(record.Temp)
        elseif Type == "Temp + Humidity" then
          SwitchType="temp"
          status = tostring(record.Temp) .. "-" .. tostring(record.Humidity).."%"
        else
          SwitchType=record.SwitchType
          MaxDimLevel=record.MaxDimLevel
          status = tostring(record.Status)
        end
        found = 1
        print_to_log(2," !!!! found device",record.Name,rDeviceName,record.idx,ridx)
        break
      end
    end
  end
  print_to_log(2," !!!! found device",rDeviceName,ridx)
  -- Check for Scenes
  if found == 0 then
    result = Scenelist["result"]
    for k,record in pairs(result) do
		print_to_log(2,k,record['Name'],DeviceName)
      if type(record) == "table" then
        if string.lower(record.Name) == string.lower(DeviceName) or idx == record.idx then
          ridx = record.idx
          rDeviceName = record.Name
          DeviceType="scenes"
          Type=record.Type
          SwitchType=record.Type
          found = 1
          print_to_log(2," !!!! found scene",record.Name,rDeviceName,record.idx,ridx)
          break
        end
      end
    end
  end
  -- Check for Scenes
  if found == 0 then
    ridx = 9999
    DeviceType="command"
    Type="command"
    SwitchType="command"
  end
 	print_to_log(2," --< devinfo_from_name:",found,ridx,rDeviceName,DeviceType,Type,SwitchType,status)
  return ridx,rDeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status
end
-----------------------------------------------
--- END population the table
-----------------------------------------------

-----------------------------------------------
--- Start Misc Function to support the process
-----------------------------------------------
-- SCAN through provided delimited string for the second parameter
function ChkInTable(itab,idev)
	print_to_log(2, " ChkInTable: ", itab)
  if itab ~= nil then
    for dev in string.gmatch(itab, "[^|,]+") do
      if dev == idev then
--~ 				print_to_log(0, "- ChkInTable found: ".. dev)
        return true
      end
    end
  end
	print_to_log(2, "- ChkInTable not found: "..idev)
  return false
end
--
-- Simple check function whether the input field is nil or empty ("")
function ChkEmpty(itxt)
  if itxt == nil or itxt == "" then
    return true
  end
  return false
end
-----------------------------------------------
--- END Misc Function to support the process
-----------------------------------------------

-----------------------------------------------
--- START the main process handler
-----------------------------------------------
function dtgmenu_module.handler(menu_cli,SendTo)
  -- initialise the user table in case it runs the firsttime
  if LastCommand[SendTo] == nil then
    LastCommand[SendTo] = {}
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["replymarkup"] = ""
    LastCommand[SendTo]["prompt"] = false
  end
  --~	split the commandline into parameters
  local dtgmenu_cli={}
  for w in string.gmatch(menu_cli[2], "([%w-_]+)") do
    table.insert(dtgmenu_cli, w)
  end
  --
  print_to_log(0,"==> menu.lua process:" ..  menu_cli[2])
  print_to_log(1," => SendTo:",SendTo)
  local commandline = menu_cli[2]
  local command = tostring(dtgmenu_cli[1])
  local lcommand = string.lower(command)
  local lcommandline = string.lower(commandline)
  local param1
  -- Retrieve the first parameter after the command in case provided.
  if menu_cli[3] ~= nil then
    param1  = menu_cli[3]              -- the command came in through the standard DTGBOT process
  else
    param1  = tostring(dtgmenu_cli[2]) -- the command came in via the DTGMENU exit routine
  end
  print_to_log(1," => commandline  :",commandline)
  print_to_log(1," => command      :",command)
  print_to_log(1," => param1       :",param1)
  print_to_log(1,' => Lastmenu submenu  :',LastCommand[SendTo]["l1menu"])
  print_to_log(1,' => Lastmenu devs/cmds:',LastCommand[SendTo]["l2menu"])
  print_to_log(1,' => Lastmenu actions  :',LastCommand[SendTo]["l3menu"])
  print_to_log(1,' => Lastcmd prompt :',LastCommand[SendTo]["prompt"])
  print_to_log(1,' => Lastcmd submenu:',LastCommand[SendTo]["submenu"])
  print_to_log(1,' => Lastcmd device :',LastCommand[SendTo]["device"])

  -------------------------------------------------
  -- set local variables
  -------------------------------------------------
  local lparam1 = string.lower(param1)
  local cmdisaction  = ChkInTable(LastCommand[SendTo]["l3menu"],commandline)
  local cmdisbutton  = ChkInTable(LastCommand[SendTo]["l2menu"],commandline)
  local cmdissubmenu = ChkInTable(LastCommand[SendTo]["l1menu"],commandline)
  print_to_log(1,' => cmdisaction :',cmdisaction)
  print_to_log(1,' => cmdisbutton :',cmdisbutton)
  print_to_log(1,' => cmdissubmenu:',cmdissubmenu)

  -------------------------------------------------
  -- Process "dtgmenu  (On/Off)" command
  -------------------------------------------------
  -- Set DTGMENU On/Off
  if lcommand == "dtgmenu" then
    Menuidx = idx_from_variable_name("TelegramBotMenu")
    if Menuidx == nil then
      Menuval = "Off"
    else
      Menuval = get_variable_value(Menuidx)
    end
    response="DTGMENU is currently "..Menuval
    if Menuval == "On" and lparam1 == "off" then
      print_to_log(0, " Set DTGMENU Off")
      response="DTGMENU is now disabled. send DTGMENU On to start the menus again."
      replymarkup='{"hide_keyboard":true}'
      set_variable_value(Menuidx,"TelegramBotMenu",2,"Off")
    elseif Menuval == "Off" and lparam1 == "on" then
      print_to_log(0, " Set DTGMENU On")
      response="DTGMENU is now enabled. send DTGMENU Off to stop the menus."
      response=dtgmenu_lang[language].text["main"]
      replymarkup = makereplymenu(SendTo, "mainmenu")
      if Menuidx == nil then
        create_variable("TelegramBotMenu",2,"On")
      else
        set_variable_value(Menuidx,"TelegramBotMenu",2,"On")
      end
    end
    status=1
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    print_to_log(0,"==< Show main menu")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- Process "start" or "menu" commands
  -------------------------------------------------
  -- Build main menu and return
  if cmdisaction == false and(lcommand == "menu" or lcommand == "start") then
    response=dtgmenu_lang[language].text["main"]
    replymarkup = makereplymenu(SendTo, "mainmenu")
    status=1
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    print_to_log(0,"==< Show main menu")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- process prompt input for "command" Type
  -------------------------------------------------
  -- When returning from a "prompt"action" then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
  if LastCommand[SendTo]["prompt"] then
    -- make small keyboard
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 0
    response = ""
    -- add previous command ot the current command
    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log(0,"==<1 promt and found regular lua command and param was given. -> hand back to dtgbot to run",commandline)
    return status, response, replymarkup, commandline
  end

  -----------------------------------------------------
  -- process when command is not known in the last menu
  -----------------------------------------------------
  -- hand back to DTGBOT reset keyboard to just MENU
  if cmdisaction == false
  and cmdisbutton == false
  and cmdissubmenu == false then
    -- make small keyboard
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 0 -- this triggers dtgbot to reset the parsed_command[2}=response and parsed_command[3}=command
    response = ""
    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log(0,"==<1 found regular lua command and param was given. -> hand back to dtgbot to run",commandline )
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- continue set local variables
  -------------------------------------------------
  local submenu    = ""
  local devicename = ""
  local action     = ""
  local status     = 0
  local response = ""
  local DeviceType = "devices"
  local SwitchType = ""
  local idx        = ""
  local Type       = ""
  local MaxDimLevel= 0
  if cmdissubmenu then
    submenu    = commandline
  end

  ----------------------------------------------------------------------
  -- Set needed variable when the command is a known device menu button
  ----------------------------------------------------------------------
  if cmdisbutton then
    submenu    = LastCommand[SendTo]["submenu"]
    devicename = command  -- use command as that should only contain the values of the first param
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    print_to_log(1,' => devicename :',devicename)
    print_to_log(1,' => realdevicename :',realdevicename)
    print_to_log(1,' => idx:',idx)
    print_to_log(1,' => Type :',Type)
    print_to_log(1,' => DeviceType :',DeviceType)
    print_to_log(1,' => SwitchType :',SwitchType)
    print_to_log(1,' => MaxDimLevel :',MaxDimLevel)
  end
  ----------------------------------------------------------------------
  -- Set needed variables when the command is a known action menu button
  ----------------------------------------------------------------------
  if cmdisaction then
    submenu    = LastCommand[SendTo]["submenu"]
    devicename = LastCommand[SendTo]["device"]
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    action     = lcommand  -- use lcommand as that should only contain the values of the first param
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    print_to_log(1,' => devicename :',devicename)
    print_to_log(1,' => realdevicename :',realdevicename)
    print_to_log(1,' => idx:',idx)
    print_to_log(1,' => Type :',Type)
    print_to_log(1,' => DeviceType :',DeviceType)
    print_to_log(1,' => SwitchType :',SwitchType)
    print_to_log(1,' => MaxDimLevel :',MaxDimLevel)
  end
  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- process Type="command" (none devices/scenes
  -------------------------------------------------
  if Type == "command" then
  --  when Button is pressed and Type "command" and no actions defined for the command then check for prompt and hand back without updating the keyboard
    if cmdisbutton
    and ChkEmpty(dtgmenu_submenus[submenu].buttons[command].actions) then
      -- prompt for parameter when requested in the config
      if dtgmenu_submenus[LastCommand[SendTo]["submenu"]].buttons[commandline].prompt then
        LastCommand[SendTo]["device"] = commandline
        LastCommand[SendTo]["prompt"] = true
        replymarkup='{"force_reply":true}'
        LastCommand[SendTo]["replymarkup"] = replymarkup
        status = 1
        response="param needed"
        print_to_log(0,"==<1 found regular lua command that need Param ")

      -- no prompt defined so simply return to dtgbot with status 0 so it will be performed and reset the keyboard to just MENU
      else
        replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
        status = 0
        LastCommand[SendTo]["submenu"] = ""
        LastCommand[SendTo]["device"] = ""
        LastCommand[SendTo]["l1menu"] = ""
        LastCommand[SendTo]["l2menu"] = ""
        LastCommand[SendTo]["l3menu"] = ""
        print_to_log(0,"==<1 found regular lua command. -> hand back to dtgbot to run")
      end
      return status, response, replymarkup, commandline
    end

    --  when Action is pressed and Type "command"  then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
    if devicename ~= ""
    and cmdisaction then
    --  if command is one of the actions of a command DeviceType hand it now back to DTGBOT
      replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
      response = ""
      -- add previous command ot the current command
      commandline = LastCommand[SendTo]["device"] .. " " .. commandline
      LastCommand[SendTo]["submenu"] = ""
      LastCommand[SendTo]["device"] = ""
      LastCommand[SendTo]["l1menu"] = ""
      LastCommand[SendTo]["l2menu"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      print_to_log(0,"==<2 found regular lua command. -> hand back to dtgbot to run:"..LastCommand[SendTo]["device"].. " " .. commandline )
      return status, response, replymarkup, commandline
    end
  end

  -------------------------------------------------
  -- process submenu button pressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    LastCommand[SendTo]["submenu"]=submenu
    print_to_log(1,' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      LastCommand[SendTo]["device"] = rdevicename
      print_to_log(1," -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=dtgmenu_lang[language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. dtgmenu_lang[language].text["Select"]
    end
    status=1
    print_to_log(0,"==< show options in submenu.")
    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------------
  -- process device button pressed on one of the submenus
  -------------------------------------------------------
  status=1
  if cmdisbutton then
    -- create reply menu and update table with device details
    replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename)
    -- Save the current device
    LastCommand[SendTo]["device"] = devicename
    local switchstatus=""
    local found=0
    if DeviceType == "scenes" then
      if Type == "Group" then
        response = dtgmenu_lang[language].text["SelectGroup"]
        print_to_log(0,"==< Show group options menu plus other devices in submenu.")
      else
        response = dtgmenu_lang[language].text["SelectScene"]
        print_to_log(0,"==< Show scene options menu plus other devices in submenu.")
      end
    elseif Type == "Temp" or Type == "Temp + Humidity" then
        -- when temp device is selected them just return with sending anything.
      LastCommand[SendTo]["device"] = ""
      response = ""
      status=1
      replymarkup=""
      print_to_log(1,"==< Don't do anything as a temp device was selected.")
    elseif DeviceType == "devices" then
      -- Only show current status in the text when not shown on the action options
      if dtgmenu_submenus[submenu].showdevstatus == "y" then
        response = dtgmenu_lang[language].text["SelectOptionwo"]
      else
        switchstatus = dtgmenu_submenus[submenu].button[devicename].status
        response = dtgmenu_lang[language].text["SelectOption"] .. " " .. switchstatus
      end
      print_to_log(0,"==< Show device options menu plus other devices in submenu.")
    else
      response = dtgmenu_lang[language].text["Select"]
      print_to_log(0,"==< Show options menu plus other devices in submenu.")
    end

    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  if ChkInTable(string.lower(dtgmenu_lang[language].switch_options["Off"]),action) then
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,'Off')
  elseif ChkInTable(string.lower(dtgmenu_lang[language].switch_options["On"]),action) then
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,'On')
  elseif string.find(action, "%d") then
    -- calculate the proper leve lto set the dimmer
    rellev = MaxDimLevel/100*tonumber(action)  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response = "Set level " .. action
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  else
    response = dtgmenu_lang[language].text["UnknownChoice"] .. action
  end
  status=1

  replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename)
  print_to_log(0,"==<"..response)
  return status, response, replymarkup, commandline;
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------

local dtgmenu_commands = {
  ["dtgmenu"] = {handler=dtgmenu_module.handler, description="DTGMENU (On/Off) to start or stop the menu functionality."},
  }

function dtgmenu_module.get_commands()
  return dtgmenu_commands;
end

return dtgmenu_module;
-- =====================================================================================================================
-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in easykeys.cfg Open the file for descript of the details.
--
-- programmer: Simon Gibbon
-- based on initial work of Jos van der Zande
-- version: 0.1.150824
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
--local config = assert(loadfile(BotHomePath.."lua/dtgmenu.cfg"))();
local http = require "socket.http";

-- definition used by DTGBOT
local easykeys_module = {};
local menu_language = language

-- Create the replymarkup from a keyboard array
function create_replymarkup(keyboard)
  print_to_log(1," Creating replymarkup",#keyboard)
  local draftmarkup = ''
  local thislevel = keyboard[1].level
  local width = 3
  local position = 0
  for i = 1, #keyboard do
    print_to_log(0,'i',i)
    currentlevel = keyboard[i].level
    -- Finish a line when width is full or changing level
    if position == width or thislevel ~= currentlevel then
      draftmarkup = draftmarkup .. '],'
      position = 0
      thislevel = currentlevel
    end
    -- Start a new line when in first place
    if position == 0 then
      draftmarkup = draftmarkup .. '["' .. buttons[keyboard[i].idx][2] .. '"'
    else
      draftmarkup = draftmarkup .. ',"' .. buttons[keyboard[i].idx][2] .. '"'
    end
    position = position + 1
  end
  if draftmarkup ~= "" then
    draftmarkup = '{"keyboard":['..draftmarkup..']],"resize_keyboard":true}'
  end
  print_to_log(1,"    -< Created replymarkup",draftmarkup)
  return draftmarkup
end

function create_roombuttons()
    local room_number = 0
    local room_buttonlist = {}
  if Roomlist ~= nil then
    print_to_log(0,"Creating Room Buttons")
    ------------------------------------
    -- process all Rooms
    ------------------------------------
    for rnumber, rname in pairs(iRoomlist) do
      room_name = rname
      room_number = rnumber
      rbutton = rname
      -----------------------------------------------------------
      -- retrieve all devices/scenes for this plan from Domoticz
      -----------------------------------------------------------
      print(room_number)
      Devsinplan = device_list("command&param=getplandevices&idx="..room_number)
      DIPresult = Devsinplan["result"]
      if DIPresult ~= nil then
        print_to_log(0,'For room '..room_name..' got some devices and/or scenes')
        -----------------------------------------------------------
        -- process all found entries in the plan record
        -----------------------------------------------------------
--        room_markup = ''
        room_buttons = {}
        for d,DIPrecord in pairs(DIPresult) do
          if type(DIPrecord) == "table" then
            local idx=DIPrecord.devidx
            local name=DIPrecord.Name
            print_to_log(0," - Plan record:",DIPrecord.Name,DIPrecord.devidx,DIPrecord.type)
            if DIPrecord.type == 1 then
              print_to_log(1,"--> scene record")
              currentidx = soffset + idx
              name = '*'..iScenelist[idx]
            else
              print_to_log(1,"--> device record")
              currentidx = doffset + idx
              name = iDevicelist[idx]
            end
            print(iDevicelist[idx])
            print(idx)
            print(name)
            -- Remove the name of the room from the device if it is present and any susequent Space or Hyphen or undersciore
            print("Name bits", name, room_name)
            newname = string.gsub(name,room_name.."[%s-_]*","")
            -- But reinstate it if less than 2 letters are left
            if #newname < 2 then
              newname = name
            end
            buttons[currentidx] = {idx, newname}
            table.insert(room_buttons,currentidx)
          end
        end
      end
      -- Save the Room entry with all its devices/sceens
      buttons[roffset + rnumber] = {rnumber, rname, room_buttons}
      table.insert(room_buttonlist, roffset + rnumber) 
    end
    return room_buttonlist
  else
    print_to_log(0,'No Rooms defined in Domoticz')
  end
end

function easykeys_module.handler(parsed_cli,SendTo)
  roffset = 0
  soffset = 100
  doffset = 500
  moffset = 5000
  aoffset = 5500
  buttons = {}
  current_keyboard = {}
  command = parsed_cli[2]
  awaiting_input = false
  response = ""
  -- menu control
  if string.lower(command) == 'easykeys' then
    if parsed_cli[3] == 'on' then
      -- Set up the preprocess function which will intercept commands in dtgbot
      preprocess = preprocess_keys
      room_buttonlist = create_roombuttons()
      print_to_log(0,'here')
      current_keyboard = buildmenukeys(room_buttonlist,1)
      -- Create the home key button
      buttons[moffset] = {moffset,"Home",room_buttonlist}
      -- Create the home key keyboard item
      home_key = {idx = moffset, type = 'menu', level = 0}
      -- Add home key
      current_keyboard[1+#current_keyboard] = home_key
      replymarkup = create_replymarkup(current_keyboard)
    else
      if parsed_cli[3] == 'off' then
        -- Turn of the preprocess function
        preprocess = nil
        -- remove custom keyboard
        replymarkup = ''
      end
    end
    return status, response, replymarkup, commandline
  end
  return status, response, replymarkup, commandline;
end

-- Build a device / scene menu based on button idx only
function builddevicekeys(bidx, levelkeys)
  local old_keyboard = current_keyboard
  local new_keyboard = {}
  local idx = buttons[bidx][1]
  local devicename, SwitchType
  local currentlevel = levelkeys
  print_to_log(0,'idevice direct',iDevicelist[idx])
  -- This is a device
  if bidx > doffset then
    print_to_log(0,'setting deivce properties',idx)
    devicename = iDevicelist[tostring(idx)]
    SwitchType = Deviceproperties[tostring(idx)].SwitchType
    -- So this must be a scene
  else
    print_to_log(0,'setting scene properties',idx)
    devicename = iScenelist[idx]
    SwitchType = Sceneproperties[idx].SwitchType
  end
  print_to_log(0,'iDevicelist',bidx,idx,devicename,SwitchType)
  local actiontext = dtgmenu_lang['en'].devices_options[SwitchType]
  i = 0
  for keytext in string.gmatch(actiontext, "[^,]+") do
    i = i + 1
    local currentidx = aoffset + i
    currenttype = 'action'
      currentlevel = levelkeys
    if keytext == '?' then
      buttons[currentidx] = {idx, keytext, 'Set Level ??? '..devicename}
      currenttype = 'input'
      currentlevel = currentlevel + 1
    elseif keytext =="On" then
      buttons[currentidx] = {i, keytext, 'On '..devicename}
    elseif keytext == 'Off' then
      buttons[currentidx] = {i, keytext, 'Off '..devicename}
    elseif keytext == 'Activate' then
      print_to_log(0,'Activate',currentidx,i,keytext,devicename)
      buttons[currentidx] = {i, keytext, 'On '..devicename}
    elseif string.match(keytext,"%d+.*%d*") then
      buttons[currentidx] = {i, keytext, 'set level '..string.match(keytext,"%d+.*%d*")..' '..devicename}
      currentlevel = currentlevel + 1
    end
    new_keyboard[i] = {idx = currentidx, type = currenttype, level = currentlevel}
    print_to_log(0,i,keytext,currentidx)
  end
  -- Append the old keyboard so we can get back
  -- but only the non-action items
  for j = 1, #old_keyboard do
    print_to_log(0,'j,i',j,i,old_keyboard[j].idx)
    if old_keyboard[j].idx < aoffset and old_keyboard[j].level ~= 0 then
      i = i+1
      new_keyboard[i] = old_keyboard[j]
    end
  end
  return new_keyboard
end

function keyboard_compare(item1, item2)
  return buttons[item1.idx][2] < buttons[item2.idx][2]
end

function keyboard_sort(keyboard)
  table.sort(keyboard, keyboard_compare)
  return keyboard
end

function buildmenukeys(buttonlist,levelkeys)
  local old_keyboard = current_keyboard
  local new_keyboard = {}
  for i = 1, #buttonlist do
    local bidx = buttonlist[i]
    print_to_log(0,'button bit',bidx)
    local idx = buttons[bidx][1]
    -- An action
    if bidx > moffset then
      new_keyboard[i] = {idx = bidx, type = 'action', level = levelkeys}
      -- A device
    elseif bidx > doffset then
      new_keyboard[i] = {idx = bidx, type = 'device', level = levelkeys}
      -- A scene
    elseif bidx > soffset then
      new_keyboard[i] = {idx = bidx, type = 'scene', level = levelkeys}
      -- A Room
    else
      new_keyboard[i] = {idx = i, type = 'menu', level = levelkeys}  --???????????
    end
  end
  new_keyboard = keyboard_sort(new_keyboard)
  return new_keyboard
end

function preprocess_keys(cmd, SendTo, Group, MessageId)
-- Only process if cmd has come from the keyboard mark-up
-- So compare it to all the existing keys
  local status = 0
  print('preprocess keys')
  print(cmd)
  local returned_keyboard = current_keyboard
  print_to_log(0,'keys returned',#returned_keyboard)
  for ij =1,#returned_keyboard do
    local record = returned_keyboard[ij]
    -- Found key text
    if buttons[record.idx][2] == cmd then
      awaiting_input = false
      print('Keyboard exactly matched by return')
      -- Command found
      if record.type == "command" then
        -- Pass the command to dtgbot having up dated the replymarkup
        return status, record.command, replymarkup
      end
      if record.type == "menu" then
        new_keyboard = buildmenukeys(buttons[record.idx][3])
        current_keyboard = new_keyboard
        -- Add home key
      current_keyboard[1+#current_keyboard] = home_key
      replymarkup = create_replymarkup(current_keyboard)
        send_msg(SendTo,'Its a menu',MessageId,replymarkup)
        -- Return 1 so dtgbot does nothing more
        return 1, "", record.replymarkup
      end
      if record.type == "device" or record.type == "scene" then
        -- Create the options and return 1 so dtgbot does nothing more
        new_keyboard = builddevicekeys(record.idx,3)
        current_keyboard = new_keyboard
      -- Add home key
      current_keyboard[1+#current_keyboard] = home_key
      replymarkup = create_replymarkup(current_keyboard)
        send_msg(SendTo,'Its a device',MessageId,replymarkup)
        return 1, "", replymarkup
      end
      if record.type == "action" then
        print_to_log(0,'action', buttons[record.idx][3])
        return 0, buttons[record.idx][3], replymarkup
      end
      if record.type == "input" then
        print_to_log(0,'input', buttons[record.idx][3])
--        nomarkup='{"keyboard":[["1","2","3","4","5","6","7","8","9","0"],["Home"]],"resize_keyboard":true}'
        nomarkup='{"force_reply":true}'
        send_msg(SendTo,'Type value',MessageId,nomarkup)
        awaiting_input = true
        input_command = buttons[record.idx][3]
        return 1, buttons[record.idx][3], replymarkup
      end
    end
  end
  print('here 0')
  if awaiting_input then
    print('here 1')
    if string.match(cmd,"%d+.%d*") then
      print('here 2')
      cmd = string.gsub(input_command,"%?%?%?",cmd)
      awaiting_input = false
    end
  end
  -- Not a keyboard command or input so pass straight back to dtgbot
  return status, cmd, replymarkup
end

local easykeys_commands = {
  ["easykeys"] = {handler=easykeys_module.handler, description="easykeys (will toggle On/Off) to start/stop the menu functionality."},
}

function easykeys_module.get_commands()
  return easykeys_commands;
end

return easykeys_module;

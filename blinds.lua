-- Check the wiki for dzVents
-- remove what you don't need
return {

    -- optional active section,
    -- when left out the script is active
    -- note that you still have to check this script
    -- as active in the side panel
    active = {

        true,  -- either true or false, or you can specify a function

        --function(domoticz)
            -- return true/false
        --end
    },
    -- trigger
    -- can be a combination:
    on = {

        -- timer riggers
        timer = {
            -- timer triggers.. if one matches with the current time then the script is executed
            '10 minutes before sunrise',
            '0 minutes after sunrise',
            '10 minutes after sunrise',
            '60 minutes after sunrise',
            '90 minutes after sunrise',
            '0 minutes after sunset',
            '10 minutes after sunset',
            '30 minutes after sunset',
            'every minute',
        }
    },

    -- persistent data
    -- see documentation about persistent variables
    data = {
        myTimers = { initial = {
            ['10 minutes before sunrise'] = 0,
            ['0 minutes after sunrise'] = 0,
            ['10 minutes after sunrise'] = 0,
            ['60 minutes after sunrise'] = 0,
            ['90 minutes after sunrise'] = 0,
            ['0 minutes after sunset'] = 0,
            ['10 minutes after sunset'] = 0,
            ['30 minutes after sunset'] = 0,
            ['every minute'] = 0,
            }}
    },

    -- custom logging level for this script
    logging = {
        level = domoticz.LOG_INFO,
        marker = "CtrlVolets"
    },

    -- actual event code
    -- the second parameter is depending on the trigger
    -- when it is a device change, the second parameter is the device object
    -- similar for variables, scenes and groups and httpResponses
    -- inspect the type like: triggeredItem.isDevice
    execute = function(domoticz, timer, info)
        --[[

        The domoticz object holds all information about your Domoticz system. E.g.:

        local myDevice = domoticz.devices('myDevice')
        local myVariable = domoticz.variables('myUserVariable')
        local myGroup = domoticz.groups('myGroup')
        local myScene = domoticz.scenes('myScene')

        The device object is the device that was triggered due to the device in the 'on' section above.
        ]] --
        
        --------------------------------
        ------ Variables à éditer ------
        --------------------------------

        volets = {
            ['Salon fenetre'] =
                { ['open'] = {'10 minutes after sunrise'},
                  ['stopped'] = {'10 minutes before sunrise'},
                  ['close']= {'30 minutes after sunset'},
                  ['door']= false,
                  ['bedroom']= false
                 },
            ['Salon portefenetre'] =
                { ['open'] = {'10 minutes after sunrise'},
                  ['stopped'] = {'10 minutes before sunrise'},
                  ['close']= {'30 minutes after sunset'},
                  ['door']= true,
                  ['bedroom']= false
                 },
            ['Chambre fenetre'] =
                { ['open'] = {'90 minutes after sunrise'},
                  ['stopped'] = {'60 minutes after sunrise'},
                  ['close']= {'10 minutes after sunset'},
                  ['door']= false,
                  ['bedroom']= true
                 },
            ['Chambre portefenetre'] =
                { ['open'] = {'90 minutes after sunrise'},
                  ['stopped'] = {'60 minutes after sunrise'},
                  ['close']= {'10 minutes after sunset'},
                  ['door']= true,
                  ['bedroom']= true
                 },
          }

        --------------------------------
        ---- Fin variables à éditer ----
        --------------------------------
        
        --------------------------------
        ------- Helper functions -------
        --------------------------------        

        function string:split(sep)
            local sep, fields = sep or ":", {}
            local pattern = string.format("([^%s]+)", sep)
            self:gsub(pattern, function(c) fields[#fields+1] = c end)
            return fields
        end

        function volet_change(dev, newstate)
            oldstate = dev.state
            if oldstate == newstate then
                return
            end
            if newstate == 'Closed' then
                dev.switchOn()
                return
            end
            if newstate == 'Open' then
                dev.switchOff()
                return
            endeturn
            end
            if newstate == 'Stopped' then
                dev.stop()
                return
            end
        end

        function volets_status(vols) 
            for name, triggers in pairs(vols) do
                device = domoticz.devices(name)
                domoticz.log(string.format('==> %s: %s', name, device.state))
            end
        end

        function volets_dump_triggers(vols)
            for name, triggers in pairs(vols) do
                domoticz.log(name)
                for i=1, #triggers.stopped do
                    domoticz.log(string.format('__stopped : %s', triggers.stopped[i]))
                end
                for i=1, #triggers.open do
                    domoticz.log(string.format('__open... : %s', triggers.open[i]))
                end
                for i=1, #triggers.close do
                    domoticz.log(string.format('__close.. : %s', triggers.close[i]))
                end
            end
        end

        function volets_close(vols)
            for name, triggers in pairs(vols) do
                device = domoticz.devices(name)
                volet_change(device, 'Closed')
            end
        end

        function volets_open(vols)
            for name, triggers in pairs(vols) do
                device = domoticz.devices(name)
                volet_change(device, 'Open')
            end
        end

        function volets_stopped(vols)
            for name, triggers in pairs(vols) do
                device = domoticz.devices(name)
                volet_change(device, 'Stopped')
            end
        end

        ----------safeClose-------------

        function safeClose(dev)
            oldstate = dev.state
            if oldstate == 'Closed' then
                return
            end
            dev.switchOn()
            dev.stop().afterSec(5)
            dev.switchOn().afterSec(40)
        end

        -----------safeOpen-------------

        function safeOpen(dev)
            oldstate = dev.state
            if oldstate == 'Open' then
                return
            end
            local Time = require('Time')
            local now = Time() -- current time
            if now.hour < 9 then
                dev.switchOff().at('09:00')
                return
            end
            dev.switchOff()
        end

        --------------------------------
        ----- Fin helper functions -----
        --------------------------------     


        --------------------------------
        ------- Initialisations --------
        --------------------------------

        local Time = require('Time')
        local now = Time() -- current time
        now_mn = now.hour * 60 + now.minutes

        --------------------------------
        ----- Fin initialisations ------
        --------------------------------
   

        for name, triggers in pairs(volets) do
            -- Process open
            for i=1, #triggers.open do
                if triggers.open[i] == timer.trigger then
                    domoticz.data.myTimers[timer.trigger] = now_mn
                    domoticz.log(string.format('--> %s: %s', name, timer.trigger))
                    device = domoticz.devices(name)
                    if triggers.bedroom then
                        safeOpen(device)
                    else
                        device.switchOff()
                    end
                end
            end
            -- Process stopped
            for i=1, #triggers.stopped do
                if triggers.stopped[i] == timer.trigger then -- stopped
                    domoticz.data.myTimers[timer.trigger] = now_mn
                    domoticz.log(string.format('--> %s: %s', name, timer.trigger))
                    device = domoticz.devices(name)
                    device.stop()()
                end
            end
            -- Process close
            for i=1, #triggers.close do
                if triggers.close[i] == timer.trigger then -- closed
                    domoticz.data.myTimers[timer.trigger] = now_mn
                    domoticz.log(string.format('--> %s: %s', name, timer.trigger))
                    device = domoticz.devices(name)
                    if triggers.door then
                        safeClose(device)
                    else
                        device.switchOn()
                    end
                end
            end
        end


        for k, v in pairs (domoticz.data.myTimers) do
            domoticz.log(string.format('%s: %s', k, now_mn - v), domoticz.LOG_DEBUG)
        end

    end
}

clutchOutput = 0
fuelManifold = 0.5
airOutput = 0.5

--Settings

--Adjusts fuel to avoid going over redline
engineFuelTune = 0.1



function onTick()
    -- Read inputs
    ignition = input.getBool(1)
    steering = input.getNumber(1)
    throttle = input.getNumber(2)
    leftRight = input.getNumber(3)
    upDown = input.getNumber(4)
    airVol = input.getNumber(5)
    fuelVol = input.getNumber(6)
    engineTemp = input.getNumber(7)
    engineRps = input.getNumber(8)
    maxRps = input.getNumber(9)
    idleRps = input.getNumber(10)
    battery = input.getNumber(11)
	targetAFR = input.getNumber(12)
	
    -- Control engine
    if ignition == true and engineTemp < 114 then
		airControl()
        fuelControl()
        starters()
		hybridMotors()
    else
        fuelManifold = 0.05
        output.setBool(1, false)
        output.setNumber(1, 0)
        output.setNumber(2, 0)
    end
end

function sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

function clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

function airControl()
    local targetTemp = 110
    local tempError = targetTemp - engineTemp
    local outputGain = 0.005
    airOutput = clamp(airOutput + tempError * outputGain, 0, 1)
    output.setNumber(1, airOutput)
end




 
function fuelControl()
    -- avoid divide by 0 for AFR
    if fuelVol <= 0 then
        fuelVol = .0005
        output.setNumber(2, 0.5)
    end

    -- Calculate target AFR based on engine temperature
    local maxTemperature = 114
    local targetAfr = 14.5 - (engineTemp - maxTemperature) * 0.001

    -- Calculate AFR and adjust fuel flow based on AFR error
    local afr = airVol / fuelVol
    local error = targetAfr - afr
    local deltaFuel = -error * 0.005
	
	
    -- Gradually increase fuel when throttle is pressed
    if throttle > 0 and engineRps < maxRps then
        local throttleFuel = (throttle - 0.5) * .01
        deltaFuel = deltaFuel + throttleFuel * (maxRps - engineRps) / maxRps
    end

    -- Gradually decrease fuel to idle when throttle is released
    if throttle <= 0 and engineRps > idleRps then
        local rpsDiff = engineRps - idleRps
        deltaFuel = deltaFuel - rpsDiff * 0.05
    end

    -- Update fuel manifold
    if fuelManifold + deltaFuel > 1.0 then
        deltaFuel = 1.0 - fuelManifold
    end

    local minFuel = 0.07
    if fuelManifold + deltaFuel < minFuel then
        deltaFuel = minFuel - fuelManifold
    end

    fuelManifold = fuelManifold + deltaFuel

    -- Prevent engine from accelerating past redline when there is no throttle input
    if engineRps > maxRps then
        local maxIdleFuelManifold = idleRps / maxRps -- calculate max fuel manifold for idle speed
        fuelManifold = clamp(fuelManifold, 0, maxIdleFuelManifold)
    end

    output.setNumber(2, fuelManifold)
end



function hybridMotors()
    if engineRps < idleRps then
        -- Set the output value to 1 to start the motor or maintain idle speed
        output.setNumber(4, 1)
    elseif throttle > 0.1 then
        -- Calculate the proximity of engineRps to maxRps as a fraction of the maximum RPM
        local proximity = math.abs(engineRps - maxRps) / maxRps

        -- Invert the proximity value so that it goes from 1 to 0 as engineRps gets closer to maxRps
        local value = 1 - proximity

        -- If engineRps is above idleRps and throttle is less than or equal to 0.1, set the output value to 0
        if engineRps >= idleRps and throttle <= 0.1 then
            value = 0
        end

        -- Set the value as output number 4 to interact with the motor
        output.setNumber(4, value)
	else
		output.setNumber(4, 0)
    end
end




function starters()
    output.setBool(1, engineRps < 2.6)
end

safe = {

    call = function(object, key)
        
        if (type(object[key]) == "function") then
            
            object[key]();
            
        end
    
    end

}

return safe;
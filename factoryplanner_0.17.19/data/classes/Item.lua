-- 'Class' representing an item in the general sense
Item = {}

-- Initialised by passing a prototype from the all_items global table
function Item.init_by_proto(proto, class, amount)
    local type = global.all_items.types[global.all_items.map[proto.type]]
    return {
        proto = proto,
        type = type,
        amount = amount or 0,  -- produced amount
        required_amount = 0,
        sprite = (proto.type .. "/" .. proto.name),
        valid = true,
        class = class
    }
end

-- Initialised by passing a basic item table {name, type, amount}
function Item.init_by_item(item, class, amount)
    local items = global.all_items
    local type = items.types[items.map[item.type]]
    local item = type.items[type.map[item.name]]
    return Item.init_by_proto(item, class, amount)
end


-- Update the validity of this item
function Item.update_validity(self)
    local new_type_id = new.all_items.map[self.type.name]
    if new_type_id ~= nil then
        self.type = new.all_items.types[new_type_id]

        new_item_id = self.type.map[self.proto.name]
        if new_item_id ~= nil then
            self.proto = self.type.items[new_item_id]
            self.valid = true
        else
            self.proto = self.proto.name
            self.valid = false
        end
    else
        self.type = self.type.name
        self.proto = self.proto.name
        self.valid = false
    end
    
    return self.valid
end

-- Tries to repair this item, deletes it otherwise (by returning false)
-- If this is called, the item is invalid and has a string saved to proto (and maybe to type)
function Item.attempt_repair(self, player)
    -- First, try and repair the type if necessary
    if type(self.type) == "string" then
        local current_type_id = global.all_items.map[self.type]
        if current_type_id ~= nil then
            self.type = global.all_items.types[current_type_id]
        else  -- delete immediately if no matching type can be found
            return false
        end
    end
    
    -- At this point, type is always valid (and proto is always a string)
    local current_item_id = self.type.map[self.proto]
    if current_item_id ~= nil then
        self.proto = self.type.items[current_item_id]
        self.sprite =  (self.proto.name .. "/" .. self.proto.name)
        self.valid = true
    else
        self.valid = false
    end

    return self.valid
end
-- Contains the UI and event handling for machine/beacon modules
module_configurator = {}

-- ** LOCAL UTIL**
local function determine_slider_config(module, empty_slots)
    local slider_value = (module) and module.amount or empty_slots
    local maximum_value = (module) and (module.amount + empty_slots) or empty_slots
    local minimum_value = (maximum_value == 1) and 0 or 1 -- to make sure that the slider can be created
    return slider_value, maximum_value, minimum_value
end

local function add_module_frame(parent_flow,  module, module_filters, empty_slots)
    local module_id = module and module.id or nil

    local frame_module = parent_flow.add{type="frame", style="fp_frame_module", direction="horizontal",
      tags={module_id=module_id}}
    frame_module.add{type="label", caption={"fp.pu_module", 1}}

    local module_name = (module) and module.proto.name or nil
    local button_module = frame_module.add{type="choose-elem-button", name="fp_chooser_module", elem_type="item",
      item=module_name, tags={mod="fp", on_gui_elem_changed="select_module", module_id=module_id},
      elem_filters=module_filters, style="fp_sprite-button_inset_tiny"}
    button_module.style.right_margin = 12

    frame_module.add{type="label", caption={"fp.amount"}}

    local slider_value, maximum_value, minimum_value = determine_slider_config(module, empty_slots)
    local slider_style = (maximum_value == 1) and "fp_slider_module_none" or "fp_slider_module"
    local slider = frame_module.add{type="slider", name="fp_slider_module_amount", style=slider_style,
      tags={mod="fp", on_gui_value_changed="module_amount", module_id=module_id},
      minimum_value=minimum_value, maximum_value=maximum_value, value=slider_value, value_step=0.1}
    -- Fix for the slider value step "not bug" (see https://forums.factorio.com/viewtopic.php?p=516440#p516440)
    -- Fixed by setting step to something other than 1 first, then setting it to 1
    slider.set_slider_value_step(1)
    slider.enabled = (maximum_value ~= 1)  -- needs to be set here because sliders are buggy as fuck

    local textfield = frame_module.add{type="textfield", name="fp_textfield_module_amount", enabled=(maximum_value ~= 1),
      text=tostring(slider_value), tags={mod="fp", on_gui_text_changed="module_amount", module_id=module_id}}
    ui_util.setup_numeric_textfield(textfield, false, false)
    textfield.style.width = 40
end


local function handle_module_selection(player, tags, event)
    local modal_data = data_util.get("modal_data", player)
    local module_set = modal_data.module_set
    local new_name = event.element.elem_value

    if tags.module_id then  -- editing an existing module
        local module = ModuleSet.get(module_set, tags.module_id)
        if new_name then  -- changed to another module
            module.proto = MODULE_NAME_MAP[new_name]
            Module.summarize_effects(module)
        else  -- removed module
            ModuleSet.remove(module_set, module)
        end
    elseif new_name then -- choosing a new module on an empty line
        local slider = event.element.parent["fp_slider_module_amount"]
        ModuleSet.add(module_set, MODULE_NAME_MAP[new_name], slider.slider_value)
    end

    module_configurator.refresh_modules_flow(player, false)
    -- Sorting and effects refresh is done when the dialog is submitted
end

local function handle_module_slider_change(player, tags, event)
    local modal_data = data_util.get("modal_data", player)
    local module_set = modal_data.module_set
    local new_slider_value = event.element.slider_value
    local module_textfield = event.element.parent["fp_textfield_module_amount"]

    if tags.module_id then  -- editing an existing module
        local module = ModuleSet.get(module_set, tags.module_id)
        Module.set_amount(module, new_slider_value)
        module_configurator.refresh_modules_flow(player, true)
    else  -- empty line, no influence on anything else
        module_textfield.text = tostring(new_slider_value)
    end

    -- Sorting and effects refresh is done when the dialog is submitted
end

local function handle_module_textfield_change(player, tags, event)
    local modal_data = data_util.get("modal_data", player)
    local module_set = modal_data.module_set
    local new_textfield_value = tonumber(event.element.text)
    local module_slider = event.element.parent["fp_slider_module_amount"]

    local slider_maximum = module_slider.get_slider_maximum()
    local normalized_amount = math.max(1, (new_textfield_value or 1))
    local new_amount = math.min(normalized_amount, slider_maximum)

    if tags.module_id then  -- editing an existing module
        local module = ModuleSet.get(module_set, tags.module_id)
        Module.set_amount(module, new_amount)
        module_configurator.refresh_modules_flow(player, true)
    else  -- empty line, no influence on anything else
        module_slider.slider_value = new_amount
        event.element.text = tostring(new_amount)
    end

    -- Sorting and effects refresh is done when the dialog is submitted
end


-- ** TOP LEVEL **
function module_configurator.add_modules_flow(content_frame, modal_data)
    local flow_modules = content_frame.add{type="flow", direction="vertical"}
    modal_data.modal_elements["modules_flow"] = flow_modules
end

function module_configurator.refresh_modules_flow(player, update_only)
    local modal_data = data_util.get("modal_data", player)
    local modules_flow = modal_data.modal_elements.modules_flow

    local module_filters = ModuleSet.compile_filter(modal_data.module_set)
    local empty_slots = modal_data.module_set.empty_slots

    if update_only then
        -- Update the UI instead of rebuilding it so the slider can be dragged properly
        for _, frame in pairs(modules_flow.children) do
            local module_id = frame.tags.module_id
            if module_id == nil then
                frame.destroy()  -- destroy empty frame as it'll be re-added below
            else
                local module = ModuleSet.get(modal_data.module_set, module_id)
                if module == nil then
                    frame.destroy()
                else
                    local slider_value, maximum_value, minimum_value = determine_slider_config(module, empty_slots)

                    frame["fp_chooser_module"].elem_value = module.proto.name

                    local textfield = frame["fp_textfield_module_amount"]
                    textfield.text = tostring(module.amount)
                    textfield.enabled = (maximum_value ~= 1)

                    local slider = frame["fp_slider_module_amount"]
                    slider.set_slider_value_step(0.1)  -- bug workaround
                    slider.set_slider_minimum_maximum(minimum_value, maximum_value)
                    slider.slider_value = slider_value
                    slider.set_slider_value_step(1)  -- bug workaround
                    slider.enabled = (maximum_value ~= 1)
                    slider.style = (maximum_value == 1) and "fp_slider_module_none" or "fp_slider_module"
                end
            end
        end
    else
        modules_flow.clear()
        for _, module in pairs(ModuleSet.get_in_order(modal_data.module_set)) do
            add_module_frame(modules_flow, module, module_filters, empty_slots)
        end
    end

    if empty_slots > 0 then add_module_frame(modules_flow, nil, module_filters, empty_slots) end
    if modal_data.submit_checker then modal_data.submit_checker(modal_data) end
end


-- ** EVENTS **
module_configurator.gui_events = {
    on_gui_elem_changed = {
        {
            name = "select_module",
            handler = handle_module_selection
        }
    },
    on_gui_value_changed = {
        {
            name = "module_amount",
            handler = handle_module_slider_change
        }
    },
    on_gui_text_changed = {
        {
            name = "module_amount",
            handler = handle_module_textfield_change
        }
    }
}

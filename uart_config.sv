class uart_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    
    // Default configuration for the agent
    bit [15:0] baud_div = 651; // 100MHz / (9600 * 16) = 651
    bit [1:0]  parity_cfg = 0; // None

    `uvm_object_utils_begin(uart_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int(baud_div, UVM_ALL_ON)
        `uvm_field_int(parity_cfg, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_config");
        super.new(name);
    endfunction

endclass

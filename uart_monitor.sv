class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    virtual uart_if vif;
    uart_config m_cfg;
    uvm_analysis_port #(uart_trans) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "Virtual interface not set for uart_monitor")
        end
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg)) begin
             `uvm_info("MON", "No config, using default", UVM_LOW)
             m_cfg = uart_config::type_id::create("m_cfg");
        end
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_rx_serial(); // Serial Input (TB->DUT)
            monitor_tx_serial(); // Serial Output (DUT->TB)
            monitor_tx_host();   // Host Input (TB->DUT)
            monitor_rx_host();   // Host Output (DUT->TB)
        join
    endtask


    function real get_bit_period();
        return (vif.baud_div * 16.0) * 10.0; 
    endfunction

    // 1. RX PATH INPUT (Serial)
    task monitor_rx_serial(); 
        real bit_period;
        forever begin
            uart_trans item = uart_trans::type_id::create("rx_serial_item");
            item.path = uart_trans::RX_PATH;
            item.monitor_point = uart_trans::MON_INPUT;
            item.baud_div = vif.baud_div;

            @(negedge vif.tx);
            bit_period = get_bit_period();
            #(bit_period * 0.5 * 1ns);
            if (vif.tx != 0) continue; 
            #(bit_period * 1ns); 
            
            for(int i=0; i<8; i++) begin
                item.data[i] = vif.tx;
                #(bit_period * 1ns);
            end
            
            // Check Parity
            if (vif.parity_cfg != 0) begin
                bit expected_parity;
                // vif.parity_cfg: 1=Odd, 2=Even
                if (vif.parity_cfg == 1) expected_parity = ~(^item.data); // Odd
                else expected_parity = (^item.data); // Even
                
                if (vif.tx != expected_parity) begin
                    item.error_type = uart_trans::PARITY_ERR;
                end
                #(bit_period * 1ns);
            end

            // Check Stop Bit (Frame Error)
            if (vif.tx != 1) begin
                 if (item.error_type == uart_trans::NO_ERR) // Prioritize existing error
                    item.error_type = uart_trans::FRAME_ERR;
            end
            
             // Write BEFORE waiting for the full stop bit -> Removes Scoreboard Race Condition
            ap.write(item); 
            `uvm_info("MON", $sformatf("RX_PATH INPUT (Serial): 0x%0h err_type=%0s", item.data, item.error_type.name()), UVM_HIGH)

            #(bit_period * 1ns); // Stop bit duration
        end 
    endtask

    // 2. TX PATH OUTPUT (Serial)
    task monitor_tx_serial(); 
        real bit_period;
        forever begin
            uart_trans item = uart_trans::type_id::create("tx_serial_item");
            item.path = uart_trans::TX_PATH;
            item.monitor_point = uart_trans::MON_OUTPUT;
            
            @(negedge vif.rx); 
            bit_period = get_bit_period();
            #(bit_period * 1.5 * 1ns); 
            
            for(int i=0; i<8; i++) begin
                item.data[i] = vif.rx;
                #(bit_period * 1ns);
            end
            
            if (vif.parity_cfg != 0) #(bit_period * 1ns);
             
             ap.write(item); 
             `uvm_info("MON", $sformatf("TX_PATH OUTPUT (Serial): 0x%0h err=%b", item.data, vif.rx_err), UVM_MEDIUM)
        end
    endtask
    
    // 3. TX PATH INPUT (Host)
    task monitor_tx_host();
        forever begin
             uart_trans item = uart_trans::type_id::create("tx_host_item");
             item.path = uart_trans::TX_PATH;
             item.monitor_point = uart_trans::MON_INPUT;
             
             @(posedge vif.host_tx_en); // Wait for enable
             // Sample data
             #1step; // Just to be safe with timing
             item.data = vif.host_tx_data;
             
             ap.write(item);
             `uvm_info("MON", $sformatf("TX_PATH INPUT (Host): 0x%0h", item.data), UVM_HIGH)
             
             @(negedge vif.host_tx_en);
        end
    endtask
    
    // 4. RX PATH OUTPUT (Host)
    task monitor_rx_host();
        forever begin
             uart_trans item = uart_trans::type_id::create("rx_host_item");
             item.path = uart_trans::RX_PATH;
             item.monitor_point = uart_trans::MON_OUTPUT;
             
             @(posedge vif.host_rx_dv);
             item.data = vif.host_rx_data;
             item.error_type = (vif.rx_err) ? uart_trans::PARITY_ERR : uart_trans::NO_ERR; 
             
             ap.write(item);
             `uvm_info("MON", $sformatf("RX_PATH OUTPUT (Host): 0x%0h", item.data), UVM_MEDIUM)
             
             @(negedge vif.host_rx_dv);
        end
    endtask

    
endclass

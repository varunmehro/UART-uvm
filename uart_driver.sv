class uart_driver extends uvm_driver #(uart_trans);
    `uvm_component_utils(uart_driver)
    
    virtual uart_if vif;
    uart_config m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "Virtual interface not set for uart_driver")
        end
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg)) begin
             `uvm_info("NO_CFG", "No config object found, creating default", UVM_LOW)
             m_cfg = uart_config::type_id::create("m_cfg");
        end
    endfunction

    task run_phase(uvm_phase phase);
        vif.tx <= 1'b1; // Idle state
        // Drive static config signals
        vif.parity_cfg <= m_cfg.parity_cfg; 
        vif.baud_div   <= m_cfg.baud_div;
                
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(uart_trans item);
        real bit_period_ns; 
        real current_bit_period;
        
        // Jitter calculation
        bit_period_ns = (item.baud_div * 16.0) * 10.0;
        current_bit_period = bit_period_ns + (item.jitter_ps / 1000.0);

        // Apply config
        vif.baud_div <= item.baud_div;
        vif.parity_cfg <= item.parity_type;


        repeat(item.delay) @(posedge vif.clk);

        if (item.is_rx_input) begin
            // -----------------------------------------------------
            // RX STIMULUS (TB Drives Serial Line -> DUT RX)
            // -----------------------------------------------------
            `uvm_info("DRV", $sformatf("Driving RX Serial: 0x%0h Error: %s", item.data, item.error_type.name()), UVM_HIGH)
    
            // Start Bit
            vif.tx <= 1'b0;
            #(current_bit_period * 1ns);
    
            // Data Bits
            for (int i=0; i<8; i++) begin
                vif.tx <= item.data[i];
                #(current_bit_period * 1ns);
            end
    
            // Parity Bit
            if (item.parity_type != 0) begin
                bit p_bit;
                if (item.parity_type == 1) p_bit = ~(^item.data); // Odd
                else p_bit = ^item.data;                           // Even
                
                if (item.error_type == uart_trans::PARITY_ERR) begin
                     p_bit = ~p_bit;
                     `uvm_info("DRV", "Injecting Parity Error", UVM_MEDIUM)
                end
                
                vif.tx <= p_bit;
                #(current_bit_period * 1ns);
            end
    
            // Stop Bit
            if (item.error_type == uart_trans::FRAME_ERR) begin
                vif.tx <= 1'b0; 
                `uvm_info("DRV", "Injecting Frame Error", UVM_MEDIUM)
            end else begin
                vif.tx <= 1'b1;
            end
            #(current_bit_period * 1ns);
            
            // Recovery
            if (item.error_type == uart_trans::FRAME_ERR) begin
                 vif.tx <= 1'b1;
                 #(bit_period_ns * 1ns); 
            end

        end else begin
            // -----------------------------------------------------
            // TX STIMULUS (TB Drives Host Interface -> DUT TX)
            // -----------------------------------------------------
            `uvm_info("DRV", $sformatf("Driving TX Host: 0x%0h", item.data), UVM_HIGH)

            // Wait for Busy to be low (Handshake)
            fork
                begin
                    wait(vif.host_tx_busy == 0);
                end
                begin
                    #1ms;
                    `uvm_error("DRV", "Timeout waiting for host_tx_busy == 0 (Initial)")
                end
            join_any
            disable fork;
            
            @(posedge vif.clk);
            
            vif.host_tx_data <= item.data;
            vif.host_tx_en <= 1'b1;
            @(posedge vif.clk);
            vif.host_tx_en <= 1'b0;
            
            // Wait for transfer to complete
            fork
                begin
                    wait(vif.host_tx_busy == 1);
                    wait(vif.host_tx_busy == 0);
                end
                begin
                    #10ms; // Allow time for character transmission
                    `uvm_error("DRV", "Timeout waiting for host_tx_busy cycle")
                end
            join_any
            disable fork;
        end

    endtask

endclass

class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)

    uvm_analysis_imp #(uart_trans, uart_scoreboard) item_collected_export;
    

    uart_trans rx_expect_q[$];
    uart_trans tx_expect_q[$];
    
    uart_config m_cfg; 
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(uart_config)::get(this, "", "m_cfg", m_cfg)) begin
             `uvm_info("SCB", "No config, assuming defaults", UVM_LOW)
        end
    endfunction

    function void write(uart_trans trans);
        if (trans.monitor_point == uart_trans::MON_INPUT) begin
            // ------------------------------------
            // INPUT (Stimulus)
            // ------------------------------------
            if (trans.path == uart_trans::RX_PATH) begin
                `uvm_info("SCB", $sformatf("Queueing RX Expect: 0x%0h", trans.data), UVM_MEDIUM)
                rx_expect_q.push_back(trans);
            end else begin
                // TX PATH INPUT (Host TX)
                `uvm_info("SCB", $sformatf("Queueing TX Expect: 0x%0h", trans.data), UVM_HIGH)
                tx_expect_q.push_back(trans);
            end
        end else begin
            // ------------------------------------
            // OUTPUT (Result)
            // ------------------------------------
            uart_trans expected;
            string q_name;
            
            if (trans.path == uart_trans::RX_PATH) begin
                // Host RX Output
                if (rx_expect_q.size() == 0) begin
                    `uvm_error("SCB", $sformatf("Received UNEXPECTED RX Data: 0x%0h (Queue Empty)", trans.data))
                    return;
                end
                expected = rx_expect_q.pop_front();
                q_name = "RX";
            end else begin
                // Serial TX Output
                if (tx_expect_q.size() == 0) begin
                    `uvm_error("SCB", $sformatf("Received UNEXPECTED TX Data: 0x%0h (Queue Empty)", trans.data))
                    return;
                end
                expected = tx_expect_q.pop_front();
                q_name = "TX";
            end
            
            if (expected.data !== trans.data) begin
                `uvm_error("SCB", $sformatf("%s Mismatch! Expected: 0x%0h Received: 0x%0h", q_name, expected.data, trans.data))
            end else begin
                `uvm_info("SCB", $sformatf("%s Match! Data: 0x%0h", q_name, trans.data), UVM_LOW)
            end

            // Protocol Error Check (RX Only)
            if (q_name == "RX") begin
                bit exp_err, rcv_err;
                exp_err = (expected.error_type != uart_trans::NO_ERR);
                rcv_err = (trans.error_type != uart_trans::NO_ERR);
                
                if (exp_err != rcv_err) begin
                    `uvm_error("SCB", $sformatf("Protocol Error Mismatch! Expected Error: %b Received Error: %b", exp_err, rcv_err))
                end else if (exp_err) begin
                    `uvm_info("SCB", "Protocol Error successfully detected by DUT", UVM_MEDIUM)
                end
            end
        end
    endfunction
    
    function void check_phase(uvm_phase phase);
        if (rx_expect_q.size() > 0) begin
            `uvm_error("SCB", $sformatf("RX Scoreboard not empty! %0d items remaining.", rx_expect_q.size()))
        end
        if (tx_expect_q.size() > 0) begin
            `uvm_error("SCB", $sformatf("TX Scoreboard not empty! %0d items remaining.", tx_expect_q.size()))
        end
    endfunction

endclass

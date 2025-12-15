class uart_base_seq extends uvm_sequence #(uart_trans);
    `uvm_object_utils(uart_base_seq)
    
    function new(string name="uart_base_seq");
        super.new(name);
    endfunction
endclass

class uart_tx_seq extends uart_base_seq;
    `uvm_object_utils(uart_tx_seq)
    
    rand int num_trans;
    constraint c_num { num_trans inside {[5:20]}; }

    function new(string name="uart_tx_seq");
        super.new(name);
    endfunction

    task body();
        repeat(num_trans) begin
            req = uart_trans::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { baud_div == 651; }) begin
                `uvm_error("SEQ", "Randomization failed")
            end
            finish_item(req);
        end
    endtask
endclass

class uart_param_seq extends uart_base_seq;
    `uvm_object_utils(uart_param_seq)
    
    rand bit [7:0] specific_data;
    
    function new(string name="uart_param_seq");
        super.new(name);
    endfunction

    task body();
        req = uart_trans::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { data == specific_data; }) begin
             `uvm_error("SEQ", "Randomization failed")
        end
        finish_item(req);
    endtask
endclass

class uart_err_seq extends uart_base_seq;
    `uvm_object_utils(uart_err_seq)
    
    function new(string name="uart_err_seq");
        super.new(name);
    endfunction

    task body();
        // Injection of Parity Errors
        repeat(5) begin
             req = uart_trans::type_id::create("req");
             start_item(req);
             if(!req.randomize() with { error_type == uart_trans::PARITY_ERR; parity_type != 0; baud_div == 651; is_rx_input == 1; }) 
                `uvm_error("SEQ", "Randomization failed")
             finish_item(req);
        end
        // Injection of Frame Errors
        repeat(5) begin
             req = uart_trans::type_id::create("req");
             start_item(req);
             if(!req.randomize() with { error_type == uart_trans::FRAME_ERR; baud_div == 651; is_rx_input == 1; }) 
                `uvm_error("SEQ", "Randomization failed")
             finish_item(req);
        end
    endtask
endclass

class uart_jitter_seq extends uart_base_seq;
    `uvm_object_utils(uart_jitter_seq)
    
    function new(string name="uart_jitter_seq");
        super.new(name);
    endfunction
    
    task body();
        repeat(20) begin
             req = uart_trans::type_id::create("req");
             start_item(req);
             // Random jitter
             if(!req.randomize() with { jitter_ps != 0; }) 
                `uvm_error("SEQ", "Randomization failed")
             finish_item(req);
        end
    endtask
endclass



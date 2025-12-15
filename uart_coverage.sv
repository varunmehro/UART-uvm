class uart_coverage extends uvm_subscriber #(uart_trans);
    `uvm_component_utils(uart_coverage)

    uart_trans m_item;
    
    covergroup uart_cg;
        // Cover Data values
        cp_data: coverpoint m_item.data {
            bins low = {[0:63]};
            bins mid = {[64:127]};
            bins high = {[128:255]};
            bins all_values = {[0:255]}; // Full coverage might be too much for random, but good for directed
        }
        
        // Cover Parity Configuration
        cp_parity: coverpoint m_item.parity_type {
            bins none = {0};
            bins odd  = {1};
            bins even = {2};
        }
        
        // Cover Baud Divisor (Speed)
        cp_baud: coverpoint m_item.baud_div {
            bins fast = {[10:100]};
            bins normal = {[101:500]};
            bins slow = {[501:1000]};
        }
        
        // Cover Error Types
        cp_err: coverpoint m_item.error_type {
            bins no_err = {uart_trans::NO_ERR};
            bins par_err = {uart_trans::PARITY_ERR};
            bins frm_err = {uart_trans::FRAME_ERR};
        }
        
        // Cross coverage
        cross cp_parity, cp_data;
        cross cp_err, cp_parity;
    endgroup


    function new(string name, uvm_component parent);
        super.new(name, parent);
        uart_cg = new();
    endfunction

    function void write(uart_trans t);
        m_item = t;
        uart_cg.sample();
    endfunction

endclass

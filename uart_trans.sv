class uart_trans extends uvm_sequence_item;
    
    rand bit [7:0] data;
    rand bit [1:0] parity_type; // 0: None, 1: Odd, 2: Even
    rand int       baud_div;
    rand int       delay;       // Delays between frames
    rand bit       is_rx_input; // Legacy flag, try to use path/point instead
    
    typedef enum bit {RX_PATH, TX_PATH} path_t;
    rand path_t path; // RX_PATH = Serial->Host, TX_PATH = Host->Serial
    
    // For Monitor/Scoreboard:
    typedef enum bit {MON_INPUT, MON_OUTPUT} mon_point_t;
    mon_point_t monitor_point; 
    
    // Error Injection
    typedef enum bit [1:0] { NO_ERR=0, PARITY_ERR=1, FRAME_ERR=2 } err_t;
    rand err_t error_type;
    rand int   jitter_ps; // Jitter in picoseconds

    `uvm_object_utils_begin(uart_trans)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(parity_type, UVM_ALL_ON)
        `uvm_field_int(baud_div, UVM_ALL_ON)
        `uvm_field_int(delay, UVM_ALL_ON)
        `uvm_field_int(is_rx_input, UVM_ALL_ON)
        `uvm_field_enum(path_t, path, UVM_ALL_ON)
        `uvm_field_enum(mon_point_t, monitor_point, UVM_ALL_ON)
        `uvm_field_enum(err_t, error_type, UVM_ALL_ON)
        `uvm_field_int(jitter_ps, UVM_ALL_ON)
    `uvm_object_utils_end



    constraint c_baud { baud_div inside {[10:1000]}; }
    constraint c_parity { parity_type inside {0, 1, 2}; }
    constraint c_delay { delay inside {[0:20]}; }
    constraint c_err { error_type dist {NO_ERR:=90, PARITY_ERR:=5, FRAME_ERR:=5}; }
    constraint c_jitter { jitter_ps inside {[-100:100]}; } // Small jitter


    function new(string name = "uart_trans");
        super.new(name);
    endfunction

endclass

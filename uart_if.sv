interface uart_if(input bit clk, input bit rst_n);
    logic tx;
    logic rx;
    logic rx_err; // New signal

    // Configuration signals (controlled by env/test usually, or tied off)
    logic [15:0] baud_div;
    logic [1:0]  parity_cfg;
    logic        loopback_en; // New signal

    // Host Interface (Parallel) - To drive DUT TX
    logic [7:0] host_tx_data;
    logic       host_tx_en;
    logic       host_tx_busy; // Input from DUT
    
    // Host Interface (Parallel) - To monitor DUT RX (Output)
    logic [7:0] host_rx_data;
    logic       host_rx_dv;

    clocking cb @(posedge clk);
        default input #1step output #1ns;
        input tx;
        input rx;
        input rx_err;
        input host_tx_busy;
        
        // Monitor DUT outputs for RX path
        input host_rx_data; 
        input host_rx_dv;

        output baud_div;
        output parity_cfg;
        output loopback_en;
        output host_tx_data;
        output host_tx_en;
    endclocking

    modport DBG (clocking cb, input rst_n);

    // Assertions
    property start_bit_check_tx;
        @(posedge clk) disable iff(!rst_n)
        $fell(tx) |-> ##1 (tx == 0); // Start bit should be stable for at least 1 cycle (oversimplified)
        // More complex checks require symbol timing awareness
    endproperty
    
    ASSERT_START_TX: assert property (start_bit_check_tx);

endinterface

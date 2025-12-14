module top;
    import uvm_pkg::*;
    import uart_pkg::*

    logic clk;
    logic rst_n;

    // Clock Generation
    initial beginaa
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // Interface
    uart_if vif(clk, rst_n);

    // DUT Connectivity
    
    wire [7:0] dut_tx_data;
    wire       dut_tx_en;
    wire       dut_tx_busy;
    
    wire       dut_tx_out;
    
    wire [7:0] dut_rx_data;
    wire       dut_rx_dv;
    
    uart_rtl dut(
        .clk(clk),
        .rst_n(rst_n),
        .baud_div(vif.baud_div), // Dynamic Config from TB
        .parity_cfg(vif.parity_cfg), // Dynamic Config from TB
        
        // Host TX Interface (Input to DUT)
        .tx_data(vif.host_tx_data),
        .tx_en(vif.host_tx_en),
        .tx_busy(vif.host_tx_busy),
        
        .tx(dut_tx_out), // DUT TX Serial Output
        
        .rx_data(dut_rx_data),
        .rx_dv(dut_rx_dv),
        .rx_err(vif.rx_err),
        
        .rx(vif.tx),     // TB TX -> DUT RX
        .loopback_en(vif.loopback_en)
    );

    // Initial assignment
    assign vif.rx = dut_tx_out;
    
    // Connect Parallel Output to VIF for Monitor
    assign vif.host_rx_data = dut_rx_data;
    assign vif.host_rx_dv = dut_rx_dv;

    initial begin
        uvm_config_db#(virtual uart_if)::set(null, "*", "vif", vif);
        run_test(); 
    end

    // Waveform dump for EDA Playground (VCS/Riviera/etc)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end

endmodule

module uart_rtl #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 9600
) (
    input  wire       clk,
    input  wire       rst_n,
    // Configuration
    input  wire [15:0] baud_div, // Divider = CLK_FREQ / (BAUD_RATE * 16)
    input  wire [1:0]  parity_cfg, // 0: None, 1: Odd, 2: Even
    // TX Interface
    input  wire [7:0] tx_data,
    input  wire       tx_en,
    input  wire       loopback_en, 
    output reg        tx_busy,

    output reg        tx,
    // RX Interface
    output reg [7:0]  rx_data,
    output reg        rx_dv,
    output reg        rx_err,      // New: Parity/Frame Error Indicator
    input  wire       rx
);

    // -------------------------------------------------------------------------
    // Parameters & Constants
    // -------------------------------------------------------------------------
    // Default Divisor for 16x oversampling
    localparam DEFAULT_DIV_16 = (CLK_FREQ / BAUD_RATE) / 16;
    wire [15:0] current_div_16 = (baud_div > 0) ? baud_div : DEFAULT_DIV_16;

    // -------------------------------------------------------------------------
    // RX Synchronization
    // -------------------------------------------------------------------------
    reg rx_sync_1, rx_sync_2;
    wire rx_in_mux;

    // Internal Loopback Mux
    assign rx_in_mux = (loopback_en) ? tx : rx_sync_2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;
        end
    end

    // -------------------------------------------------------------------------
    // Baud Tick Generation (16x)
    // -------------------------------------------------------------------------
    reg [15:0] baud_cnt;
    wire       tick_16x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 0;
        end else begin
            if (baud_cnt >= current_div_16 - 1)
                baud_cnt <= 0;
            else
                baud_cnt <= baud_cnt + 1;
        end
    end
    assign tick_16x = (baud_cnt == 0);

    // -------------------------------------------------------------------------
    // TX Logic
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] { TX_IDLE, TX_START, TX_DATA, TX_PARITY, TX_STOP } tx_state_t;
    tx_state_t tx_state;
    reg [3:0]  tx_tick_cnt; 
    reg [2:0]  tx_bit_cnt;
    reg [7:0]  tx_shift_reg;
    reg        tx_parity_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_tick_cnt <= 0;
            tx_bit_cnt <= 0;
            tx_shift_reg <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    if (tx_en) begin
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                        tx_shift_reg <= tx_data;
                        tx <= 1'b0; // Start Bit
                        tx_tick_cnt <= 0;
                        case (parity_cfg)
                            2'd1: tx_parity_bit <= ~(^tx_data); // Odd
                            2'd2: tx_parity_bit <= ^tx_data;    // Even
                            default: tx_parity_bit <= 0;
                        endcase
                    end else begin
                        tx <= 1'b1;
                        tx_busy <= 1'b0;
                    end
                end

                TX_START: begin
                    if (tick_16x) begin
                        if (tx_tick_cnt == 15) begin
                            tx_tick_cnt <= 0;
                            tx_state <= TX_DATA;
                            tx_bit_cnt <= 0;
                            tx <= tx_shift_reg[0];
                            tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        end else begin
                            tx_tick_cnt <= tx_tick_cnt + 1;
                        end
                    end
                end

                TX_DATA: begin
                    if (tick_16x) begin
                        if (tx_tick_cnt == 15) begin
                            tx_tick_cnt <= 0;
                            if (tx_bit_cnt < 7) begin
                                tx_bit_cnt <= tx_bit_cnt + 1;
                                tx <= tx_shift_reg[0];
                                tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                            end else begin
                                if (parity_cfg != 0) begin
                                    tx_state <= TX_PARITY;
                                    tx <= tx_parity_bit;
                                end else begin
                                    tx_state <= TX_STOP;
                                    tx <= 1'b1;
                                end
                            end
                        end else begin
                            tx_tick_cnt <= tx_tick_cnt + 1;
                        end
                    end
                end

                TX_PARITY: begin
                    if (tick_16x) begin
                        if (tx_tick_cnt == 15) begin
                            tx_tick_cnt <= 0;
                            tx_state <= TX_STOP;
                            tx <= 1'b1;
                        end else begin
                            tx_tick_cnt <= tx_tick_cnt + 1;
                        end
                    end
                end

                TX_STOP: begin
                    if (tick_16x) begin
                        if (tx_tick_cnt == 15) begin
                            tx_tick_cnt <= 0;
                            tx_state <= TX_IDLE;
                            tx_busy <= 0;
                        end else begin
                            tx_tick_cnt <= tx_tick_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // RX Logic (16x Oversampling)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] { RX_IDLE, RX_START, RX_DATA, RX_PARITY, RX_STOP } rx_state_t;
    rx_state_t rx_state;
    reg [3:0]  rx_tick_cnt; 
    reg [2:0]  rx_bit_cnt;
    reg [7:0]  rx_shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_dv <= 0;
            rx_data <= 0;
            rx_err <= 0;
            rx_tick_cnt <= 0;
            rx_bit_cnt <= 0;
            rx_shift_reg <= 0;
        end else begin
            rx_dv <= 0; 
            if (tick_16x) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (rx_in_mux == 1'b0) begin 
                            rx_state <= RX_START;
                            rx_tick_cnt <= 0;
                        end
                    end

                    RX_START: begin
                        if (rx_tick_cnt == 7) begin
                            if (rx_in_mux == 1'b0) rx_tick_cnt <= rx_tick_cnt + 1;
                            else rx_state <= RX_IDLE;
                        end else if (rx_tick_cnt == 15) begin
                            rx_state <= RX_DATA;
                            rx_tick_cnt <= 0;
                            rx_bit_cnt <= 0;
                        end else begin
                            rx_tick_cnt <= rx_tick_cnt + 1;
                        end
                    end

                    RX_DATA: begin
                        if (rx_tick_cnt == 7) begin
                             rx_shift_reg[rx_bit_cnt] <= rx_in_mux;
                             rx_tick_cnt <= rx_tick_cnt + 1;
                        end else if (rx_tick_cnt == 15) begin
                             rx_tick_cnt <= 0;
                             if (rx_bit_cnt < 7) begin
                                 rx_bit_cnt <= rx_bit_cnt + 1;
                             end else begin
                                 if (parity_cfg != 0) rx_state <= RX_PARITY;
                                 else rx_state <= RX_STOP;
                             end
                        end else begin
                             rx_tick_cnt <= rx_tick_cnt + 1;
                        end
                    end

                    RX_PARITY: begin
                         if (rx_tick_cnt == 7) begin
                             bit expected;
                             if (parity_cfg == 2'd1) expected = ~(^rx_shift_reg); 
                             else expected = ^rx_shift_reg; 
                             if (rx_in_mux != expected) rx_err <= 1; 
                             rx_tick_cnt <= rx_tick_cnt + 1;
                         end else if (rx_tick_cnt == 15) begin
                             rx_tick_cnt <= 0;
                             rx_state <= RX_STOP;
                         end else begin
                             rx_tick_cnt <= rx_tick_cnt + 1;
                         end
                    end

                    RX_STOP: begin
                        if (rx_tick_cnt == 7) begin
                            if (rx_in_mux == 0) rx_err <= 1; 
                            rx_tick_cnt <= rx_tick_cnt + 1;
                        end else if (rx_tick_cnt == 15) begin
                            rx_tick_cnt <= 0;
                            rx_state <= RX_IDLE;
                            rx_data <= rx_shift_reg;
                            rx_dv <= 1;
                        end else begin
                            rx_tick_cnt <= rx_tick_cnt + 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule

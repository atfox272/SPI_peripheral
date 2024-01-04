`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/30/2023 10:56:15 PM
// Design Name: 
// Module Name: baudrate_prescaler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  System clock for all module in SPI (sample clock & sclk)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*  - Main Controller 
    - Baudrate Prescaler */
module controller
    #(
    parameter BAUDRATE_PRESCALER_WIDTH = 3,
    parameter int PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH] = {10, 50, 250, 1250, 3125, 15625, 31250, 62500}
    )
    (
    input clk,
    
    // Interface
    output SS,
    // Clock line 
    output clk_sample_en,
    output clk_shift_en,
    output clk_sclk_en,
    // Control line
    input  transaction_enable,
    // Configuration line
    input                                   CPOL,   // 0 - IDLE=0; 1 - IDLE=1;
    input                                   CPHA,   
    input [BAUDRATE_PRESCALER_WIDTH - 1:0]  baudrate_prescaler_config,
    
    input rst_n
    );
    /* Finite State Machine */
    localparam IDLE_STATE           = 3'd0;
    localparam START_TRANS_STATE    = 3'd1;
    localparam STOP_TRANS_STATE     = 3'd2;
    localparam DATA_SAMPLE_STATE    = 3'd3;
    localparam DATA_SHIFT_STATE     = 3'd4;
    localparam SCLK_TOGGLE_STATE    = 3'd5; 
    /* Prescaler */
    localparam MAX_PRESCALER = PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH - 1];
    localparam PRESCALER_COUNTER_WIDTH = $clog2(MAX_PRESCALER);
    
    reg  [1:0] spi_state;
    logic[1:0] spi_state_n;
    reg  [PRESCALER_COUNTER_WIDTH - 1:0] pres_counter;
    logic[PRESCALER_COUNTER_WIDTH - 1:0] pres_counter_n;
    logic[PRESCALER_COUNTER_WIDTH - 1:0] pres_counter_load;
    reg   clk_sample_en_reg;
    logic clk_sample_en_n;
    reg   clk_shift_en_reg;
    logic clk_shift_en_n;
    reg   clk_sclk_en_reg;
    logic clk_sclk_en_n;
    reg   SS_reg;
    logic SS_n;
    
    assign SS = SS_reg;
    assign clk_sample_en = clk_sample_en_reg;
    assign clk_shift_en = clk_shift_en_reg;
    assign clk_sclk_en = clk_sclk_en_reg;
    /* Generate MUX */
    always_comb begin
        pres_counter_load = PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH - 1] >> 1;
        for(int i = 0; i < 2**BAUDRATE_PRESCALER_WIDTH; i = i + 1) begin
            if(baudrate_prescaler_config == i) pres_counter_load = PRESCALER_TABLE[i] >> 1;
        end
    end
    
    always_comb begin
        spi_state_n = spi_state;
        pres_counter_n = pres_counter;
        SS_n = SS_reg;
        clk_sample_en_n = 0;
        clk_shift_en_n = 0;
        clk_sclk_en_n = 0;
        case(spi_state)
            IDLE_STATE: begin
                if(transaction_enable) begin
                    spi_state_n = START_TRANS_STATE;
                    SS_n = 0;
                    if(CPOL) begin
                        clk_sclk_en_n = 1;  // Toggle immediate
                    end
                end
            end 
            START_TRANS_STATE: begin
            
            end
            
            
        endcase
    end
    
endmodule

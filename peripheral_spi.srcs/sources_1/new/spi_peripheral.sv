`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/30/2023 10:33:33 PM
// Design Name: 
// Module Name: spi_peripheral
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "spi_hardware.vh"
module spi_peripheral
    #(
    parameter DATA_WIDTH                = 8,
    parameter FIFO_DEPTH                = 32,
    // Configuraiton index
    parameter CONFIG_REG_WIDTH          = 8,
    parameter BAUDRATE_PRESCALER_MSB    = 7,
    parameter BAUDRATE_PRESCALER_LSB    = 5,
    parameter CPOL_BIT                  = 4, 
    parameter CPHA_BIT                  = 3, 
    parameter MSB_FIRST_BIT             = 2,
    parameter DATA_SIZE_MSB             = 1, 
    parameter DATA_SIZE_LSB             = 0,
    localparam BAUDRATE_PRESCALER_WIDTH = BAUDRATE_PRESCALER_MSB - BAUDRATE_PRESCALER_LSB + 1,
    localparam CPOL_WIDTH               = 1,    // Fixed size
    localparam CPHA_WIDTH               = 1,    // Fixed size
    localparam MSB_FIRST_WIDTH          = 1,    // Fixed size
    localparam DATA_SIZE_WIDTH          = DATA_SIZE_MSB - DATA_SIZE_LSB + 1,
    // Prescaler Table (3-bit decoder) (12.5Mhz - 6.25Mhz - 2.5Mhz - 500Khz - 100Khz - 20Khz - 4Khz - 2Khz)
    parameter int PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH] = {10, 20, 50, 250, 1250, 6250, 31250, 62500},
    // Data size Table (2-bit decoder) (5bits - 6bits - 7bits - 8bits)
    parameter int DATA_SIZE_TABLE[2**DATA_SIZE_WIDTH] = {5, 6, 7, 8}
    )
    (
    input   clk,
    
    // Peripheral's interface
    output  MOSI,
    input   MISO,
    output  SS,
    output  SCLK,
    
    // Data line 
    input   [DATA_WIDTH - 1:0]          data_in,
    output  [DATA_WIDTH - 1:0]          data_out,
    // Control line
    input                               rd_req,
    input                               wr_req,
    output                              rd_available,
    output                              wr_available,
    // Configuration line 
    input   [CONFIG_REG_WIDTH - 1:0]    config_register,
    input   rst_n
    );
    
    /* TransBuffer's inteface */
    wire [DATA_WIDTH - 1:0] data_trans;
    wire                    rd_req_trans_fifo;
    wire                    trans_buffer_full;
    wire                    trans_buffer_empty;
    /* RecvBuffer's inteface */
    wire [DATA_WIDTH - 1:0] data_rcv;
    wire                    wr_req_rcv_fifo;
    wire                    rcv_buffer_full;
    wire                    rcv_buffer_empty;
    /* Configuration parameter */
    wire                                    CPOL;
    wire                                    CPHA;
    wire [BAUDRATE_PRESCALER_WIDTH - 1:0]   baudrate_prescaler_config;
    wire [DATA_SIZE_WIDTH - 1:0]            data_size_config;
    wire                                    msb_first_config;
    
    /* Control line */
    assign wr_available = ~trans_buffer_full;
    assign rd_available = ~rcv_buffer_empty;
    /* Configuration line (Decoder) */
    assign CPOL = config_register[CPOL_BIT];
    assign CPHA = config_register[CPHA_BIT];
    assign baudrate_prescaler_config = config_register[BAUDRATE_PRESCALER_MSB:BAUDRATE_PRESCALER_LSB];
    assign data_size_config = config_register[DATA_SIZE_MSB:DATA_SIZE_LSB];
    assign msb_first_config = config_register[MSB_FIRST_BIT];
    
    
    sync_fifo 
        #(
        .FIFO_DEPTH(FIFO_DEPTH)
        ) trans_buffer (
        .clk(clk),
        .data_in(data_in),
        .data_out(data_trans),
        .rd_req(rd_req_trans_fifo),
        .wr_req(wr_req),
        .empty(trans_buffer_empty),
        .full(trans_buffer_full),
        .almost_empty(),
        .almost_full(),
        .counter_threshold(),
        .counter_threshold_flag(),
        .rst_n(rst_n)
        );
        
    sync_fifo 
        #(
        .FIFO_DEPTH(FIFO_DEPTH)
        ) rcv_buffer (
        .clk(clk),
        .data_in(data_rcv),
        .data_out(data_out),
        .rd_req(rd_req),
        .wr_req(wr_req_rcv_fifo),
        .empty(rcv_buffer_empty),
        .full(rcv_buffer_full),
        .almost_empty(),
        .almost_full(),
        .counter_threshold(),
        .counter_threshold_flag(),
        .rst_n(rst_n)
        );
    
    spi_controller
        #(
        .DATA_SIZE_WIDTH(DATA_SIZE_WIDTH),
        .DATA_SIZE_TABLE(DATA_SIZE_TABLE),
        .BAUDRATE_PRESCALER_WIDTH(BAUDRATE_PRESCALER_WIDTH),
        .PRESCALER_TABLE(PRESCALER_TABLE)
        ) spi_controller (
        .clk(clk),
        /* Interface */
        .MOSI(MOSI),
        .MISO(MISO),
        `ifdef SS_INTERNAL_CONTROLLER
        .SS(SS),
        `endif
        .SCLK(SCLK),
        /* Data line */
        .data_trans(data_trans),
        .data_rcv(data_rcv),
        /* Control line */
        .rd_req_trans_fifo(rd_req_trans_fifo),
        .wr_req_rcv_fifo(wr_req_rcv_fifo),
        .trans_buffer_empty(trans_buffer_empty),
        .rcv_buffer_full(rcv_buffer_full),
        /* Configuration line */
        .CPOL(CPOL),
        .CPHA(CPHA),
        .baudrate_prescaler_config(baudrate_prescaler_config),
        .data_size_config(data_size_config),
        .msb_first_config(msb_first_config),
        .rst_n(rst_n)
        );
    
    
endmodule



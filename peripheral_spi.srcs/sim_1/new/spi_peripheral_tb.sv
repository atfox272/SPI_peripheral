`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/03/2024 02:44:57 PM
// Design Name: 
// Module Name: spi_peripheral_tb
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


module spi_peripheral_tb;

    parameter DATA_WIDTH = 8;
    parameter CONFIG_REG_WIDTH = 8;

    reg clk;
    
    // Peripheral's interface
    wire  MOSI;
    reg   MISO;
    wire  SS;
    wire  SCLK;
    
    // Data line 
    reg   [DATA_WIDTH - 1:0]          data_in;
    wire  [DATA_WIDTH - 1:0]          data_out;
    // Control line
    reg                               rd_req;
    reg                               wr_req;
    wire                              rd_available;
    wire                              wr_available;
    // Configuration line 
    wire  [CONFIG_REG_WIDTH - 1:0]    config_register;
    reg   [2:0]                       PRESCALER_ENCODE;
    reg                               CPOL;
    reg                               CPHA;
    reg                               MSB_BIT;
    reg   [1:0]                       DATA_SIZE;
    assign config_register = {PRESCALER_ENCODE, CPOL, CPHA, MSB_BIT, DATA_SIZE};
    reg   rst_n;

    reg [DATA_WIDTH - 1:0]            slave_buffer;
        
    spi_peripheral 
        #(
        ) spi_peripheral (
        .clk(clk),
        
        /* Interface */
        .MOSI(MOSI),
        .MISO(MISO),
        .SCLK(SCLK),
        .SS(SS),
        /* Data line */
        .data_in(data_in),
        .data_out(data_out),
        /* Control line */
        .rd_req(rd_req),
        .wr_req(wr_req),
        .rd_available(rd_available),
        .wr_available(wr_available),
        /* Configuration line */
        .config_register(config_register),
        
        .rst_n(rst_n)
        );
    
    initial begin
        clk <= 0;
        MISO <= 0;
        data_in <= 0;
        rd_req <= 0;
        wr_req <= 0;
        /* Start Configure */
        PRESCALER_ENCODE <= 0;  // Sys_clock / 10
        CPOL <= 0;              // IDLE LOW
        CPHA <= 0;              // Phase 0
        MSB_BIT <= 1;           // MSB first
        DATA_SIZE <= 3;         // 8bit
        /* End Configure */
        rst_n <= 1;
        #1; rst_n <= 0;
        #9; rst_n <= 1;
        
    end
    initial begin
        forever #1 clk <= ~clk;
    end
    initial begin
        #12;
        
        /* MODE 0 */
        data_in <= 8'h27;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h02;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h20;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h03;wr_req <= 1;#2;wr_req <= 0;#2;

        /* MODE 3 */
        #700;
        CPOL <= 1;              // IDLE HIGH;
        CPHA <= 1;
        MSB_BIT <= 0;
        #12;
        data_in <= 8'h21;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h10;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h20;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h03;wr_req <= 1;#2;wr_req <= 0;#2;
        
        /* MODE 1 */
        #700;
        CPOL <= 0;              // IDLE LOW;
        CPHA <= 1;
        MSB_BIT <= 0;
        #12;
        data_in <= 8'h01;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h02;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h03;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h04;wr_req <= 1;#2;wr_req <= 0;#2;
        
        
        /* MODE 2 */
        #700;
        CPOL <= 1;              // IDLE HIGH;
        CPHA <= 0;
        MSB_BIT <= 0;
        #12;
        data_in <= 8'haa;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'hbb;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'hcc;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'hff;wr_req <= 1;#2;wr_req <= 0;#2;
        
        /* Prescaler: sys_clk / 50 */
        /* MODE 1 */
        #700;
        PRESCALER_ENCODE <= 3;  // Sys_clock / 10
        CPOL <= 0;              // IDLE LOW;
        CPHA <= 1;
        MSB_BIT <= 0;
        #12;
        data_in <= 8'h01;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h02;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h03;wr_req <= 1;#2;wr_req <= 0;#2;
        data_in <= 8'h04;wr_req <= 1;#2;wr_req <= 0;#2;
        
    end
    
    /* SPI Slave sim */
    wire        SCLK_align = (CPOL ^ CPHA) ? ~SCLK : SCLK;
    reg [2:0]   counter;
    wire        slave_rcv_flag;
    assign slave_rcv_flag = counter == 7;
    always @(posedge SCLK_align, negedge rst_n) begin
        if(!rst_n) begin
            slave_buffer <= 0;
            counter <= 7;
        end
        else if (~SS) begin
            #1; /* Delay on rising edge of SCLK */
            if(MSB_BIT) begin
                slave_buffer <= {slave_buffer[6:0], MOSI};
            end 
            else begin
                slave_buffer <= {MOSI, slave_buffer[7:1]};
            end
            counter <= counter - 1'b1;
        end
    end
    /* Sample module */
    always @(negedge SCLK_align, negedge rst_n, posedge SS) begin
        if(!rst_n || SS) begin
            MISO <= 0;
        end 
        else if(~SS) begin
            #1;
            MISO <= ~MISO;
        end
    end 
    initial begin
        #10000; $stop;
    end 
endmodule

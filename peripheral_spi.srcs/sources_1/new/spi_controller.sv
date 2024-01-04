`include "spi_hardware.vh"
module spi_controller   /* Master mode */
    #(
    parameter DATA_WIDTH                                        = 8,
    parameter DATA_SIZE_WIDTH                                   = 2,
    parameter int DATA_SIZE_TABLE[2**DATA_SIZE_WIDTH]           = {5, 6, 7, 8},
    parameter BAUDRATE_PRESCALER_WIDTH                          = 3,
    parameter int PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH]  = {10, 50, 250, 1250, 3125, 15625, 31250, 62500}
    )
    (
    input                                   clk,
    
    // Interface
    output                                  MOSI,
    input                                   MISO,
    `ifdef SS_INTERNAL_CONTROLLER
    output                                  SS,
    `endif
    output                                  SCLK,
    // Data line
    input [DATA_WIDTH - 1:0]                data_trans,
    output[DATA_WIDTH - 1:0]                data_rcv,
    // Control line
    input                                   trans_buffer_empty,
    input                                   rcv_buffer_full,  /* Exception: FIFO is overflow */
    output                                  rd_req_trans_fifo,
    output                                  wr_req_rcv_fifo,
    // Configuration line 
    /* For SCLK */
    input                                   CPOL,   // 0 - IDLE=0       1 - IDLE=1
    input                                   CPHA,   // 0 - FirstEdge    1 - SecondEdge
    input [BAUDRATE_PRESCALER_WIDTH - 1:0]  baudrate_prescaler_config,
    /* for DATA */
    input [DATA_SIZE_WIDTH - 1:0]           data_size_config,
    input                                   msb_first_config,
    
    input                                   rst_n
    );
    /* Finite State Machine */
    localparam IDLE_STATE           = 3'd0;
    localparam POST_PHASE_STATE     = 3'd1;
    localparam DATA_SAMPLE_STATE    = 3'd2;
    localparam DATA_SHIFT_STATE     = 3'd3;
    /* For internal SS controller */
    localparam START_TRANS_STATE    = 3'd5; /* Set SS pin LOW */
    localparam END_TRANS_STATE      = 3'd6; /* Set SS pin HIGH */
    /* Prescaler */
    localparam MAX_PRESCALER            = PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH - 1];
    localparam PRESCALER_COUNTER_WIDTH  = $clog2(MAX_PRESCALER);
    /* Data */
    localparam COUNTER_WIDTH    = $clog2(DATA_WIDTH);
    localparam MSB_BIT          = DATA_WIDTH - 1;
    localparam LSB_BIT          = 0;
    
    /* Controller */ 
    reg  [2:0]                              spi_state;
    logic[2:0]                              spi_state_n;
    /* Clock */
    reg                                     SCLK_reg;
    logic                                   SCLK_n;
    reg  [PRESCALER_COUNTER_WIDTH - 1:0]    pres_counter;
    logic[PRESCALER_COUNTER_WIDTH - 1:0]    pres_counter_n;
    logic[PRESCALER_COUNTER_WIDTH - 1:0]    pres_counter_decr;
    logic[PRESCALER_COUNTER_WIDTH - 1:0]    pres_counter_load;
    logic                                   data_sample_en;
    logic                                   data_shift_en;
    /* Slave Select */
    `ifdef SS_INTERNAL_CONTROLLER
    reg                                     SS_reg;
    logic                                   SS_n;        
    `endif
    /* Data */
    reg  [COUNTER_WIDTH - 1:0]  data_counter;
    logic[COUNTER_WIDTH - 1:0]  data_counter_n;
    logic[COUNTER_WIDTH - 1:0]  data_counter_load;
    logic[COUNTER_WIDTH - 1:0]  data_counter_decr;
    /* Trans Data */
    reg  [DATA_WIDTH - 1:0]     trans_buffer;
    logic[DATA_WIDTH - 1:0]     trans_buffer_n;
    logic[DATA_WIDTH - 1:0]     trans_buffer_shift; // trans_buffer shift logic
    logic[DATA_WIDTH - 1:0]     trans_buffer_sll;   // trans_buffer shift left logic
    logic[DATA_WIDTH - 1:0]     trans_buffer_srl;   // trans_buffer shift right logic
    reg                         rd_req_trans_fifo_reg;
    logic                       rd_req_trans_fifo_n;
    /* Receive Data  */
    reg                         MISO_sample_buf;
    logic                       MISO_sample_buf_n;
    reg  [DATA_WIDTH - 1:0]     rcv_buffer;
    logic[DATA_WIDTH - 1:0]     rcv_buffer_n;
    reg  [DATA_WIDTH - 1:0]     data_rcv_reg;
    logic[DATA_WIDTH - 1:0]     data_rcv_n;
    reg                         wr_req_rcv_fifo_reg;
    logic                       wr_req_rcv_fifo_n;
    
    assign MOSI = (msb_first_config) ? trans_buffer[MSB_BIT] : trans_buffer[LSB_BIT];
    `ifdef SS_INTERNAL_CONTROLLER
    assign SS = SS_reg;
    `endif
    assign SCLK = SCLK_reg;
    assign data_rcv = data_rcv_reg;
    assign rd_req_trans_fifo = rd_req_trans_fifo_reg;
    assign wr_req_rcv_fifo = wr_req_rcv_fifo_reg;
    
    /* Generate MUX */
    always_comb begin
        pres_counter_load = PRESCALER_TABLE[2**BAUDRATE_PRESCALER_WIDTH - 1] >> 1;
        for(int i = 0; i < 2**BAUDRATE_PRESCALER_WIDTH; i = i + 1) begin
            if(baudrate_prescaler_config == i) pres_counter_load = (PRESCALER_TABLE[i] >> 1) - 1'b1;
        end
    end
    /* Baudrate Prescaler */
    always_comb begin
        pres_counter_n = pres_counter;
        pres_counter_decr = pres_counter - 1'b1;
        data_sample_en = (pres_counter == 1);   /* Sample enable */
        data_shift_en  = (pres_counter == 1);   /* Shift enable */
        pres_counter_n = ((pres_counter == 0) | (spi_state == IDLE_STATE)) ? pres_counter_load : pres_counter_decr;
    end    
    
    always_comb begin
        data_counter_load = DATA_SIZE_TABLE[2**BAUDRATE_PRESCALER_WIDTH - 1] - 1; /* Last option */
        data_counter_decr = data_counter - 1'b1;
        for(int i = 0; i < 2**DATA_SIZE_WIDTH; i = i + 10) begin
            if(data_size_config == i) data_counter_load = DATA_SIZE_TABLE[i] - 1;
        end
    end
    always_comb begin
        trans_buffer_sll = trans_buffer << 1;
        trans_buffer_srl = trans_buffer >> 1;
        trans_buffer_shift  = (msb_first_config) ? trans_buffer_sll : trans_buffer_srl;
    end 
    
   /*
    * Critical Path:
    *    MUX  -  MUX  -  MUX  -  MUX
    *  (4 states fsm)  (xx_en)  
    *  
    *   >=5 stalls in data_shift_en & data_sample_en
    */
    always_comb begin
        spi_state_n = spi_state;
        trans_buffer_n = trans_buffer;
        rcv_buffer_n = rcv_buffer;
        data_rcv_n = data_rcv_reg;
        data_counter_n = data_counter;
        wr_req_rcv_fifo_n = 0;
        rd_req_trans_fifo_n = 0;
        SCLK_n = SCLK_reg;
        `ifdef SS_INTERNAL_CONTROLLER
        SS_n = SS_reg;
        `endif
        MISO_sample_buf_n = MISO_sample_buf;
        case(spi_state)
            IDLE_STATE: begin
                SCLK_n = CPOL;
                `ifdef SS_INTERNAL_CONTROLLER
                if(~trans_buffer_empty) begin
                    spi_state_n = START_TRANS_STATE;
                    SS_n = 1'b0;
                    // Load data from FIFO
                    trans_buffer_n = data_trans;
                    rcv_buffer_n = 0;                    
                    data_counter_n = data_counter_load;
                    rd_req_trans_fifo_n = 1'b1;
                end
                `else
                if(~trans_buffer_empty) begin
                    spi_state_n = DATA_SHIFT_STATE;
                    // Load data from FIFO
                    trans_buffer_n = data_trans;
                    rcv_buffer_n = 0;                    
                    data_counter_n = data_counter_load;
                    rd_req_trans_fifo_n = 1'b1;
                    if(CPHA) begin  /* Sample in the second phase of transaction*/
                        SCLK_n = ~SCLK_reg;
                    end
                end
                `endif
                
            end 
            DATA_SAMPLE_STATE: begin
                if(data_shift_en) begin
                    spi_state_n = DATA_SHIFT_STATE;
                    rcv_buffer_n = {rcv_buffer[DATA_WIDTH - 2:0], MISO_sample_buf}; // rcv_buffer << 1;
                    trans_buffer_n = trans_buffer_shift;
                    SCLK_n = ~SCLK_reg;
                end
            end
            DATA_SHIFT_STATE: begin
                if(data_sample_en) begin
                    spi_state_n = (data_counter == 0) ? POST_PHASE_STATE : DATA_SAMPLE_STATE;
                    MISO_sample_buf_n = MISO;
                    SCLK_n = ~SCLK_reg;
                    data_counter_n = data_counter_decr;
                end
            end
            POST_PHASE_STATE: begin
                if(data_shift_en) begin
                    `ifdef SS_INTERNAL_CONTROLLER
                    spi_state_n = END_TRANS_STATE;
                    `else 
                    spi_state_n = IDLE_STATE;
                    `endif
                    if(~CPHA) begin
                        SCLK_n = ~SCLK_reg;
                    end
                    wr_req_rcv_fifo_n = 1'b1;
                    data_rcv_n = {rcv_buffer[DATA_WIDTH - 2:0], MISO_sample_buf};
                end
            end
            `ifdef SS_INTERNAL_CONTROLLER
            START_TRANS_STATE: begin
                spi_state_n = DATA_SHIFT_STATE;
                if(CPHA) begin  /* Sample in the second phase of transaction*/
                    SCLK_n = ~SCLK_reg;
                end
            end 
            END_TRANS_STATE: begin
                spi_state_n = IDLE_STATE;
                SS_n = 1'b1;
            end
            `endif
        endcase
    end
    
    always @(posedge clk) begin
        if(!rst_n) begin
            spi_state <= IDLE_STATE;
            wr_req_rcv_fifo_reg <= 1'b0;
            rd_req_trans_fifo_reg <= 1'b0;
            `ifdef SS_INTERNAL_CONTROLLER
            SS_reg <= 1'b1;
            `endif
            SCLK_reg <= 1'b0;
        end
        else begin
            spi_state <= spi_state_n;
            trans_buffer <= trans_buffer_n;
            rcv_buffer <= rcv_buffer_n;
            data_rcv_reg <= data_rcv_n;
            data_counter <= data_counter_n;
            pres_counter <= pres_counter_n;
            wr_req_rcv_fifo_reg <= wr_req_rcv_fifo_n;
            rd_req_trans_fifo_reg <= rd_req_trans_fifo_n;
            SCLK_reg <= SCLK_n;
            `ifdef SS_INTERNAL_CONTROLLER
            SS_reg <= SS_n;
            `endif
            MISO_sample_buf <= MISO_sample_buf_n;
        end
    end
    
endmodule

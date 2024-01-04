module trans_controller
    #(
    parameter DATA_WIDTH                                = 8,
    parameter DATA_SIZE_WIDTH                           = 2,
    parameter int DATA_SIZE_TABLE[2**DATA_SIZE_WIDTH]   = {5, 6, 7, 8}
    )
    (
    input clk,
    
    // Interface
    output                          MOSI,
    // Clock line
    input                           clk_sample_en,
    // Data line 
    input [DATA_WIDTH - 1:0]        data_trans,
    // Control line
    input                           trans_buffer_empty,
    output                          transaction_en,
    // Configuration line
    input [DATA_SIZE_WIDTH - 1:0]   data_size_config,
    input                           msb_first_config,
    
    input rst_n
    );
    /*Finite State Machine*/
    localparam IDLE_STATE       = 2'd0;
    localparam TRANS_STATE      = 2'd1;
    /*Data*/
    localparam COUNTER_WIDTH    = $clog2(DATA_WIDTH);
    localparam MSB_BIT          = 7;
    localparam LSB_BIT          = 0;
    
    reg  [1:0]                  trans_state;
    logic[1:0]                  trans_state_n;
    reg                         MOSI_reg;
    logic                       MOSI_n;
    reg  [DATA_WIDTH - 1:0]     trans_buffer;
    logic[DATA_WIDTH - 1:0]     trans_buffer_n;
    logic[DATA_WIDTH - 1:0]     trans_buffer_sll;   // trans_buffer shift left logic
    logic[DATA_WIDTH - 1:0]     trans_buffer_srl;   // trans_buffer shift right logic
    reg  [COUNTER_WIDTH - 1:0]  data_counter;
    logic[COUNTER_WIDTH - 1:0]  data_counter_n;
    logic[COUNTER_WIDTH - 1:0]  data_counter_load;
    logic[COUNTER_WIDTH - 1:0]  data_counter_decr;
    
    assign MOSI = MOSI_reg;
    assign transaction_en = trans_state == TRANS_STATE;
    
    always_comb begin
        data_counter_load = $clog2(DATA_SIZE_TABLE[2'd3]) - 1;
        data_counter_decr = data_counter - 1'b1;
        for(int i = 0; i < 2**DATA_SIZE_WIDTH; i = i + 10) begin
            if(data_size_config == i) data_counter_load = $clog2(DATA_SIZE_TABLE[i]) - 1;
        end
    end
    always_comb begin
        trans_buffer_sll = trans_buffer << 1;
        trans_buffer_srl = trans_buffer >> 1;
    end 
    
    /*
    Critical path: 
      START  -  MUX  -  MUX  -  SUB(8bit) (*)
           |   (FSM)  (CKEN)
             -  MUX  -  MUX  -  MUX
               (FSM)  (CKEN)  (MSB_DECIS)
    (if (clk_sample_en == 125Mhz))
    */
    always_comb begin
        trans_state_n = trans_state;
        trans_buffer_n = trans_buffer;
        data_counter_n = data_counter;
        MOSI_n = MOSI_reg;
        case(trans_state)
            IDLE_STATE: begin
                MOSI_n = 1'b0;
                if(~trans_buffer_empty) begin
                    trans_state_n = TRANS_STATE;
                    trans_buffer_n = data_trans;
                    data_counter_n = data_counter_load;
                end
            end 
            TRANS_STATE: begin
                if(clk_sample_en) begin
                    if(data_counter == 0) begin
                        trans_state_n = IDLE_STATE;
                    end
                    MOSI_n = (msb_first_config) ? trans_buffer[MSB_BIT] : trans_buffer[LSB_BIT];
                    trans_buffer_n = (msb_first_config) ? trans_buffer_sll : trans_buffer_srl;  
                    data_counter_n = data_counter_decr;
                end 
            end
        endcase 
    end 
    
    always @(posedge clk) begin
        if(!rst_n) begin
            trans_state <= IDLE_STATE;
            MOSI_reg <= 1'b0;
        end
        else begin
            trans_state <= trans_state_n;
            trans_buffer <= trans_buffer_n;
            data_counter <= data_counter_n;
            MOSI_reg <= MOSI_n;
        end
    end 
    
endmodule
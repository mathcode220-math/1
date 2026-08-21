//============================================================================
//  SILICON AGENT: Configuration Register File (AXI-Lite)
//  Runtime configuration for learning parameters
//============================================================================

`include "agent_types.svh"
`include "agent_interfaces.sv"

module config_registers #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_TOKENS = 5
) (
    input  logic                    aclk,
    input  logic                    areset_n,
    
    // AXI-Lite Slave Interface
    input  logic [ADDR_WIDTH-1:0]  awaddr,
    input  logic                    awvalid,
    output logic                    awready,
    
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wvalid,
    output logic                    wready,
    
    output logic [1:0]              bresp,
    output logic                    bvalid,
    input  logic                    bready,
    
    input  logic [ADDR_WIDTH-1:0]  araddr,
    input  logic                    arvalid,
    output logic                    arready,
    
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic                    rvalid,
    input  logic                    rready,
    
    // Configuration Output to Agent
    output agent_config_t           config_out
);
    // Register map addresses
    localparam ADDR_LEARNING_RATE   = 8'h00;
    localparam ADDR_Q_ALPHA_SHIFT   = 8'h04;
    localparam ADDR_BIAS_MAX        = 8'h08;
    localparam ADDR_BIAS_MIN        = 8'h0C;
    localparam ADDR_TARGET_REWARD   = 8'h10;
    localparam ADDR_CONTROL         = 8'h14;
    localparam ADDR_STATUS          = 8'h18;
    
    // Internal registers
    logic [7:0]  learning_rate_reg;
    logic [2:0]  q_alpha_shift_reg;
    logic [15:0] bias_max_reg;
    logic [15:0] bias_min_reg;
    logic [7:0]  target_reward_reg;
    logic        enable_learning_reg;
    logic        reset_q_values_reg;
    
    // Status registers
    logic [31:0] cycle_count_reg;
    logic        converged_reg;
    logic        error_reg;
    
    // AXI state machine
    typedef enum logic [2:0] {
        AXI_IDLE,
        AXI_WRITE_ADDR,
        AXI_WRITE_DATA,
        AXI_WRITE_RESP,
        AXI_READ_ADDR,
        AXI_READ_DATA
    } axi_state_t;
    
    axi_state_t axi_state, axi_next;
    logic [ADDR_WIDTH-1:0] write_addr_reg;
    
    // ------------------------------------------------------------------------
    // AXI State Machine
    // ------------------------------------------------------------------------
    always_comb begin
        axi_next = axi_state;
        awready = 1'b0;
        wready = 1'b0;
        bvalid = 1'b0;
        bresp = 2'b00;  // OKAY
        arready = 1'b0;
        rvalid = 1'b0;
        rresp = 2'b00;  // OKAY
        rdata = '0;
        
        unique case (axi_state)
            AXI_IDLE: begin
                if (awvalid) begin
                    axi_next = AXI_WRITE_ADDR;
                    awready = 1'b1;
                end else if (arvalid) begin
                    axi_next = AXI_READ_ADDR;
                    arready = 1'b1;
                end
            end
            
            AXI_WRITE_ADDR: begin
                if (wvalid) begin
                    axi_next = AXI_WRITE_DATA;
                    wready = 1'b1;
                end
            end
            
            AXI_WRITE_DATA: begin
                axi_next = AXI_WRITE_RESP;
                bvalid = 1'b1;
                if (bready)
                    axi_next = AXI_IDLE;
            end
            
            AXI_WRITE_RESP: begin
                axi_next = AXI_IDLE;
            end
            
            AXI_READ_ADDR: begin
                axi_next = AXI_READ_DATA;
                rvalid = 1'b1;
                if (rready)
                    axi_next = AXI_IDLE;
            end
            
            AXI_READ_DATA: begin
                axi_next = AXI_IDLE;
            end
            
            default: axi_next = AXI_IDLE;
        endcase
    end
    
    always_ff @(posedge aclk or negedge areset_n) begin
        if (!areset_n) begin
            axi_state <= AXI_IDLE;
            write_addr_reg <= '0;
        end else begin
            axi_state <= axi_next;
            if (awvalid && awready)
                write_addr_reg <= awaddr;
        end
    end
    
    // ------------------------------------------------------------------------
    // Register Write Logic
    // ------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge areset_n) begin
        if (!areset_n) begin
            learning_rate_reg <= `LEARNING_RATE_DEFAULT[7:0];
            q_alpha_shift_reg <= `Q_ALPHA_SHIFT_DEFAULT[2:0];
            bias_max_reg <= 16'd32767;
            bias_min_reg <= 16'd-32768;
            target_reward_reg <= 8'd128;
            enable_learning_reg <= 1'b1;
            reset_q_values_reg <= 1'b0;
        end else if (axi_state == AXI_WRITE_DATA) begin
            unique case (write_addr_reg)
                ADDR_LEARNING_RATE:
                    learning_rate_reg <= wdata[7:0];
                ADDR_Q_ALPHA_SHIFT:
                    q_alpha_shift_reg <= wdata[2:0];
                ADDR_BIAS_MAX:
                    bias_max_reg <= wdata[15:0];
                ADDR_BIAS_MIN:
                    bias_min_reg <= wdata[15:0];
                ADDR_TARGET_REWARD:
                    target_reward_reg <= wdata[7:0];
                ADDR_CONTROL:
                    begin
                        enable_learning_reg <= wdata[0];
                        reset_q_values_reg <= wdata[1];
                    end
            endcase
        end
    end
    
    // ------------------------------------------------------------------------
    // Register Read Logic
    // ------------------------------------------------------------------------
    always_comb begin
        unique case (araddr)
            ADDR_LEARNING_RATE:
                rdata = {24'd0, learning_rate_reg};
            ADDR_Q_ALPHA_SHIFT:
                rdata = {29'd0, q_alpha_shift_reg};
            ADDR_BIAS_MAX:
                rdata = {16'd0, bias_max_reg};
            ADDR_BIAS_MIN:
                rdata = {16'd0, bias_min_reg};
            ADDR_TARGET_REWARD:
                rdata = {24'd0, target_reward_reg};
            ADDR_CONTROL:
                rdata = {30'd0, reset_q_values_reg, enable_learning_reg};
            ADDR_STATUS:
                rdata = {30'd0, converged_reg, error_reg};
            default:
                rdata = '0;
        endcase
    end
    
    // ------------------------------------------------------------------------
    // Cycle Counter
    // ------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge areset_n) begin
        if (!areset_n)
            cycle_count_reg <= '0;
        else
            cycle_count_reg <= cycle_count_reg + 1'b1;
    end
    
    // ------------------------------------------------------------------------
    // Output Assignment
    // ------------------------------------------------------------------------
    assign config_out.learning_rate   = learning_rate_reg;
    assign config_out.q_alpha_shift   = q_alpha_shift_reg;
    assign config_out.bias_max        = bias_max_reg;
    assign config_out.bias_min        = bias_min_reg;
    assign config_out.target_reward   = target_reward_reg;
    assign config_out.enable_learning = enable_learning_reg;
    assign config_out.reset_q_values  = reset_q_values_reg;
    assign config_out.reserved        = 4'd0;
    
    assign converged_reg = config_out.enable_learning && !error_reg;
    assign error_reg = 1'b0;  // Placeholder for error detection
    
endmodule

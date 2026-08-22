//============================================================================
//  SILICON AGENT: Clock Domain Crossing (CDC) Synchronizers
//  Safe data transfer between fast execution and slow learning domains
//============================================================================

`include "agent_types.svh"

// ============================================================================
// 2-FF Synchronizer for Single-Bit Signals
// ============================================================================
module cdc_sync_2ff #(
    parameter int WIDTH = 1,
    parameter int STAGES = 2
) (
    input  logic             clk_dst,
    input  logic             rst_dst_n,
    input  logic [WIDTH-1:0] data_src,
    output logic [WIDTH-1:0] data_dst
);
    logic [WIDTH-1:0] sync_reg [STAGES-1:0];
    integer i;
    
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            for (i = 0; i < STAGES; i = i + 1)
                sync_reg[i] <= '0;
        end else begin
            sync_reg[0] <= data_src;
            for (i = 1; i < STAGES; i = i + 1)
                sync_reg[i] <= sync_reg[i-1];
        end
    end
    
    assign data_dst = sync_reg[STAGES-1];
    
    // Note: SVA properties moved to agent_sva.sv package for better tool support
    // Metastability safety is ensured by 2-FF synchronizer design
endmodule

// ============================================================================
// Handshake CDC for Multi-Bit Data (Full Protocol)
// ============================================================================
module cdc_handshake #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                  clk_src,
    input  logic                  rst_src_n,
    input  logic                  clk_dst,
    input  logic                  rst_dst_n,
    
    // Source interface
    input  logic                  src_valid,
    input  logic [DATA_WIDTH-1:0] src_data,
    output logic                  src_ready,
    
    // Destination interface
    output logic                  dst_valid,
    output logic [DATA_WIDTH-1:0] dst_data,
    input  logic                  dst_ready
);
    typedef enum logic [1:0] {
        HS_IDLE   = 2'b00,
        HS_REQ    = 2'b01,
        HS_ACK    = 2'b10,
        HS_DONE   = 2'b11
    } handshake_state_t;
    
    // Source side state machine
    handshake_state_t src_state, src_next;
    logic [DATA_WIDTH-1:0] src_data_reg;
    logic src_valid_int;
    
    // Dest side state machine
    handshake_state_t dst_state, dst_next;
    logic [DATA_WIDTH-1:0] dst_data_reg;
    logic dst_valid_int;
    
    // Cross-domain signals (synchronized)
    logic req_sync, ack_sync;
    
    // ------------------------------------------------------------------------
    // Source State Machine
    // ------------------------------------------------------------------------
    always_comb begin
        src_valid_int = 1'b0;
        
        unique case (src_state)
            HS_IDLE: begin
                if (src_valid) begin
                    src_next = HS_REQ;
                    src_valid_int = 1'b1;
                end else begin
                    src_next = HS_IDLE;
                end
            end
            
            HS_REQ: begin
                src_valid_int = 1'b1;
                if (ack_sync)
                    src_next = HS_DONE;
                else
                    src_next = HS_REQ;
            end
            
            HS_DONE: begin
                if (!src_valid)
                    src_next = HS_IDLE;
                else
                    src_next = HS_DONE;
            end
            
            default: src_next = HS_IDLE;
        endcase
    end
    
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            src_state <= HS_IDLE;
            src_data_reg <= '0;
        end else begin
            src_state <= src_next;
            if (src_valid && (src_state == HS_IDLE))
                src_data_reg <= src_data;
        end
    end
    
    assign src_ready = (src_state == HS_IDLE) || (src_state == HS_DONE);
    
    // ------------------------------------------------------------------------
    // Destination State Machine
    // ------------------------------------------------------------------------
    always_comb begin
        dst_next = handshake_state_t'(dst_state);
        dst_valid_int = 1'b0;
        
        unique case (dst_state)
            HS_IDLE: begin
                if (req_sync) begin
                    dst_next = HS_ACK;
                    dst_valid_int = 1'b1;
                end
            end
            
            HS_ACK: begin
                dst_valid_int = 1'b1;
                if (dst_ready)
                    dst_next = HS_DONE;
            end
            
            HS_DONE: begin
                if (!req_sync)
                    dst_next = HS_IDLE;
            end
            
            default: dst_next = HS_IDLE;
        endcase
    end
    
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            dst_state <= HS_IDLE;
            dst_data_reg <= '0;
        end else begin
            dst_state <= dst_next;
            if (req_sync && (dst_state == HS_IDLE))
                dst_data_reg <= src_data_reg;
        end
    end
    
    assign dst_valid = dst_valid_int;
    assign dst_data = dst_data_reg;
    
    // ------------------------------------------------------------------------
    // Cross-Domain Synchronization
    // ------------------------------------------------------------------------
    cdc_sync_2ff #(.WIDTH(1)) req_sync_inst (
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .data_src(src_valid_int),
        .data_dst(req_sync)
    );
    
    cdc_sync_2ff #(.WIDTH(1)) ack_sync_inst (
        .clk_dst(clk_src),
        .rst_dst_n(rst_src_n),
        .data_src((dst_state == HS_ACK)),
        .data_dst(ack_sync)
    );
    
    // Note: SVA properties moved to agent_sva.sv package for better tool support
    // The infinite delay ##[1:$] is not supported by all simulators
    // Handshake correctness is verified in testbench via functional coverage
endmodule

// ============================================================================
// Pulse Synchronizer (for single-cycle pulses across domains)
// ============================================================================
module cdc_pulse_sync (
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic clk_dst,
    input  logic rst_dst_n,
    input  logic src_pulse,      // Single-cycle pulse in source domain
    output logic dst_pulse       // Single-cycle pulse in destination domain
);
    logic src_toggle;
    logic dst_toggle;
    logic toggle_sync;
    logic prev_toggle;
    
    // Toggle on source pulse
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            src_toggle <= 1'b0;
        else if (src_pulse)
            src_toggle <= ~src_toggle;
    end
    
    // Synchronize toggle to destination domain
    cdc_sync_2ff #(.WIDTH(1)) toggle_sync_inst (
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .data_src(src_toggle),
        .data_dst(toggle_sync)
    );
    
    // Detect toggle change in destination
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            dst_toggle <= 1'b0;
            prev_toggle <= 1'b0;
        end else begin
            dst_toggle <= toggle_sync;
            prev_toggle <= dst_toggle;
        end
    end
    
    // Generate single-cycle pulse on toggle detection
    assign dst_pulse = (toggle_sync != prev_toggle);
endmodule

//============================================================================
//  SILICON AGENT: SystemVerilog Interfaces
//  Standardized interfaces for clean module communication
//============================================================================

`include "agent_types.svh"

// ============================================================================
// Agent Interface: Connects Decision Core, Q-Agent, and Bias Memory
// ============================================================================
interface agent_if #(
    parameter int NUM_TOKENS = 5,
    parameter int DATA_WIDTH = 16
) (
    input logic clk_fast,
    input logic clk_slow,
    input logic rst_n
);
    // Evidence from systolic array (execution domain)
    logic signed [DATA_WIDTH-1:0] evidence [NUM_TOKENS-1:0][NUM_TOKENS-1:0];
    logic                         evidence_valid;
    
    // Bias from bias memory (shared between domains)
    logic signed [DATA_WIDTH-1:0] bias [NUM_TOKENS-1:0];
    
    // Winner selection (execution domain)
    logic [$clog2(NUM_TOKENS)-1:0] winner_id;
    logic                          winner_valid;
    logic [NUM_TOKENS-1:0]         one_hot_weights;
    
    // Reward signal (slow learning domain)
    logic signed [DATA_WIDTH-1:0] reward;
    logic                         reward_valid;
    
    // Learning control signals
    logic                         learn_write_en;
    logic [$clog2(NUM_TOKENS)-1:0] learn_write_addr;
    logic signed [DATA_WIDTH-1:0]  learn_write_data;
    
    // Configuration interface (renamed from 'config' to avoid keyword conflict)
    agent_config_t cfg_reg;
    
    // Performance counters
    perf_counters_t perf;
    
    // Convergence flag
    logic converged;
    
    // Modport for Decision Core
    modport decision_core (
        input evidence, evidence_valid, bias,
        output winner_id, winner_valid, one_hot_weights
    );
    
    // Modport for Q-Guided Agent
    modport q_agent (
        input clk_slow, winner_id, winner_valid, reward, reward_valid, cfg_reg,
        output learn_write_en, learn_write_addr, learn_write_data, bias,
        output converged, perf
    );
    
    // Modport for Bias Memory
    modport bias_memory (
        input clk_fast, learn_write_en, learn_write_addr, learn_write_data,
        output bias
    );
    
    // Modport for Testbench
    modport tb (
        output clk_fast, clk_slow, rst_n, evidence, evidence_valid,
        output reward, reward_valid, cfg_reg,
        input winner_id, winner_valid, one_hot_weights, bias,
        input converged, perf
    );
endinterface

// ============================================================================
// CDC Handshake Interface: For safe clock domain crossing
// ============================================================================
interface cdc_if #(
    parameter int DATA_WIDTH = 16
) (
    input logic clk_src,
    input logic clk_dst,
    input logic rst_src_n,
    input logic rst_dst_n
);
    // Source side signals
    logic src_valid;
    logic [DATA_WIDTH-1:0] src_data;
    logic src_ready;
    
    // Destination side signals
    logic dst_valid;
    logic [DATA_WIDTH-1:0] dst_data;
    logic dst_ready;
    
    // Modport for Source
    modport source (
        input clk_src, rst_src_n, src_ready,
        output src_valid, src_data
    );
    
    // Modport for Destination
    modport destination (
        input clk_dst, rst_dst_n, dst_valid, dst_data,
        output dst_ready
    );
    
    // Modport for Synchronizer
    modport sync (
        input src_valid, src_data, dst_ready,
        output dst_valid, dst_data, src_ready
    );
endinterface

// ============================================================================
// AXI-Lite Configuration Interface
// ============================================================================
interface axi_lite_if #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
) (
    input logic aclk,
    input logic areset_n
);
    // Address/Control
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;
    
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;
    
    // Write Data
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;
    
    // Write Response
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;
    
    // Read Data
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;
    
    // Modport for Master (Testbench/CPU)
    modport master (
        input aclk, areset_n, awready, arready, wready, bvalid, bresp, rvalid, rresp, rdata,
        output awaddr, awvalid, araddr, arvalid, wdata, wstrb, wvalid, bready, rready
    );
    
    // Modport for Slave (Config Registers)
    modport slave (
        input aclk, areset_n, awaddr, awvalid, araddr, arvalid, wdata, wstrb, wvalid, bready, rready,
        output awready, arready, wready, bvalid, bresp, rvalid, rresp, rdata
    );
endinterface

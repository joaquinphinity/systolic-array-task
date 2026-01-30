`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: mac_pe
// Description: 8-bit Multiply-Accumulate Processing Element for Systolic Array
//
// See docs/Specification.md for detailed requirements.
//-----------------------------------------------------------------------------

module mac_pe (
    input  wire        clk,
    input  wire        rst_n,          // Active-low synchronous reset
    
    // Control signals
    input  wire        enable,         // Enable computation
    input  wire        weight_load,    // Load new weight into shadow buffer
    input  wire        weight_switch,  // Switch active weight buffer
    
    // Weight interface
    input  wire [7:0]  weight_data,    // 8-bit signed weight input
    
    // Activation data flow (left to right)
    input  wire [7:0]  data_in,        // 8-bit signed activation from left neighbor
    output reg  [7:0]  data_out,       // 8-bit signed activation to right neighbor
    
    // Partial sum data flow (top to bottom)
    input  wire [31:0] psum_in,        // 32-bit partial sum from top neighbor
    output reg  [31:0] psum_out        // 32-bit partial sum to bottom neighbor
);

    // Your implementation here

endmodule

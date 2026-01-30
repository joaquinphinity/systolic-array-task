`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: mac_pe
// Description: 8-bit Multiply-Accumulate Processing Element for Systolic Array
//
// See docs/Specification.md for detailed requirements.
//-----------------------------------------------------------------------------

module mac_pe (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,
    input  wire        weight_load,
    input  wire        weight_switch,
    
    // Weight interface
    input  wire [7:0]  weight_data,
    
    // Activation data flow (left to right)
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    
    // Partial sum data flow (top to bottom)
    input  wire [31:0] psum_in,
    output reg  [31:0] psum_out
);

    // Your implementation here

endmodule

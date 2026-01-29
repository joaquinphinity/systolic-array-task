`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: systolic_array_2x2
// Description: 2x2 Systolic Array for Matrix Multiplication
//
// See docs/Specification.md for detailed requirements.
//-----------------------------------------------------------------------------

module systolic_array_2x2 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,
    input  wire        weight_load,
    input  wire        weight_switch,
    input  wire        weight_col_sel,
    
    // Weight data
    input  wire [7:0]  weight_row0_data,
    input  wire [7:0]  weight_row1_data,
    
    // Activation inputs
    input  wire [7:0]  act_row0_in,
    input  wire [7:0]  act_row1_in,
    
    // Partial sum inputs
    input  wire [31:0] psum_col0_in,
    input  wire [31:0] psum_col1_in,
    
    // Activation outputs
    output wire [7:0]  act_row0_out,
    output wire [7:0]  act_row1_out,
    
    // Partial sum outputs
    output wire [31:0] psum_col0_out,
    output wire [31:0] psum_col1_out
);

    // Your implementation here

endmodule

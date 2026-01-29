`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: systolic_array_2x2
// Description: 2x2 Systolic Array for Matrix Multiplication
//
// TODO: Implement the 2x2 systolic array by instantiating 4 mac_pe modules
//       and wiring them together according to the specification.
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

    // TODO: Implement the systolic array
    // 
    // Requirements:
    // 1. Instantiate 4 mac_pe modules in a 2x2 grid
    // 2. Wire horizontal connections (activation flow: left to right)
    // 3. Wire vertical connections (partial sum flow: top to bottom)
    // 4. Route weight_load to selected column based on weight_col_sel
    // 5. Broadcast enable and weight_switch to all PEs

    // Placeholder outputs (remove when implementing)
    assign act_row0_out = 8'h00;
    assign act_row1_out = 8'h00;
    assign psum_col0_out = 32'h00000000;
    assign psum_col1_out = 32'h00000000;

endmodule

`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: systolic_array_2x2
// Description: 2x2 Systolic Array for Matrix Multiplication
//
// This module implements a 2x2 systolic array using MAC processing elements.
// It performs matrix multiplication: C = A × B where:
//   - A is the activation matrix (fed from the left, row by row)
//   - B is the weight matrix (pre-loaded into the PEs)
//   - C is the output matrix (collected from the bottom)
//
// Data Flow:
//   - Activations enter from the left with diagonal skewing
//   - Partial sums flow from top to bottom
//   - Results exit from the bottom row after computation completes
//
// Weight Loading:
//   - Weights are loaded column by column into the PEs
//   - weight_col_sel selects which column (0 or 1) receives weights
//   - weight_row_data provides weights for both rows simultaneously
//
// Array Layout:
//   PE[0][0] --- PE[0][1]     (Row 0)
//      |           |
//   PE[1][0] --- PE[1][1]     (Row 1)
//
//-----------------------------------------------------------------------------

module systolic_array_2x2 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,              // Enable computation
    input  wire        weight_load,         // Load weights into selected column
    input  wire        weight_switch,       // Switch all PEs to new weight buffer
    input  wire        weight_col_sel,      // Select column for weight loading (0 or 1)
    
    // Weight data (one weight per row, loaded into selected column)
    input  wire [7:0]  weight_row0_data,    // Weight for row 0 of selected column
    input  wire [7:0]  weight_row1_data,    // Weight for row 1 of selected column
    
    // Activation inputs (from the left, already skewed by caller)
    input  wire [7:0]  act_row0_in,         // Activation input for row 0
    input  wire [7:0]  act_row1_in,         // Activation input for row 1
    
    // Partial sum inputs (from the top, typically 0 for first operation)
    input  wire [31:0] psum_col0_in,        // Partial sum input for column 0
    input  wire [31:0] psum_col1_in,        // Partial sum input for column 1
    
    // Activation outputs (to the right, for chaining arrays)
    output wire [7:0]  act_row0_out,        // Activation output from row 0
    output wire [7:0]  act_row1_out,        // Activation output from row 1
    
    // Partial sum outputs (from the bottom)
    output wire [31:0] psum_col0_out,       // Result for column 0
    output wire [31:0] psum_col1_out        // Result for column 1
);

    //-------------------------------------------------------------------------
    // Internal wires for PE interconnections
    //-------------------------------------------------------------------------
    
    // Horizontal activation wires (left to right within each row)
    wire [7:0] act_r0_c0_to_c1;   // Row 0: PE[0][0] -> PE[0][1]
    wire [7:0] act_r1_c0_to_c1;   // Row 1: PE[1][0] -> PE[1][1]
    
    // Vertical partial sum wires (top to bottom within each column)
    wire [31:0] psum_c0_r0_to_r1; // Col 0: PE[0][0] -> PE[1][0]
    wire [31:0] psum_c1_r0_to_r1; // Col 1: PE[0][1] -> PE[1][1]
    
    // Weight load signals for each PE (active when loading that column)
    wire weight_load_col0;
    wire weight_load_col1;
    
    //-------------------------------------------------------------------------
    // Weight loading logic
    //-------------------------------------------------------------------------
    
    // Route weight_load to the selected column
    assign weight_load_col0 = weight_load & ~weight_col_sel;
    assign weight_load_col1 = weight_load &  weight_col_sel;
    
    //-------------------------------------------------------------------------
    // PE Instantiations
    //-------------------------------------------------------------------------
    
    // PE[0][0] - Top-left
    mac_pe pe_00 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col0),
        .weight_switch(weight_switch),
        .weight_data  (weight_row0_data),
        .data_in      (act_row0_in),
        .data_out     (act_r0_c0_to_c1),
        .psum_in      (psum_col0_in),
        .psum_out     (psum_c0_r0_to_r1)
    );
    
    // PE[0][1] - Top-right
    mac_pe pe_01 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row0_data),
        .data_in      (act_r0_c0_to_c1),
        .data_out     (act_row0_out),
        .psum_in      (psum_col1_in),
        .psum_out     (psum_c1_r0_to_r1)
    );
    
    // PE[1][0] - Bottom-left
    mac_pe pe_10 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col0),
        .weight_switch(weight_switch),
        .weight_data  (weight_row1_data),
        .data_in      (act_row1_in),
        .data_out     (act_r1_c0_to_c1),
        .psum_in      (psum_c0_r0_to_r1),
        .psum_out     (psum_col0_out)
    );
    
    // PE[1][1] - Bottom-right
    mac_pe pe_11 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row1_data),
        .data_in      (act_r1_c0_to_c1),
        .data_out     (act_row1_out),
        .psum_in      (psum_c1_r0_to_r1),
        .psum_out     (psum_col1_out)
    );

endmodule

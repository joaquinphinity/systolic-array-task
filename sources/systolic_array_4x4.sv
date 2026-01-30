`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: systolic_array_4x4
// Description: 4x4 Systolic Array for Matrix Multiplication
//
// This module implements a 4x4 systolic array using MAC processing elements.
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
//   - weight_col_sel selects which column (0-3) receives weights
//   - weight_row_data provides weights for all rows simultaneously
//
// Array Layout:
//   PE[0][0] --- PE[0][1] --- PE[0][2] --- PE[0][3]     (Row 0)
//      |           |           |           |
//   PE[1][0] --- PE[1][1] --- PE[1][2] --- PE[1][3]     (Row 1)
//      |           |           |           |
//   PE[2][0] --- PE[2][1] --- PE[2][2] --- PE[2][3]     (Row 2)
//      |           |           |           |
//   PE[3][0] --- PE[3][1] --- PE[3][2] --- PE[3][3]     (Row 3)
//
//-----------------------------------------------------------------------------

module systolic_array_4x4 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,              // Enable computation
    input  wire        weight_load,         // Load weights into selected column
    input  wire        weight_switch,       // Switch all PEs to new weight buffer
    input  wire [1:0]  weight_col_sel,      // Select column for weight loading (0-3)
    
    // Weight data (one weight per row, loaded into selected column)
    input  wire [7:0]  weight_row0_data,    // Weight for row 0 of selected column
    input  wire [7:0]  weight_row1_data,    // Weight for row 1 of selected column
    input  wire [7:0]  weight_row2_data,    // Weight for row 2 of selected column
    input  wire [7:0]  weight_row3_data,    // Weight for row 3 of selected column
    
    // Activation inputs (from the left, already skewed by caller)
    input  wire [7:0]  act_row0_in,         // Activation input for row 0
    input  wire [7:0]  act_row1_in,         // Activation input for row 1
    input  wire [7:0]  act_row2_in,         // Activation input for row 2
    input  wire [7:0]  act_row3_in,         // Activation input for row 3
    
    // Partial sum inputs (from the top, typically 0 for first operation)
    input  wire [31:0] psum_col0_in,        // Partial sum input for column 0
    input  wire [31:0] psum_col1_in,        // Partial sum input for column 1
    input  wire [31:0] psum_col2_in,        // Partial sum input for column 2
    input  wire [31:0] psum_col3_in,        // Partial sum input for column 3
    
    // Activation outputs (to the right, for chaining arrays)
    output wire [7:0]  act_row0_out,        // Activation output from row 0
    output wire [7:0]  act_row1_out,        // Activation output from row 1
    output wire [7:0]  act_row2_out,        // Activation output from row 2
    output wire [7:0]  act_row3_out,        // Activation output from row 3
    
    // Partial sum outputs (from the bottom)
    output wire [31:0] psum_col0_out,       // Result for column 0
    output wire [31:0] psum_col1_out,       // Result for column 1
    output wire [31:0] psum_col2_out,       // Result for column 2
    output wire [31:0] psum_col3_out        // Result for column 3
);

    //-------------------------------------------------------------------------
    // Internal wires for PE interconnections
    //-------------------------------------------------------------------------
    
    // Horizontal activation wires (left to right within each row)
    // Row 0
    wire [7:0] act_r0_c0_to_c1;
    wire [7:0] act_r0_c1_to_c2;
    wire [7:0] act_r0_c2_to_c3;
    // Row 1
    wire [7:0] act_r1_c0_to_c1;
    wire [7:0] act_r1_c1_to_c2;
    wire [7:0] act_r1_c2_to_c3;
    // Row 2
    wire [7:0] act_r2_c0_to_c1;
    wire [7:0] act_r2_c1_to_c2;
    wire [7:0] act_r2_c2_to_c3;
    // Row 3
    wire [7:0] act_r3_c0_to_c1;
    wire [7:0] act_r3_c1_to_c2;
    wire [7:0] act_r3_c2_to_c3;
    
    // Vertical partial sum wires (top to bottom within each column)
    // Column 0
    wire [31:0] psum_c0_r0_to_r1;
    wire [31:0] psum_c0_r1_to_r2;
    wire [31:0] psum_c0_r2_to_r3;
    // Column 1
    wire [31:0] psum_c1_r0_to_r1;
    wire [31:0] psum_c1_r1_to_r2;
    wire [31:0] psum_c1_r2_to_r3;
    // Column 2
    wire [31:0] psum_c2_r0_to_r1;
    wire [31:0] psum_c2_r1_to_r2;
    wire [31:0] psum_c2_r2_to_r3;
    // Column 3
    wire [31:0] psum_c3_r0_to_r1;
    wire [31:0] psum_c3_r1_to_r2;
    wire [31:0] psum_c3_r2_to_r3;
    
    // Weight load signals for each column
    wire weight_load_col0;
    wire weight_load_col1;
    wire weight_load_col2;
    wire weight_load_col3;
    
    //-------------------------------------------------------------------------
    // Weight loading logic
    //-------------------------------------------------------------------------
    
    // Route weight_load to the selected column
    assign weight_load_col0 = weight_load & (weight_col_sel == 2'b00);
    assign weight_load_col1 = weight_load & (weight_col_sel == 2'b01);
    assign weight_load_col2 = weight_load & (weight_col_sel == 2'b10);
    assign weight_load_col3 = weight_load & (weight_col_sel == 2'b11);
    
    //-------------------------------------------------------------------------
    // PE Instantiations - Row 0
    //-------------------------------------------------------------------------
    
    // PE[0][0] - Row 0, Column 0
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
    
    // PE[0][1] - Row 0, Column 1
    mac_pe pe_01 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row0_data),
        .data_in      (act_r0_c0_to_c1),
        .data_out     (act_r0_c1_to_c2),
        .psum_in      (psum_col1_in),
        .psum_out     (psum_c1_r0_to_r1)
    );
    
    // PE[0][2] - Row 0, Column 2
    mac_pe pe_02 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col2),
        .weight_switch(weight_switch),
        .weight_data  (weight_row0_data),
        .data_in      (act_r0_c1_to_c2),
        .data_out     (act_r0_c2_to_c3),
        .psum_in      (psum_col2_in),
        .psum_out     (psum_c2_r0_to_r1)
    );
    
    // PE[0][3] - Row 0, Column 3
    mac_pe pe_03 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col3),
        .weight_switch(weight_switch),
        .weight_data  (weight_row0_data),
        .data_in      (act_r0_c2_to_c3),
        .data_out     (act_row0_out),
        .psum_in      (psum_col3_in),
        .psum_out     (psum_c3_r0_to_r1)
    );
    
    //-------------------------------------------------------------------------
    // PE Instantiations - Row 1
    //-------------------------------------------------------------------------
    
    // PE[1][0] - Row 1, Column 0
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
        .psum_out     (psum_c0_r1_to_r2)
    );
    
    // PE[1][1] - Row 1, Column 1
    mac_pe pe_11 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row1_data),
        .data_in      (act_r1_c0_to_c1),
        .data_out     (act_r1_c1_to_c2),
        .psum_in      (psum_c1_r0_to_r1),
        .psum_out     (psum_c1_r1_to_r2)
    );
    
    // PE[1][2] - Row 1, Column 2
    mac_pe pe_12 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col2),
        .weight_switch(weight_switch),
        .weight_data  (weight_row1_data),
        .data_in      (act_r1_c1_to_c2),
        .data_out     (act_r1_c2_to_c3),
        .psum_in      (psum_c2_r0_to_r1),
        .psum_out     (psum_c2_r1_to_r2)
    );
    
    // PE[1][3] - Row 1, Column 3
    mac_pe pe_13 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col3),
        .weight_switch(weight_switch),
        .weight_data  (weight_row1_data),
        .data_in      (act_r1_c2_to_c3),
        .data_out     (act_row1_out),
        .psum_in      (psum_c3_r0_to_r1),
        .psum_out     (psum_c3_r1_to_r2)
    );
    
    //-------------------------------------------------------------------------
    // PE Instantiations - Row 2
    //-------------------------------------------------------------------------
    
    // PE[2][0] - Row 2, Column 0
    mac_pe pe_20 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col0),
        .weight_switch(weight_switch),
        .weight_data  (weight_row2_data),
        .data_in      (act_row2_in),
        .data_out     (act_r2_c0_to_c1),
        .psum_in      (psum_c0_r1_to_r2),
        .psum_out     (psum_c0_r2_to_r3)
    );
    
    // PE[2][1] - Row 2, Column 1
    mac_pe pe_21 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row2_data),
        .data_in      (act_r2_c0_to_c1),
        .data_out     (act_r2_c1_to_c2),
        .psum_in      (psum_c1_r1_to_r2),
        .psum_out     (psum_c1_r2_to_r3)
    );
    
    // PE[2][2] - Row 2, Column 2
    mac_pe pe_22 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col2),
        .weight_switch(weight_switch),
        .weight_data  (weight_row2_data),
        .data_in      (act_r2_c1_to_c2),
        .data_out     (act_r2_c2_to_c3),
        .psum_in      (psum_c2_r1_to_r2),
        .psum_out     (psum_c2_r2_to_r3)
    );
    
    // PE[2][3] - Row 2, Column 3
    mac_pe pe_23 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col3),
        .weight_switch(weight_switch),
        .weight_data  (weight_row2_data),
        .data_in      (act_r2_c2_to_c3),
        .data_out     (act_row2_out),
        .psum_in      (psum_c3_r1_to_r2),
        .psum_out     (psum_c3_r2_to_r3)
    );
    
    //-------------------------------------------------------------------------
    // PE Instantiations - Row 3
    //-------------------------------------------------------------------------
    
    // PE[3][0] - Row 3, Column 0
    mac_pe pe_30 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col0),
        .weight_switch(weight_switch),
        .weight_data  (weight_row3_data),
        .data_in      (act_row3_in),
        .data_out     (act_r3_c0_to_c1),
        .psum_in      (psum_c0_r2_to_r3),
        .psum_out     (psum_col0_out)
    );
    
    // PE[3][1] - Row 3, Column 1
    mac_pe pe_31 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col1),
        .weight_switch(weight_switch),
        .weight_data  (weight_row3_data),
        .data_in      (act_r3_c0_to_c1),
        .data_out     (act_r3_c1_to_c2),
        .psum_in      (psum_c1_r2_to_r3),
        .psum_out     (psum_col1_out)
    );
    
    // PE[3][2] - Row 3, Column 2
    mac_pe pe_32 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col2),
        .weight_switch(weight_switch),
        .weight_data  (weight_row3_data),
        .data_in      (act_r3_c1_to_c2),
        .data_out     (act_r3_c2_to_c3),
        .psum_in      (psum_c2_r2_to_r3),
        .psum_out     (psum_col2_out)
    );
    
    // PE[3][3] - Row 3, Column 3
    mac_pe pe_33 (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .weight_load  (weight_load_col3),
        .weight_switch(weight_switch),
        .weight_data  (weight_row3_data),
        .data_in      (act_r3_c2_to_c3),
        .data_out     (act_row3_out),
        .psum_in      (psum_c3_r2_to_r3),
        .psum_out     (psum_col3_out)
    );

endmodule

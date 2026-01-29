`timescale 1ns/1ps

//-----------------------------------------------------------------------------
// Module: mac_pe
// Description: 8-bit Multiply-Accumulate Processing Element for Systolic Array
//
// This module implements a single MAC unit that forms the building block of
// a TPU-style systolic array. It supports:
//   - 8-bit signed integer multiplication
//   - 32-bit accumulation with saturation
//   - Double-buffered weights for parallel weight loading
//   - Systolic data flow (left-to-right for activations, top-to-bottom for partial sums)
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

    // Double-buffered weights
    reg [7:0] weight_buffer_0;
    reg [7:0] weight_buffer_1;
    reg       active_buffer;
    
    wire [7:0] active_weight;
    wire signed [15:0] mult_result;
    wire signed [31:0] mult_extended;
    wire signed [32:0] acc_result;
    wire signed [31:0] acc_saturated;
    
    // Select active weight
    assign active_weight = active_buffer ? weight_buffer_1 : weight_buffer_0;
    
    // Weight buffer control
    always @(posedge clk) begin
        if (!rst_n) begin
            weight_buffer_0 <= 8'h00;
            weight_buffer_1 <= 8'h00;
            active_buffer   <= 1'b0;
        end else begin
            if (weight_load) begin
                if (active_buffer)
                    weight_buffer_0 <= weight_data;
                else
                    weight_buffer_1 <= weight_data;
            end
            if (weight_switch) begin
                active_buffer <= ~active_buffer;
            end
        end
    end
    
    // MAC computation
    assign mult_result = $signed(data_in) * $signed(active_weight);
    assign mult_extended = {{16{mult_result[15]}}, mult_result};
    assign acc_result = $signed(psum_in) + $signed(mult_extended);
    
    // Saturation
    assign acc_saturated = (acc_result > $signed(32'h7FFFFFFF)) ? 32'h7FFFFFFF :
                          (acc_result < $signed(-32'h80000000)) ? 32'h80000000 :
                          acc_result[31:0];
    
    // Systolic data flow
    always @(posedge clk) begin
        if (!rst_n) begin
            data_out <= 8'h00;
            psum_out <= 32'h00000000;
        end else if (enable) begin
            data_out <= data_in;
            psum_out <= acc_saturated;
        end
    end

endmodule

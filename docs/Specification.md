# 2x2 Systolic Array Specification

## Overview

Implement a 2x2 systolic array that performs matrix computations using MAC (Multiply-Accumulate) Processing Elements. This is a core building block for TPU-style accelerators.

## Array Layout

```
              psum_col0_in    psum_col1_in
                   |               |
                   v               v
act_row0_in --> [PE 0,0] -----> [PE 0,1] --> act_row0_out
                   |               |
                   v               v
act_row1_in --> [PE 1,0] -----> [PE 1,1] --> act_row1_out
                   |               |
                   v               v
              psum_col0_out   psum_col1_out
```

## Module Interface

```systemverilog
module systolic_array_2x2 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,              // Enable computation
    input  wire        weight_load,         // Load weights into selected column
    input  wire        weight_switch,       // Switch all PEs to new weight buffer
    input  wire        weight_col_sel,      // Select column: 0=col0, 1=col1
    
    // Weight data (loaded into selected column)
    input  wire [7:0]  weight_row0_data,    // Weight for row 0 of selected column
    input  wire [7:0]  weight_row1_data,    // Weight for row 1 of selected column
    
    // Activation inputs (from the left)
    input  wire [7:0]  act_row0_in,
    input  wire [7:0]  act_row1_in,
    
    // Partial sum inputs (from the top)
    input  wire [31:0] psum_col0_in,
    input  wire [31:0] psum_col1_in,
    
    // Activation outputs (to the right)
    output wire [7:0]  act_row0_out,
    output wire [7:0]  act_row1_out,
    
    // Partial sum outputs (from the bottom)
    output wire [31:0] psum_col0_out,
    output wire [31:0] psum_col1_out
);
```

## MAC PE Interface (Provided)

The `mac_pe` module is provided in `sources/mac_pe.sv`. Its interface is:

```systemverilog
module mac_pe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        weight_load,
    input  wire        weight_switch,
    input  wire [7:0]  weight_data,
    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    input  wire [31:0] psum_in,
    output reg  [31:0] psum_out
);
```

## Functional Requirements

### 1. PE Instantiation
- Instantiate 4 `mac_pe` modules named: `pe_00`, `pe_01`, `pe_10`, `pe_11`
- PE naming: `pe_<row><col>` (e.g., `pe_01` is row 0, column 1)

### 2. Horizontal Wiring (Activation Flow)
- `act_row0_in` connects to `pe_00.data_in`
- `pe_00.data_out` connects to `pe_01.data_in`
- `pe_01.data_out` connects to `act_row0_out`
- Same pattern for row 1: `act_row1_in` → `pe_10` → `pe_11` → `act_row1_out`

### 3. Vertical Wiring (Partial Sum Flow)
- `psum_col0_in` connects to `pe_00.psum_in`
- `pe_00.psum_out` connects to `pe_10.psum_in`
- `pe_10.psum_out` connects to `psum_col0_out`
- Same pattern for column 1

### 4. Weight Loading
- When `weight_load` is high and `weight_col_sel=0`:
  - `weight_row0_data` goes to `pe_00.weight_data`
  - `weight_row1_data` goes to `pe_10.weight_data`
  - Only column 0 PEs receive `weight_load=1`
- When `weight_load` is high and `weight_col_sel=1`:
  - `weight_row0_data` goes to `pe_01.weight_data`
  - `weight_row1_data` goes to `pe_11.weight_data`
  - Only column 1 PEs receive `weight_load=1`

### 5. Control Signal Broadcasting
- `enable` connects to all 4 PEs
- `weight_switch` connects to all 4 PEs
- `clk` and `rst_n` connect to all 4 PEs

## Timing

All PEs have 1-cycle latency. Data flows through the array as follows:
- Cycle N: Activation enters PE from the left
- Cycle N+1: Activation exits PE to the right, partial sum exits to the bottom

## Example Weight Loading Sequence

To load a 2x2 weight matrix `[[w00, w01], [w10, w11]]`:

1. Set `weight_col_sel=0`, `weight_row0_data=w00`, `weight_row1_data=w10`
2. Assert `weight_load` for 1 cycle
3. Set `weight_col_sel=1`, `weight_row0_data=w01`, `weight_row1_data=w11`
4. Assert `weight_load` for 1 cycle
5. Assert `weight_switch` for 1 cycle to activate the loaded weights

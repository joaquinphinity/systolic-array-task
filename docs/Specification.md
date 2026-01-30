# 4x4 Systolic Array Specification

## Overview

Implement a 4x4 systolic array that performs matrix computations using MAC (Multiply-Accumulate) Processing Elements. This is a core building block for TPU-style accelerators.

## Array Layout

```
                 psum_col0_in  psum_col1_in  psum_col2_in  psum_col3_in
                      |             |             |             |
                      v             v             v             v
act_row0_in --> [PE 0,0] ----> [PE 0,1] ----> [PE 0,2] ----> [PE 0,3] --> act_row0_out
                      |             |             |             |
                      v             v             v             v
act_row1_in --> [PE 1,0] ----> [PE 1,1] ----> [PE 1,2] ----> [PE 1,3] --> act_row1_out
                      |             |             |             |
                      v             v             v             v
act_row2_in --> [PE 2,0] ----> [PE 2,1] ----> [PE 2,2] ----> [PE 2,3] --> act_row2_out
                      |             |             |             |
                      v             v             v             v
act_row3_in --> [PE 3,0] ----> [PE 3,1] ----> [PE 3,2] ----> [PE 3,3] --> act_row3_out
                      |             |             |             |
                      v             v             v             v
                 psum_col0_out psum_col1_out psum_col2_out psum_col3_out
```

## Module Interface

```systemverilog
module systolic_array_4x4 (
    input  wire        clk,
    input  wire        rst_n,
    
    // Control signals
    input  wire        enable,              // Enable computation
    input  wire        weight_load,         // Load weights into selected column
    input  wire        weight_switch,       // Switch all PEs to new weight buffer
    input  wire [1:0]  weight_col_sel,      // Select column: 0=col0, 1=col1, 2=col2, 3=col3
    
    // Weight data (loaded into selected column)
    input  wire [7:0]  weight_row0_data,    // Weight for row 0 of selected column
    input  wire [7:0]  weight_row1_data,    // Weight for row 1 of selected column
    input  wire [7:0]  weight_row2_data,    // Weight for row 2 of selected column
    input  wire [7:0]  weight_row3_data,    // Weight for row 3 of selected column
    
    // Activation inputs (from the left)
    input  wire [7:0]  act_row0_in,
    input  wire [7:0]  act_row1_in,
    input  wire [7:0]  act_row2_in,
    input  wire [7:0]  act_row3_in,
    
    // Partial sum inputs (from the top)
    input  wire [31:0] psum_col0_in,
    input  wire [31:0] psum_col1_in,
    input  wire [31:0] psum_col2_in,
    input  wire [31:0] psum_col3_in,
    
    // Activation outputs (to the right)
    output wire [7:0]  act_row0_out,
    output wire [7:0]  act_row1_out,
    output wire [7:0]  act_row2_out,
    output wire [7:0]  act_row3_out,
    
    // Partial sum outputs (from the bottom)
    output wire [31:0] psum_col0_out,
    output wire [31:0] psum_col1_out,
    output wire [31:0] psum_col2_out,
    output wire [31:0] psum_col3_out
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
- Instantiate 16 `mac_pe` modules in a 4x4 grid
- PE naming convention: `pe_<row><col>` (e.g., `pe_23` is row 2, column 3)
- Valid PE names: pe_00, pe_01, pe_02, pe_03, pe_10, pe_11, pe_12, pe_13, pe_20, pe_21, pe_22, pe_23, pe_30, pe_31, pe_32, pe_33

### 2. Horizontal Wiring (Activation Flow)
- Row 0: `act_row0_in` → `pe_00` → `pe_01` → `pe_02` → `pe_03` → `act_row0_out`
- Row 1: `act_row1_in` → `pe_10` → `pe_11` → `pe_12` → `pe_13` → `act_row1_out`
- Row 2: `act_row2_in` → `pe_20` → `pe_21` → `pe_22` → `pe_23` → `act_row2_out`
- Row 3: `act_row3_in` → `pe_30` → `pe_31` → `pe_32` → `pe_33` → `act_row3_out`

### 3. Vertical Wiring (Partial Sum Flow)
- Column 0: `psum_col0_in` → `pe_00` → `pe_10` → `pe_20` → `pe_30` → `psum_col0_out`
- Column 1: `psum_col1_in` → `pe_01` → `pe_11` → `pe_21` → `pe_31` → `psum_col1_out`
- Column 2: `psum_col2_in` → `pe_02` → `pe_12` → `pe_22` → `pe_32` → `psum_col2_out`
- Column 3: `psum_col3_in` → `pe_03` → `pe_13` → `pe_23` → `pe_33` → `psum_col3_out`

### 4. Weight Loading
- `weight_col_sel` is a 2-bit signal selecting the target column (0-3)
- When `weight_load` is high:
  - Only the PEs in the selected column receive `weight_load=1`
  - `weight_row0_data` goes to the row 0 PE of the selected column
  - `weight_row1_data` goes to the row 1 PE of the selected column
  - `weight_row2_data` goes to the row 2 PE of the selected column
  - `weight_row3_data` goes to the row 3 PE of the selected column

### 5. Control Signal Broadcasting
- `enable` connects to all 16 PEs
- `weight_switch` connects to all 16 PEs
- `clk` and `rst_n` connect to all 16 PEs

## Timing

All PEs have 1-cycle latency. Data flows through the array as follows:
- Cycle N: Activation enters PE from the left
- Cycle N+1: Activation exits PE to the right, partial sum exits to the bottom

For a 4x4 array with diagonal feeding:
- First result appears at cycle 4 (after activations propagate through 4 PE rows)
- Last result appears at cycle 10 (after all diagonal wavefronts complete)

## Example Weight Loading Sequence

To load a 4x4 weight matrix:

```
[[w00, w01, w02, w03],
 [w10, w11, w12, w13],
 [w20, w21, w22, w23],
 [w30, w31, w32, w33]]
```

1. Set `weight_col_sel=0`, set `weight_rowX_data=wX0` for all rows, assert `weight_load` for 1 cycle
2. Set `weight_col_sel=1`, set `weight_rowX_data=wX1` for all rows, assert `weight_load` for 1 cycle
3. Set `weight_col_sel=2`, set `weight_rowX_data=wX2` for all rows, assert `weight_load` for 1 cycle
4. Set `weight_col_sel=3`, set `weight_rowX_data=wX3` for all rows, assert `weight_load` for 1 cycle
5. Assert `weight_switch` for 1 cycle to activate the loaded weights

## MAC PE Behavior

The provided `mac_pe` module implements:
- 8-bit signed multiplication of activation and weight
- 32-bit accumulation with saturation at INT32_MIN/INT32_MAX
- Double-buffered weights (load to shadow buffer, switch to activate)
- Synchronous active-low reset

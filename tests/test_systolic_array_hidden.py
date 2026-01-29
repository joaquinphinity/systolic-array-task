"""
Hidden Cocotb testbench for 2x2 Systolic Array
Comprehensive tests for grading agent submissions.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import random


def to_unsigned_8bit(val):
    """Convert signed value to unsigned 8-bit."""
    return val & 0xFF


def signed_32bit(val):
    """Convert to signed 32-bit representation."""
    if val > 0x7FFFFFFF:
        val -= 0x100000000
    return val


async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.enable.value = 0
    dut.weight_load.value = 0
    dut.weight_switch.value = 0
    dut.weight_col_sel.value = 0
    dut.weight_row0_data.value = 0
    dut.weight_row1_data.value = 0
    dut.act_row0_in.value = 0
    dut.act_row1_in.value = 0
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def load_weights(dut, weights):
    """
    Load a 2x2 weight matrix into the array.
    weights[i][j] goes to PE[i][j]
    """
    # Load column 0 (PE[0,0] and PE[1,0])
    dut.weight_col_sel.value = 0
    dut.weight_row0_data.value = to_unsigned_8bit(weights[0][0])
    dut.weight_row1_data.value = to_unsigned_8bit(weights[1][0])
    dut.weight_load.value = 1
    await RisingEdge(dut.clk)
    dut.weight_load.value = 0
    await RisingEdge(dut.clk)
    
    # Load column 1 (PE[0,1] and PE[1,1])
    dut.weight_col_sel.value = 1
    dut.weight_row0_data.value = to_unsigned_8bit(weights[0][1])
    dut.weight_row1_data.value = to_unsigned_8bit(weights[1][1])
    dut.weight_load.value = 1
    await RisingEdge(dut.clk)
    dut.weight_load.value = 0
    await RisingEdge(dut.clk)
    
    # Switch to activate weights
    dut.weight_switch.value = 1
    await RisingEdge(dut.clk)
    dut.weight_switch.value = 0
    await RisingEdge(dut.clk)


async def run_systolic_and_capture(dut, A, B):
    """
    Run systolic computation and capture all non-zero outputs.
    Returns list of (cycle, col0, col1) tuples with non-zero values.
    """
    await load_weights(dut, B)
    
    dut.enable.value = 1
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    
    results = []
    
    for cycle in range(10):
        if cycle == 0:
            dut.act_row0_in.value = to_unsigned_8bit(A[0][0])
            dut.act_row1_in.value = 0
        elif cycle == 1:
            dut.act_row0_in.value = to_unsigned_8bit(A[0][1])
            dut.act_row1_in.value = to_unsigned_8bit(A[1][0])
        elif cycle == 2:
            dut.act_row0_in.value = 0
            dut.act_row1_in.value = to_unsigned_8bit(A[1][1])
        else:
            dut.act_row0_in.value = 0
            dut.act_row1_in.value = 0
        
        await RisingEdge(dut.clk)
        
        col0 = signed_32bit(int(dut.psum_col0_out.value))
        col1 = signed_32bit(int(dut.psum_col1_out.value))
        
        if col0 != 0 or col1 != 0:
            results.append((cycle, col0, col1))
    
    return results


def compute_expected_outputs(A, B):
    """
    Compute expected systolic array outputs.
    
    For a 2x2 systolic array with diagonal feeding, the outputs are:
    - col0 cycle 2: A[0,0]*B[0,0] + A[1,0]*B[1,0]
    - col0 cycle 3: A[0,1]*B[0,0] + A[1,1]*B[1,0]
    - col1 cycle 3: A[0,0]*B[0,1] + A[1,0]*B[1,1]
    - col1 cycle 4: A[0,1]*B[0,1] + A[1,1]*B[1,1]
    """
    # These are the expected outputs at each cycle
    expected = []
    
    # Cycle 2: col0 has result, col1 is 0
    col0_c2 = A[0][0] * B[0][0] + A[1][0] * B[1][0]
    expected.append((2, col0_c2, 0))
    
    # Cycle 3: both columns have results
    col0_c3 = A[0][1] * B[0][0] + A[1][1] * B[1][0]
    col1_c3 = A[0][0] * B[0][1] + A[1][0] * B[1][1]
    expected.append((3, col0_c3, col1_c3))
    
    # Cycle 4: col0 is 0, col1 has result
    col1_c4 = A[0][1] * B[0][1] + A[1][1] * B[1][1]
    expected.append((4, 0, col1_c4))
    
    return expected


# =============================================================================
# TEST CASES
# =============================================================================

@cocotb.test()
async def test_reset_clears_outputs(dut):
    """Test that reset properly clears all outputs to zero."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    await load_weights(dut, [[5, 5], [5, 5]])
    dut.enable.value = 1
    dut.act_row0_in.value = 10
    await ClockCycles(dut.clk, 5)
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    
    assert int(dut.psum_col0_out.value) == 0, "psum_col0_out should be 0 after reset"
    assert int(dut.psum_col1_out.value) == 0, "psum_col1_out should be 0 after reset"
    
    dut._log.info("test_reset_clears_outputs PASSED")


@cocotb.test()
async def test_activation_passthrough(dut):
    """Test that activations pass through horizontally."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    await load_weights(dut, [[0, 0], [0, 0]])
    
    dut.enable.value = 1
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    
    dut.act_row0_in.value = 42
    dut.act_row1_in.value = 99
    await RisingEdge(dut.clk)
    
    dut.act_row0_in.value = 0
    dut.act_row1_in.value = 0
    await ClockCycles(dut.clk, 2)
    
    row0_out = int(dut.act_row0_out.value)
    row1_out = int(dut.act_row1_out.value)
    
    assert row0_out == 42, f"Expected act_row0_out=42, got {row0_out}"
    assert row1_out == 99, f"Expected act_row1_out=99, got {row1_out}"
    
    dut._log.info("test_activation_passthrough PASSED")


@cocotb.test()
async def test_single_pe_computation(dut):
    """Test single PE multiply-accumulate."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Load weight=3 into PE[0,0]
    dut.weight_col_sel.value = 0
    dut.weight_row0_data.value = 3
    dut.weight_row1_data.value = 0
    dut.weight_load.value = 1
    await RisingEdge(dut.clk)
    dut.weight_load.value = 0
    
    dut.weight_switch.value = 1
    await RisingEdge(dut.clk)
    dut.weight_switch.value = 0
    await RisingEdge(dut.clk)
    
    dut.enable.value = 1
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    dut.act_row0_in.value = 7
    dut.act_row1_in.value = 0
    await RisingEdge(dut.clk)
    
    dut.act_row0_in.value = 0
    await ClockCycles(dut.clk, 2)
    
    # Result should appear: 7 * 3 = 21
    col0 = signed_32bit(int(dut.psum_col0_out.value))
    assert col0 == 21, f"Expected 21, got {col0}"
    
    dut._log.info("test_single_pe_computation PASSED")


@cocotb.test()
async def test_column_routing(dut):
    """Test that weight_col_sel routes to correct columns."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Load col0=2, col1=5
    dut.weight_col_sel.value = 0
    dut.weight_row0_data.value = 2
    dut.weight_row1_data.value = 0
    dut.weight_load.value = 1
    await RisingEdge(dut.clk)
    
    dut.weight_col_sel.value = 1
    dut.weight_row0_data.value = 5
    dut.weight_row1_data.value = 0
    dut.weight_load.value = 1
    await RisingEdge(dut.clk)
    dut.weight_load.value = 0
    
    dut.weight_switch.value = 1
    await RisingEdge(dut.clk)
    dut.weight_switch.value = 0
    await RisingEdge(dut.clk)
    
    dut.enable.value = 1
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    dut.act_row0_in.value = 10
    dut.act_row1_in.value = 0
    await RisingEdge(dut.clk)
    
    dut.act_row0_in.value = 0
    await ClockCycles(dut.clk, 3)
    
    # Capture col1 result (10*5=50)
    col1 = signed_32bit(int(dut.psum_col1_out.value))
    assert col1 == 50, f"Expected col1=50, got {col1}"
    
    dut._log.info("test_column_routing PASSED")


@cocotb.test()
async def test_systolic_computation(dut):
    """Test full systolic array computation."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    A = [[1, 2], [3, 4]]
    B = [[5, 6], [7, 8]]
    
    results = await run_systolic_and_capture(dut, A, B)
    expected = compute_expected_outputs(A, B)
    
    dut._log.info(f"Results: {results}")
    dut._log.info(f"Expected: {expected}")
    
    # Verify cycle 2 output (col0 only)
    assert any(r[0] == 2 and r[1] == expected[0][1] for r in results), \
        f"Cycle 2 col0 mismatch"
    
    # Verify cycle 3 outputs
    c3_results = [r for r in results if r[0] == 3]
    assert len(c3_results) > 0, "No results at cycle 3"
    assert c3_results[0][1] == expected[1][1], f"Cycle 3 col0 mismatch"
    assert c3_results[0][2] == expected[1][2], f"Cycle 3 col1 mismatch"
    
    # Verify cycle 4 output (col1 only)
    assert any(r[0] == 4 and r[2] == expected[2][2] for r in results), \
        f"Cycle 4 col1 mismatch"
    
    dut._log.info("test_systolic_computation PASSED")


@cocotb.test()
async def test_negative_values(dut):
    """Test with negative values."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    A = [[-2, 3], [4, -5]]
    B = [[6, -7], [-8, 9]]
    
    results = await run_systolic_and_capture(dut, A, B)
    expected = compute_expected_outputs(A, B)
    
    dut._log.info(f"A={A}, B={B}")
    dut._log.info(f"Results: {results}")
    dut._log.info(f"Expected: {expected}")
    
    # Verify key outputs match
    c3_results = [r for r in results if r[0] == 3]
    assert len(c3_results) > 0, "No results at cycle 3"
    assert c3_results[0][1] == expected[1][1], f"Cycle 3 col0: expected {expected[1][1]}, got {c3_results[0][1]}"
    
    dut._log.info("test_negative_values PASSED")


@cocotb.test()
async def test_enable_gating(dut):
    """Test that enable gates computation."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    await load_weights(dut, [[10, 10], [10, 10]])
    
    dut.enable.value = 0
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    dut.act_row0_in.value = 5
    dut.act_row1_in.value = 5
    
    await ClockCycles(dut.clk, 10)
    
    col0 = int(dut.psum_col0_out.value)
    assert col0 == 0, f"Should be 0 when disabled, got {col0}"
    
    dut._log.info("test_enable_gating PASSED")


@cocotb.test()
async def test_random_values(dut):
    """Test with random values."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    random.seed(123)
    
    for test_num in range(3):
        await reset_dut(dut)
        
        A = [[random.randint(-20, 20) for _ in range(2)] for _ in range(2)]
        B = [[random.randint(-20, 20) for _ in range(2)] for _ in range(2)]
        
        results = await run_systolic_and_capture(dut, A, B)
        expected = compute_expected_outputs(A, B)
        
        dut._log.info(f"Test {test_num}: A={A}, B={B}")
        
        # Check cycle 3 results (where both columns have values)
        c3_results = [r for r in results if r[0] == 3]
        if len(c3_results) > 0:
            assert c3_results[0][1] == expected[1][1], f"Test {test_num} cycle 3 col0 mismatch"
            assert c3_results[0][2] == expected[1][2], f"Test {test_num} cycle 3 col1 mismatch"
    
    dut._log.info("test_random_values PASSED")


# Pytest wrapper
def test_systolic_array_hidden_runner():
    """Pytest entry point."""
    import os
    from pathlib import Path
    from cocotb_tools.runner import get_runner
    
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    
    sources = [
        proj_path / "mac_pe.sv",
        proj_path / "systolic_array_2x2.sv",
    ]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="systolic_array_2x2",
        always=True,
    )
    runner.test(
        hdl_toplevel="systolic_array_2x2",
        test_module="test_systolic_array_hidden"
    )


if __name__ == "__main__":
    test_systolic_array_hidden_runner()

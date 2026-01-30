"""
Hidden Cocotb testbench for 4x4 Systolic Array
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
    dut.weight_row2_data.value = 0
    dut.weight_row3_data.value = 0
    dut.act_row0_in.value = 0
    dut.act_row1_in.value = 0
    dut.act_row2_in.value = 0
    dut.act_row3_in.value = 0
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    dut.psum_col2_in.value = 0
    dut.psum_col3_in.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def load_weights(dut, weights):
    """Load a 4x4 weight matrix into the array."""
    for col in range(4):
        dut.weight_col_sel.value = col
        dut.weight_row0_data.value = to_unsigned_8bit(weights[0][col])
        dut.weight_row1_data.value = to_unsigned_8bit(weights[1][col])
        dut.weight_row2_data.value = to_unsigned_8bit(weights[2][col])
        dut.weight_row3_data.value = to_unsigned_8bit(weights[3][col])
        dut.weight_load.value = 1
        await RisingEdge(dut.clk)
        dut.weight_load.value = 0
        await RisingEdge(dut.clk)
    
    dut.weight_switch.value = 1
    await RisingEdge(dut.clk)
    dut.weight_switch.value = 0
    await RisingEdge(dut.clk)


async def run_systolic_and_capture(dut, A, B, num_cycles=20):
    """Run systolic computation with diagonal feeding."""
    await load_weights(dut, B)
    
    dut.enable.value = 1
    dut.psum_col0_in.value = 0
    dut.psum_col1_in.value = 0
    dut.psum_col2_in.value = 0
    dut.psum_col3_in.value = 0
    
    results = {}
    
    for cycle in range(num_cycles):
        act0 = to_unsigned_8bit(A[0][cycle]) if cycle < 4 else 0
        act1 = to_unsigned_8bit(A[1][cycle-1]) if 1 <= cycle < 5 else 0
        act2 = to_unsigned_8bit(A[2][cycle-2]) if 2 <= cycle < 6 else 0
        act3 = to_unsigned_8bit(A[3][cycle-3]) if 3 <= cycle < 7 else 0
        
        dut.act_row0_in.value = act0
        dut.act_row1_in.value = act1
        dut.act_row2_in.value = act2
        dut.act_row3_in.value = act3
        
        await RisingEdge(dut.clk)
        
        col0 = signed_32bit(int(dut.psum_col0_out.value))
        col1 = signed_32bit(int(dut.psum_col1_out.value))
        col2 = signed_32bit(int(dut.psum_col2_out.value))
        col3 = signed_32bit(int(dut.psum_col3_out.value))
        
        results[cycle] = (col0, col1, col2, col3)
    
    return results


def compute_matrix_product(A, B):
    """Compute expected matrix product C = A × B."""
    C = [[0]*4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            for k in range(4):
                C[i][j] += A[i][k] * B[k][j]
    return C


@cocotb.test()
async def test_reset_clears_outputs(dut):
    """Test that reset properly clears all outputs to zero."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    weights = [[5]*4 for _ in range(4)]
    await load_weights(dut, weights)
    dut.enable.value = 1
    dut.act_row0_in.value = 10
    await ClockCycles(dut.clk, 10)
    
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    
    assert int(dut.psum_col0_out.value) == 0, "psum_col0_out should be 0 after reset"
    assert int(dut.psum_col1_out.value) == 0, "psum_col1_out should be 0 after reset"
    assert int(dut.psum_col2_out.value) == 0, "psum_col2_out should be 0 after reset"
    assert int(dut.psum_col3_out.value) == 0, "psum_col3_out should be 0 after reset"
    
    dut._log.info("test_reset_clears_outputs PASSED")


@cocotb.test()
async def test_activation_passthrough(dut):
    """Test that activations pass through horizontally."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    await load_weights(dut, [[0]*4 for _ in range(4)])
    
    dut.enable.value = 1
    dut.act_row0_in.value = 42
    dut.act_row1_in.value = 99
    dut.act_row2_in.value = 17
    dut.act_row3_in.value = 123
    await RisingEdge(dut.clk)
    
    dut.act_row0_in.value = 0
    dut.act_row1_in.value = 0
    dut.act_row2_in.value = 0
    dut.act_row3_in.value = 0
    await ClockCycles(dut.clk, 4)
    
    assert int(dut.act_row0_out.value) == 42, f"Expected 42, got {int(dut.act_row0_out.value)}"
    assert int(dut.act_row1_out.value) == 99, f"Expected 99, got {int(dut.act_row1_out.value)}"
    assert int(dut.act_row2_out.value) == 17, f"Expected 17, got {int(dut.act_row2_out.value)}"
    assert int(dut.act_row3_out.value) == 123, f"Expected 123, got {int(dut.act_row3_out.value)}"
    
    dut._log.info("test_activation_passthrough PASSED")


@cocotb.test()
async def test_identity_matrix(dut):
    """Test with identity weight matrix."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    I = [[1 if i==j else 0 for j in range(4)] for i in range(4)]
    A = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    
    results = await run_systolic_and_capture(dut, A, I)
    expected = compute_matrix_product(A, I)
    
    dut._log.info(f"Identity test: Expected C = A = {expected}")
    dut._log.info("test_identity_matrix PASSED")


@cocotb.test()
async def test_enable_gating(dut):
    """Test that enable gates computation."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    await load_weights(dut, [[10]*4 for _ in range(4)])
    
    dut.enable.value = 0
    dut.act_row0_in.value = 5
    dut.act_row1_in.value = 5
    dut.act_row2_in.value = 5
    dut.act_row3_in.value = 5
    
    await ClockCycles(dut.clk, 15)
    
    assert int(dut.psum_col0_out.value) == 0, f"Should be 0 when disabled"
    assert int(dut.psum_col1_out.value) == 0, f"Should be 0 when disabled"
    assert int(dut.psum_col2_out.value) == 0, f"Should be 0 when disabled"
    assert int(dut.psum_col3_out.value) == 0, f"Should be 0 when disabled"
    
    dut._log.info("test_enable_gating PASSED")


@cocotb.test()
async def test_all_zeros(dut):
    """Test with all zero inputs."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    A = [[0]*4 for _ in range(4)]
    B = [[0]*4 for _ in range(4)]
    
    results = await run_systolic_and_capture(dut, A, B)
    
    for cycle, (c0, c1, c2, c3) in results.items():
        assert c0 == 0 and c1 == 0 and c2 == 0 and c3 == 0
    
    dut._log.info("test_all_zeros PASSED")


@cocotb.test()
async def test_negative_values(dut):
    """Test with negative values."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    A = [[-2, 3, -4, 5], [6, -7, 8, -9], [-10, 11, -12, 13], [14, -15, 16, -17]]
    B = [[1, -2, 3, -4], [-5, 6, -7, 8], [9, -10, 11, -12], [-13, 14, -15, 16]]
    
    results = await run_systolic_and_capture(dut, A, B)
    expected = compute_matrix_product(A, B)
    
    dut._log.info(f"Negative values test: Expected C = {expected}")
    dut._log.info("test_negative_values PASSED")


@cocotb.test()
async def test_random_values(dut):
    """Test with random values."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    random.seed(456)
    
    for test_num in range(3):
        await reset_dut(dut)
        
        A = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]
        B = [[random.randint(-50, 50) for _ in range(4)] for _ in range(4)]
        
        results = await run_systolic_and_capture(dut, A, B)
        expected = compute_matrix_product(A, B)
        
        dut._log.info(f"Random test {test_num}: Expected C = {expected}")
    
    dut._log.info("test_random_values PASSED")


@cocotb.test()
async def test_back_to_back_computation(dut):
    """Test back-to-back matrix multiplications."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    A1 = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    B1 = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    
    results1 = await run_systolic_and_capture(dut, A1, B1)
    
    await reset_dut(dut)
    
    A2 = [[2, 4, 6, 8], [1, 3, 5, 7], [8, 6, 4, 2], [7, 5, 3, 1]]
    B2 = [[1, 1, 1, 1], [2, 2, 2, 2], [3, 3, 3, 3], [4, 4, 4, 4]]
    
    results2 = await run_systolic_and_capture(dut, A2, B2)
    expected2 = compute_matrix_product(A2, B2)
    
    dut._log.info(f"Back-to-back test: Expected C2 = {expected2}")
    dut._log.info("test_back_to_back_computation PASSED")


def test_systolic_array_hidden_runner():
    """Pytest entry point."""
    import os
    from pathlib import Path
    from cocotb_tools.runner import get_runner
    
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources_path = proj_path.parent / "sources"
    
    sources = [
        sources_path / "mac_pe.sv",
        sources_path / "systolic_array_4x4.sv",
    ]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="systolic_array_4x4",
        always=True,
    )
    runner.test(
        hdl_toplevel="systolic_array_4x4",
        test_module="test_systolic_array_hidden"
    )


if __name__ == "__main__":
    test_systolic_array_hidden_runner()

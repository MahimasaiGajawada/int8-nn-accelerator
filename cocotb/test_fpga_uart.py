import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

from golden_model import golden_model


CLK_PERIOD_NS = 10
CLKS_PER_BIT = 104
BIT_PERIOD_NS = CLK_PERIOD_NS * CLKS_PER_BIT
HALF_BIT_NS = BIT_PERIOD_NS // 2


async def receive_uart_byte(dut):
    # Wait for UART start bit
    await FallingEdge(dut.tx)

    # Move to center of start bit
    await Timer(HALF_BIT_NS, units="ns")

    # Verify start bit
    assert int(dut.tx.value) == 0, "UART start bit incorrect"

    received = 0

    # Move to the center of each data bit
    for bit in range(8):
        await Timer(BIT_PERIOD_NS, units="ns")

        value = int(dut.tx.value)
        received |= value << bit

    # Move to center of stop bit
    await Timer(BIT_PERIOD_NS, units="ns")

    assert int(dut.tx.value) == 1, "UART stop bit incorrect"

    return received


@cocotb.test()
async def test_fpga_uart(dut):

    # Start clock
    cocotb.start_soon(
        Clock(dut.clk, CLK_PERIOD_NS, units="ns").start()
    )

    # Reset
    dut.rst.value = 1
    await Timer(20, units="ns")
    dut.rst.value = 0

    # Same fixed inputs used by fpga/ice40/top.sv
    input_data = [
        [1, 2],
        [3, 4],
    ]

    weight = [
        [1, 0, 2],
        [0, 1, 3],
    ]

    bias = [0, 0, 0]

    # Generate expected results using the existing Python golden model
    expected_matrix = golden_model(input_data, weight, bias)

    # Flatten:
    # [[1, 2, 8],
    #  [3, 4, 18]]
    #
    # becomes:
    # [1, 2, 8, 3, 4, 18]
    expected = [
        value
        for row in expected_matrix
        for value in row
    ]

    received = []

    # Receive all six UART bytes
    for index, expected_value in enumerate(expected):

        value = await receive_uart_byte(dut)

        received.append(value)

        print(
            f"UART BYTE {index}: "
            f"received={value}, expected={expected_value}"
        )

        assert value == expected_value, (
            f"UART BYTE {index} FAILED: "
            f"expected {expected_value}, got {value}"
        )

    # Verify the complete UART stream
    assert received == expected

    # Wait until the FPGA wrapper reports completion
    while int(dut.done.value) == 0:
        await RisingEdge(dut.clk)

    print("========================================")
    print("FPGA UART VERIFICATION: PASS")
    print(f"Golden model output: {expected_matrix}")
    print(f"UART received:       {received}")
    print("========================================")
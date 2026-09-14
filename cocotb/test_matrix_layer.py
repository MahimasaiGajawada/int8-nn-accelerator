import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from test_vectors import test_vectors

from golden_model import golden_model


@cocotb.test()
async def test_matrix_layer(dut):

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Reset
    dut.rst.value = 1
    dut.start.value = 0

    await Timer(20, unit="ns")

    dut.rst.value = 0

    # --------------------------------------------------
    # Test 1: Basic 2x2 × 2x3 matrix multiplication
    #
    # [1 2]   [1 2 3]   [ 9 12 15]
    # [3 4] x [4 5 6] = [19 26 33]
    # --------------------------------------------------
    await run_test(
        dut,
        name="Basic 2x3 matrix multiplication",
        input_values=[
            1, 2,
            3, 4
        ],
        weight_values=[
            1, 2, 3,
            4, 5, 6
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Test 2: Zero input
    # --------------------------------------------------
    await run_test(
        dut,
        name="Zero input",
        input_values=[
            0, 0,
            0, 0
        ],
        weight_values=[
            1, 2, 3,
            4, 5, 6
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Test 3: Zero weights
    # --------------------------------------------------
    await run_test(
        dut,
        name="Zero weights",
        input_values=[
            5, 10,
            15, 20
        ],
        weight_values=[
            0, 0, 0,
            0, 0, 0
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Test 4: Bias only
    #
    # Matrix multiplication = 0
    # --------------------------------------------------
    await run_test(
        dut,
        name="Bias",
        input_values=[
            0, 0,
            0, 0
        ],
        weight_values=[
            0, 0, 0,
            0, 0, 0
        ],
        bias_values=[3, 5, 7]
    )

    # --------------------------------------------------
    # Test 5: Independent output neurons
    #
    # [1 2]   [1 0 0]   [1 2 0]
    # [3 4] x [0 1 0] = [3 4 0]
    # --------------------------------------------------
    await run_test(
        dut,
        name="Independent output neurons",
        input_values=[
            1, 2,
            3, 4
        ],
        weight_values=[
            1, 0, 0,
            0, 1, 0
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Test 6: Negative inputs + ReLU
    # --------------------------------------------------
    await run_test(
        dut,
        name="Negative inputs + ReLU",
        input_values=[
            -1, -2,
            -3, -4
        ],
        weight_values=[
            1, 1, 1,
            1, 1, 1
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Test 7: Negative weights + ReLU
    # --------------------------------------------------
    await run_test(
        dut,
        name="Negative weights + ReLU",
        input_values=[
            1, 2,
            3, 4
        ],
        weight_values=[
            -1, -1, -1,
            -1, -1, -1
        ],
        bias_values=[0, 0, 0]
    )

    # --------------------------------------------------
    # Randomized testing
    # --------------------------------------------------

    print()
    print("========================================")
    print("Starting 100 randomized tests")
    print("========================================")

    vectors = test_vectors()
    latencies = []

    for vector in vectors:
        name = vector["name"]
        input_values = vector["input_values"]
        weight_values = vector["weight_values"]
        bias_values = vector["bias_values"]

        latency = await run_test(
            dut,
            name,
            input_values=input_values,
            weight_values=weight_values,
            bias_values=bias_values
        )

        latencies.append(latency)
        print(f"Latency: {latency} cycles")

    total_cycles = sum(latencies)
    average_latency = total_cycles / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)

    print(f"Tests:             {len(latencies)}")
    print(f"Total cycles:      {total_cycles}")
    print(f"Average latency:   {average_latency:.2f} cycles")
    print(f"Minimum latency:   {min_latency} cycles")
    print(f"Maximum latency:   {max_latency} cycles")

    print()
    print("========================================")
    print("Matrix Layer Verification: PASS")
    print("107/107 tests passed")
    print("========================================")


async def run_test(
    dut,
    name,
    input_values,
    weight_values,
    bias_values
):

    # --------------------------------------------------
    # Fixed DUT configuration
    # --------------------------------------------------

    INPUT_ROWS = 2
    INPUT_COLS = 2
    WEIGHT_COLS = 3
    NUM_OUTPUTS = INPUT_ROWS * WEIGHT_COLS

    # --------------------------------------------------
    # Check test dimensions
    # --------------------------------------------------

    assert len(input_values) == INPUT_ROWS * INPUT_COLS
    assert len(weight_values) == INPUT_COLS * WEIGHT_COLS
    assert len(bias_values) == WEIGHT_COLS

    # --------------------------------------------------
    # Determine signal widths
    # --------------------------------------------------

    input_signal_width = len(dut.input_data)
    weight_signal_width = len(dut.weight)
    bias_signal_width = len(dut.bias)
    output_signal_width = len(dut.output_data)

    input_width = input_signal_width // len(input_values)
    weight_width = weight_signal_width // len(weight_values)
    bias_width = bias_signal_width // len(bias_values)
    output_width = output_signal_width // NUM_OUTPUTS

    # --------------------------------------------------
    # Pack input values
    # --------------------------------------------------

    input_bits = "".join(
        f"{value & ((1 << input_width) - 1):0{input_width}b}"
        for value in input_values
    )

    dut.input_data.value = int(input_bits, 2)

    # --------------------------------------------------
    # Pack weight values
    # --------------------------------------------------

    weight_bits = "".join(
        f"{value & ((1 << weight_width) - 1):0{weight_width}b}"
        for value in weight_values
    )

    dut.weight.value = int(weight_bits, 2)

    # --------------------------------------------------
    # Pack bias values
    # --------------------------------------------------

    bias_bits = "".join(
        f"{value & ((1 << bias_width) - 1):0{bias_width}b}"
        for value in bias_values
    )

    dut.bias.value = int(bias_bits, 2)

    # --------------------------------------------------
    # Build matrices for golden model
    # --------------------------------------------------

    input_matrix = [
        input_values[0:2],
        input_values[2:4]
    ]

    weight_matrix = [
        weight_values[0:3],
        weight_values[3:6]
    ]

    expected_matrix = golden_model(
        input_matrix,
        weight_matrix,
        bias_values
    )

    expected = [
        value
        for row in expected_matrix
        for value in row
    ]

    # --------------------------------------------------
    # Start DUT
    # --------------------------------------------------

    latency_count = 0
    dut.start.value = 1

    await RisingEdge(dut.clk)

    dut.start.value = 0
    latency_count += 1

    # --------------------------------------------------
    # Wait for completion
    # --------------------------------------------------

    while not dut.done.value:
        await RisingEdge(dut.clk)
        latency_count += 1


    # --------------------------------------------------
    # Extract outputs
    # --------------------------------------------------

    actual = int(dut.output_data.value)

    outputs = []

    for i in range(NUM_OUTPUTS):

        output = (
            actual
            >> ((NUM_OUTPUTS - 1 - i) * output_width)
        ) & ((1 << output_width) - 1)

        msb = 1 << (output_width - 1)

        if output & msb:
            output = output - (1 << output_width)

        outputs.append(output)

    # --------------------------------------------------
    # Compare against golden model
    # --------------------------------------------------

    for i in range(NUM_OUTPUTS):

        assert outputs[i] == expected[i], (
            f"{name}: output {i} mismatch — "
            f"expected {expected[i]}, got {outputs[i]}"
        )

    print(
        f"PASS: {name} "
        f"-> expected={expected}, actual={outputs}"
    )

    return latency_count
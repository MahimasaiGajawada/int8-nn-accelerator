# Parameterizable INT8 Neural Network Accelerator

A parameterizable SystemVerilog neural-network inference accelerator implementing:

$$
Y = ReLU(XW + B)
$$

The design supports both sequential and parallel matrix-multiply architectures, with a Python golden model and cocotb/Verilator verification flow. The project also includes Yosys synthesis, iCE40 FPGA implementation, an AMD Vivado implementation flow, and a UART-based FPGA demonstration wrapper.

## Architecture

The accelerator computes a fully connected neural-network layer using signed INT8 inputs and weights.

The datapath consists of:

- INT8 signed multipliers
- Multiply-accumulate operations
- Configurable matrix dimensions
- Bias addition
- ReLU activation
- Sequential and parallel execution architectures

## Results at a Glance

| Metric | Result |
|---|---:|
| Verification | 107/107 tests passed |
| Sequential synthesis | 1,426 cells |
| Parallel synthesis | 1,352 cells |
| iCE40 utilization | 578 / 5,280 logic cells (10%) |
| iCE40 Fmax | 29.05 MHz |
| iCE40 timing target | 12 MHz — PASS |
| Vivado LUT utilization | 80 / 20,800 (0.38%) |
| Vivado register utilization | 119 / 41,600 (0.29%) |

## Execution Architectures

### Sequential

The sequential architecture reuses a single MAC datapath across matrix elements. This reduces hardware resources at the cost of increased latency.

### Parallel

The parallel architecture instantiates multiple MAC datapaths and processes multiple operations concurrently. With `PARALLEL_MACS=2`, two MAC operations can execute in parallel, reducing computation latency at the cost of additional hardware resources.

## Example

For:

$$
X =
\begin{bmatrix}
1 & 2 \\
3 & 4
\end{bmatrix}
$$

$$
W =
\begin{bmatrix}
1 & 0 & 2 \\
0 & 1 & 3
\end{bmatrix}
$$

and:

$$
B =
\begin{bmatrix}
0 & 0 & 0
\end{bmatrix}
$$

the accelerator produces:

$$
Y =
\begin{bmatrix}
1 & 2 & 8 \\
3 & 4 & 18
\end{bmatrix}
$$

## Verification

The accelerator was verified against an independent Python golden model that computes the expected matrix multiplication, bias addition, and ReLU activation.

Verification was performed using cocotb with Verilator.

### Test Coverage

- 7 directed test cases
- 100 randomized test cases
- 107/107 tests passed for the parallel architecture
- Sequential and parallel implementations were compared against the same golden model
- FPGA UART output was verified with an end-to-end cocotb testbench

The verification flow checks both functional correctness and the serialized UART output produced by the FPGA wrapper.

## How to Run

The project provides Makefile targets for simulation, synthesis, and FPGA implementation.

### Simulation

Run the sequential architecture:

    make sequential

Run the parallel architecture:

    make parallel

### Synthesis

Synthesize both architectures with Yosys:

    make synth

Run the individual synthesis flows:

    make synth-sequential
    make synth-parallel

### FPGA Demonstration

Run the FPGA wrapper UART simulation:

    make fpga-sim

Run the iCE40 synthesis, place-and-route, and bitstream generation flow:

    make fpga

Clean generated simulation and build artifacts:

    make clean

## Synthesis

The design was synthesized using Yosys and implemented through both an open-source iCE40 flow and AMD Vivado.

### Yosys Synthesis

| Architecture | Cells |
|---|---:|
| Sequential | 1,426 |
|  Parallel | 1,352 |

The parallel implementation uses two `dot_product` datapaths (`PARALLEL_MACS=2`) to increase computational parallelism.

## FPGA Implementation

### iCE40

The design was synthesized and place-and-routed for an iCE40 UP5K target using Yosys, nextpnr-ice40, and icepack.

| Resource | Usage |
|---|---:|
| Logic Cells | 578 / 5,280 (10%) |
| SB_IO | 4 / 96 (4%) |
| Global Buffers | 4 / 8 (50%) |
| BRAM | 0 / 30 (0%) |
| DSP | 0 / 8 (0%) |
| Fmax | 29.05 MHz |
| Timing Target | 12 MHz — PASS |

The critical path was approximately 34.4 ns, including logic and routing delay.

### AMD Vivado

The design was also synthesized and implemented through Vivado targeting an AMD 7-Series device.

| Resource | Usage |
|---|---:|
| LUTs | 80 / 20,800 (0.38%) |
| Registers | 119 / 41,600 (0.29%) |
| Slices | 39 / 8,150 (0.48%) |
| BRAM | 0 / 50 (0%) |
| DSP | 0 / 90 (0%) |

Implementation completed successfully with the design routed at a 12 MHz clock constraint.

No physical AMD FPGA board was used for this flow, so hardware programming and board-level validation are not claimed.

## UART FPGA Demonstration

An FPGA wrapper connects the neural-network accelerator to a UART transmitter. After the accelerator completes, the wrapper serializes the six 8-bit output values over UART.

For the example input:

    X = [[1, 2],
         [3, 4]]

    W = [[1, 0, 2],
         [0, 1, 3]]

    B = [0, 0, 0]

    Y = [[1, 2, 8],
         [3, 4, 18]]

The UART wrapper transmits the output values in row-major order:

    1, 2, 8, 3, 4, 18

## Tools

- SystemVerilog
- Verilator
- cocotb
- Python
- Yosys
- nextpnr-ice40
- icepack
- AMD Vivado
- Make
- Git / GitHub

## Project Structure

```text
├── rtl/                 # Synthesizable SystemVerilog RTL
├── tb/                  # SystemVerilog module testbenches
├── cocotb/              # Python/cocotb verification
├── synthesis/           # Yosys synthesis sources
├── fpga/
│   ├── ice40/           # iCE40 FPGA flow and UART wrapper
│   └── vivado/          # AMD Vivado implementation flow
├── reports/
│   ├── yosys/           # Yosys synthesis reports
│   ├── ice40/           # iCE40 implementation report
│   └── vivado/          # Vivado implementation reports
├── golden_model.py      # Python reference model
├── test_vectors.py      # Test vector generation
├── Makefile             # Simulation, synthesis, and FPGA targets
└── README.md

## Design Tradeoffs

The sequential architecture prioritizes hardware reuse and lower resource usage by reusing the same computational datapath across operations.

The parallel architecture increases hardware resources by instantiating multiple dot-product datapaths, allowing multiple computations to execute concurrently.

This provides a practical hardware tradeoff between:

- **Resource utilization**
- **Computation latency**
- **Parallelism**
- **Design complexity**

The accelerator is parameterized so matrix dimensions and parallelism can be adjusted without rewriting the core architecture.

## Future Work

Potential extensions include:

- Validate the design on physical iCE40 and AMD FPGA hardware.
- Explore pipelining and additional parallelism to improve throughput.
- Extend the accelerator toward larger neural-network layers and memory-based data movement.

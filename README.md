# UART RTL & UVM Verification Project

## Overview
This project contains a robust **Universal Asynchronous Receiver-Transmitter (UART)** RTL design and a complete **UVM (Universal Verification Methodology)** verification environment. The goal is to verify the UART's functionality, including data transmission, reception, baud rate generation, parity checking, and error handling, under various constrained-random scenarios.

## Features

### RTL Design (`design.sv`)
*   **Standard UART Protocol**: Supports Start bit, 8 Data bits, Parity bit (Optional: None/Odd/Even), and Stop bit.
*   **16x Oversampling**: Robust RX synchronization and noise filtering using 16x oversampling architecture.
*   **Dynamic Configuration**: Configurable Baud Rate Divisor and Parity settings via input ports.
*   **Internal Loopback**: Supports internal loopback mode for self-test.
*   **Status Indicators**: TX Busy, RX Data Valid, and RX Error (Parity/Frame) flags.

### UVM Verification Environment
*   **Modular Architecture**: Follows standard UVM topology (Agent, Driver, Monitor, Scoreboard, Environment).
*   **Virtual Interface**: Connects the class-based UVM environment to the signal-based RTL.
*   **Constrained Random Stimulus**:
    *   Randomized data payloads.
    *   Randomized configuration (Baud Rate, Parity).
    *   Randomized error injection (Parity Error, Frame Error).
    *   Timing jitter injection for robust receiver testing.
*   **Self-Checking Scoreboard**: Verified data integrity for both TX and RX paths, including protocol error detection.
*   **Functional Coverage**: Covergroups for Data, Parity settings, Baud rates, and Error types.

## Directory Structure
```
UART-uvm/
├── design.sv          # UART RTL Implementation
├── uart_if.sv         # SystemVerilog Interface
├── uart_pkg.sv        # UVM Package (Includes all UVM components)
├── uart_trans.sv      # Sequence Item (Transaction)
├── uart_config.sv     # Configuration Object
├── uart_driver.sv     # Driver (Drives Host & Serial interfaces)
├── uart_monitor.sv    # Monitor (Observes Host & Serial interfaces)
├── uart_sequencer.sv  # Sequencer
├── uart_agent.sv      # Agent (Groups Driver, Monitor, Sequencer)
├── uart_scoreboard.sv # Scoreboard (Data integrity & Error checking)
├── uart_coverage.sv   # Functional Coverage
├── uart_env.sv        # Environment (Connects Agent, Scoreboard, Coverage)
├── uart_seq_lib.sv    # Sequence Library (Base, TX, Random, Error, Jitter sequences)
├── uart_test_lib.sv   # Test Library (Base, TX, Random, Error, Back-to-Back tests)
├── top.sv             # Top-level Testbench connecting DUT and UVM Test
└── README.md          # Project Documentation
```

## Verification Workflow
The verification process follows a standard UVM flow:

1.  **Stimulus Generation**: Sequences (`uart_seq_lib.sv`) allow creating random or directed transactions (`uart_trans`).
2.  **Driver**: The `uart_driver` translates these transactions into pin-level activity on the `uart_if`.
    *   **TX Path**: Drives Host Interface signals (`tx_data`, `tx_en`) to initiate DUT transmission.
    *   **RX Path**: Drives the Serial `rx` line with start/data/parity/stop bits to simulate an external UART transmitter. Includes error injection logic.
3.  **Monitor**: The `uart_monitor` observes the interface:
    *   Captures transactions from the Host Interface (Golden Input for TX).
    *   Captures serial bitstreams from the Serial Interface (DUT Output).
    *   Reconstructs the frames and sends them to the Scoreboard.
4.  **Scoreboard**: Compares the expected data vs. actual data. It also validates that Protocol Errors (Parity/Frame) are correctly flagged by the DUT.
5.  **Coverage**: Collects statistics on the scenarios exercised (Data patterns, Config combinations, Errors).

## How to Run
This project requires a SystemVerilog simulator that supports UVM (e.g., VCS, Riviera-PRO, Questa, Xcelium, or Verilator with UVM support).

### Generic Run Command
```bash
# Compile and Run
<simulator_command> -sverilog +incdir+<uvm_home> top.sv +UVM_TESTNAME=<test_name>
```

### Available Tests
Pass the test name via `+UVM_TESTNAME` argument:

| Test Name | Description |
| :--- | :--- |
| `uart_tx_test` | Basic transmission test. |
| `uart_rand_test` | Randomized data and configuration test. |
| `uart_error_test` | Injects Parity and Frame errors to verify DUT error detection. |
| `uart_b2b_test` | Back-to-back transmission stress test. |

## Implementation Details
*   **Design**: The RTL uses a Finite State Machine (FSM) for both TX and RX. The RX FSM uses a 16x tick counter to sample in the middle of the bit period for reliability.
*   **Verification**: The UVM environment uses a single agent to handle both Host-side and Serial-side interfaces, simplifying the coordination. The `uart_trans` item contains a `path` field to distinguish between Host->Serial (TX) and Serial->Host (RX) transactions.
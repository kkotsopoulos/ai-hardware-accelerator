# Custom AI Hardware Accelerator in Verilog 🚀

A digital system implementation of a simplified Neural Network (NN) accelerator written in Verilog. This project focuses on hardware-software co-design principles, featuring the design, simulation, and verification of fundamental digital components including a 32-bit ALU, a Multi-port Register File, a MAC unit, and a Moore FSM-controlled datapath.

##  System Architecture

The accelerator is organized around a finite state machine (Moore FSM) that sequentially controls the data flow and execution of the processing stages. 

### Key Components:
* **Neural Network FSM (`nn.v`):** The core control unit implementing states for Loading, Pre-processing, Input Layer MAC operations, Output Layer MAC operations, and Post-processing.
* **Multiply-Accumulate Unit (`mac_unit.v`):** The foundational arithmetic block for neural network tensor calculations, utilizing two ALUs for sequential multiplication and addition.
* **32-bit ALU (`alu.v`):** Supports arithmetic (signed addition/subtraction/multiplication), logical, and arithmetic/logical shift operations with overflow and zero flag detection.
* **Register File (`regfile.v`):** A 16x32-bit memory block supporting 4 simultaneous read ports and 2 write ports for efficient weight and bias storage.
* **ROM Module (`rom.v`):** Read-only memory storing the pre-trained neural network weights and biases.

##  Features & Hardware Considerations

* **Signed Arithmetic & Saturation:** Full support for 32-bit signed arithmetic. In the event of an overflow during any FSM stage, the system safely saturates the output (`0xFFFFFFFF`) and flags the exact stage where the overflow occurred.
* **Resource Optimization:** Reuses ALU and MAC instances across different FSM stages to save hardware area.
* **Testbenches & Verification:** Includes comprehensive testbenches (e.g., `tb_nn.v`, `calc_tb.v`) validating edge cases, overflow behaviors, and timing constraints.

##  Tech Stack & Tools

* **Hardware Description Language:** Verilog (IEEE 1364)
* **Simulation & Verification:** QuestaSim / Icarus Verilog
* **Waveform Viewer:** EPWave
* **Development Environment:** EDA Playground

##  Repository Structure

* `nn.v`, `mac_unit.v`, `alu.v`, `regfile.v` - Core accelerator modules.
* `calc.v`, `calc_enc.v` - Accumulator-based calculator modules (sub-components).
* `tb_nn.v`, `calc_tb.v` - Verification testbenches.
* `Kotsopoulos_Konstantinos_10969_HW1.pdf` - Comprehensive project documentation, architectural block diagrams, and waveform analysis.

##  How to Run (Simulation)

1. Load the core `.v` files and the testbench (`tb_nn.v`) into your preferred Verilog simulator (e.g., QuestaSim or ModelSim).
2. Ensure the `rom_bytes.data` is in the root simulation directory to load the NN weights.
3. Run the simulation. The testbench will execute 100 iterations of randomized signed inputs to verify the datapath against a software reference model.

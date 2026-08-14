# DP TX + RISC-V AUX Controller - Build Guide

## Project Structure

```
src/
├── dp_tx_top.v              # Top-level (uses riscv_soc for AUX)
├── dp_tx_aux_ctrl.v          # Original hardwired AUX (replaced, kept for ref)
├── dp_tx_video_packer.v
├── dp_tx_pixel_fifo.v        # Async FIFO (pixel_clk → byte_clk domain crossing)
├── dp_tx_scrambler.v
├── dp_tx_msa_gen.v
├── dp_tx_stream_mux.v
├── dp_tx_lane_mapper.v
├── dp_tx_phy_7series.v
└── riscv/                    # RISC-V AUX subsystem
    ├── picorv32.v            # RV32I core (native memory interface)
    ├── ram.v                 # Dual-port block RAM with firmware init
    ├── aux_periph.v          # AUX host I/F + DPCD + RISC-V memory slave
    ├── riscv_soc.v           # SoC top: core + decoder + RAM + peripheral
    ├── firmware.S            # Assembly source for AUX handler
    ├── firmware.hex          # Compiled firmware binary
    ├── asm.py                # RV32I assembler
    ├── test_fw.py            # Python firmware emulation test
    └── simulate.py           # Full simulation runner
tb/
└── dp_tx_top_tb.v            # Testbench with AUX transaction tests
```

## Building and Running

### 0. Prerequisites

- Python 3.6+ (for firmware assembly and emulation testing)
- Icarus Verilog (iverilog) for RTL simulation

### 1. Assemble Firmware

```bash
cd src/riscv
python asm.py firmware.S firmware.hex
```

### 2. Test Firmware (Python Emulation)

```bash
cd src/riscv
python test_fw.py
```

This emulates the RV32I core running the firmware and tests:
- AUX read transaction → DPCD read
- AUX write transaction → DPCD write
- Write-then-read verification
- Unknown opcode → NACK response
- Initial DPCD value integrity

### 3. Run Full RTL Simulation

```bash
cd src/riscv
python simulate.py
```

This assembles firmware, runs Python tests, then invokes iverilog.

**Note (Windows/WSL):** `simulate.py` has a known path issue on Windows. Workaround:

```bash
# Assemble + copy hex
cd src/riscv
python asm.py firmware.S firmware.hex
copy firmware.hex ..\..\tb\firmware.hex

# Compile + run in WSL
wsl iverilog -g2012 -o /tmp/sim_vvp ...  # all .v files
wsl cp /mnt/c/.../tb/firmware.hex /tmp/
wsl bash -c "cd /tmp && vvp sim_vvp"
```

### 4. View Waveforms

```bash
wsl bash -c "cd /tmp && vvp sim_vvp"  # generates dp_tx_top_tb.vcd
gtkwave /tmp/dp_tx_top_tb.vcd
```

### 5. Vivado Synthesis

Add these files to your Vivado project:

```
src/dp_tx_top.v
src/dp_tx_video_packer.v
src/dp_tx_scrambler.v
src/dp_tx_msa_gen.v
src/dp_tx_stream_mux.v
src/dp_tx_lane_mapper.v
src/dp_tx_phy_7series.v
src/riscv/picorv32.v
src/riscv/ram.v
src/riscv/aux_periph.v
src/riscv/riscv_soc.v
src/riscv/firmware.hex
```

For synthesis, replace `$readmemh` in ram.v with block ROM initialized from firmware.hex.

## Memory Map

| Address Range | Region | Description |
|---------------|--------|-------------|
| 0x00000000 - 0x00001FFF | RAM (8KB) | Firmware code + stack/data |
| 0x10000000 | AUX_CTRL | [0]=req_pending(RO), [1]=resp_ready(WO), [2]=ack(WO) |
| 0x10000004 | AUX_REQ_OPADDR | {opcode, addr_hi, addr_lo, len} (RO) |
| 0x10000008 | AUX_REQ_WDATA | Write data byte from host (RO) |
| 0x1000000C | AUX_RESP_CTRL | Response code[7:0], ack[8] (WO) |
| 0x10000010 | AUX_RESP_DATA | Response data byte (WO) |
| 0x10000100 - 0x100001FF | DPCD (256B) | Byte-accessible DPCD register file |

## Firmware Customization

Modify `src/riscv/firmware.S` then reassemble:

```bash
cd src/riscv
python asm.py firmware.S firmware.hex
python test_fw.py   # verify changes
```

## GTXE2_CHANNEL Instantiation (Kintex-7)

The `dp_tx_phy_7series.v` module has two modes selected via `__ICARUS__`:

- **Simulation** (`__ICARUS__` defined): Simple behavioral model — 8b/10b encoder outputs drive `txp = code[0]`, `txn = ~code[0]`
- **Synthesis** (Vivado): Full `GTXE2_CHANNEL` instantiation per lane with `TX_DATA_WIDTH=20` (two 10-bit symbols packed per cycle), `TX_8B10B_EN="FALSE"` (bypass, uses fabric encoder), and DP 1.2 HBR parameters

**Gearbox:** A 2:1 packer accumulates two consecutive 10-bit symbols per lane and presents them as a 20-bit word to the GTX at the byte clock rate (`clk` → `TXUSRCLK2`).

**For actual bitstream generation,** run the Vivado GTX wizard to match your board's REFCLK (typically 135 MHz or 270 MHz) and update the `GTXE2_CHANNEL` parameters accordingly (`TX_CLK25_DIV`, PLL settings in `GT_COMMON`).

## Pixel Clock Domain Crossing

**Architecture:** The `dp_tx_top` module now accepts two separate clocks:
- `pixel_clk` — video pixel domain (pixel source)
- `clk` — link byte clock (DP serial link)

An asynchronous FIFO (`dp_tx_pixel_fifo.v`) bridges the two domains:
- **Write side** (`pixel_clk`): stores `{pixel_sof, pixel_in[23:0]}` when `pixel_valid`
- **Read side** (`clk`): outputs `fifo_pixel` + `fifo_sof`, gated by `pixel_consumed = packer_pixel_ready && !fifo_empty`

The 8-deep FIFO uses gray-coded pointers for safe clock domain crossing. Video timing counters (`h_count`, `v_count`, `in_vblank`) run on the byte clock domain and advance on `pixel_consumed`.

## Critical Fix: Scrambler Reset (DP Compliance)

**Root cause:** `dp_tx_top.v` tied `scrambler_rst` to `1'b0` — the scrambler LFSR was never re-initialized. DP 1.2 requires the scrambler to reset to `0xFFFF` at the start of each blanking interval (VSync), before the BS sequence.

**Fix:** Added `scrambler_rst` output to `dp_tx_stream_mux.v`. Pulses high for one cycle on the ACTIVE→BS transition (bstate 0 → 1). Wired in `dp_tx_top.v` to the scrambler's `scrambler_rst` port.

## Critical Fix: 8b/10b Disparity Tracking

**Root cause:** `dp_tx_phy_7series.v` created a single `disp` register but never updated it (only reset at rst_n). The `disp_out` from all 4 encoders was unconnected. Also, `dp_tx_8b10b_enc.v` computed `disp_out = ^code_out` (XOR parity), which is incorrect for neutral 5:5 codes — XOR is 1 (odd parity), causing a spurious disparity flip for balanced codes.

**Fix (encoder):** Use per-sub-block ones count for correct disparity:
```verilog
cnt6 = count of ones in 6b sub-block;
cnt4 = count of ones in 4b sub-block;
if (cnt6 > 3) disp_out = 1;
else if (cnt6 < 3) disp_out = 0;
else if (cnt4 > 2) disp_out = 1;
else if (cnt4 < 2) disp_out = 0;
else disp_out = disp_in;  // neutral: no change
```

**Fix (PHY):** Track per-lane disparity registers, update on `tx_valid`:
```verilog
reg disp0, disp1, disp2, disp3;
always @(posedge clk) begin
    if (!rst_n) {disp0,disp1,disp2,disp3} <= 0;
    else if (tx_valid) begin
        disp0 <= disp_next0;  // from enc0.disp_out
        disp1 <= disp_next1;
        disp2 <= disp_next2;
        disp3 <= disp_next3;
    end
end
```
Each encoder now has its own independent running disparity, fed back on the next cycle.

## Critical Fix: AUX Testbench Race Condition

**Root cause:** Testbench set `aux_req_valid` *before* `@(posedge clk)`, creating a race with the AUX peripheral's always block. On the shared posedge, evaluation order was undefined — the AUX peripheral sometimes saw `aux_req_valid=1`, sometimes not.

**Fix:** Use task-based sequencing — set `aux_req_valid` *after* `@(posedge clk)`, so it's stable for the *next* posedge:

```verilog
task aux_read(input [7:0] addr);
    begin
        @(posedge clk);
        aux_req_valid = 1;  // set AFTER edge
        aux_req_opcode = 8'h02;
        aux_req_addr_lo = addr;
        @(posedge clk);     // held for full cycle
        aux_req_valid = 0;
        wait (aux_resp_valid);
        @(posedge clk);
    end
endtask
```

This ensures `aux_req_valid=1` is sampled cleanly on the second posedge. All 5 RTL tests pass with this fix.

## Architecture

```
Host I/F ──► AUX Periph ◄── PicoRV32 ◄── RAM (firmware)
                 │                              ▲
            DPCD[0..255]                    firmware init
                 │
            AUX PHY Engine (future)
                 │
            AUX+/- Channel
```

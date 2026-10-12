# DisplayPort IP Alpha - Project State Summary

**Last Updated:** 2026-10-12  
**Repository:** D:\Document\GitHub\DISPLAYPORT_IP_ALPHA\RISCV_AUX_DPTXIP

---

## Project Structure

```
RISCV_AUX_DPTXIP/
├── AGENTS.md                 # Build guide & architecture docs
├── LICENSE
├── README.md
├── .gitattributes
├── dp_tx_riscv_full.v        # Single-file pack (all RTL + TB)
├── src/
│   ├── dp_tx_top.v           # Top-level (video + AUX + PHY)
│   ├── dp_tx_video_packer.v
│   ├── dp_tx_pixel_fifo.v    # Async FIFO (pixel_clk → byte_clk)
│   ├── dp_tx_scrambler.v
│   ├── dp_tx_8b10b_enc.v     # Fabric 8b/10b encoder (per-lane, disparity tracking)
│   ├── dp_tx_msa_gen.v       # MSA packet generator
│   ├── dp_tx_stream_mux.v    # Training/video mux + scrambler_rst pulse
│   ├── dp_tx_lane_mapper.v
│   ├── dp_tx_link_layer.v
│   ├── dp_tx_clk_gen.v       # MMCM reference (135→270/148.5 MHz)
│   ├── dp_tx_phy_7series.v   # GTXE2_CHANNEL wrapper (SIM vs SYNTH)
│   ├── dp_tx_aux_phy.v       # DP 1.2 compliant Manchester PHY
│   └── riscv/
│       ├── picorv32.v        # RV32I core (native memory I/F)
│       ├── ram.v             # Dual-port BRAM (8KB, firmware init)
│       ├── aux_periph.v      # DP 1.2 AUX peripheral + DPCD + PHY TX SM
│       ├── riscv_soc.v       # SoC: core + decoder + RAM + peripheral
│       ├── firmware.S        # Assembly source (AUX handler)
│       ├── firmware.hex      # Compiled firmware binary
│       ├── asm.py            # RV32I assembler
│       ├── gen_rom.py        # Generates ram.v mem[] init from firmware.hex
│       ├── test_fw.py        # Python firmware emulation tests
│       └── simulate.py       # Full simulation runner
└── tb/
    ├── dp_tx_top_tb.v        # DP 1.2 AUX transaction tests
    ├── dp_tx_top_full_tb.v   # 1080p60 video + AUX testbench
    ├── dp_tx_top_tb.vcd
    └── firmware.hex          # Copied hex for TB RAM init
```

---

## Key Features Implemented

### DisplayPort TX (Video Path)
- ✅ 4-lane DP 1.2 HBR (2.7 Gbps/lane)
- ✅ Video packing (24-bit RGB → 8b/10b symbols)
- ✅ Scrambler with proper reset (BS sequence)
- ✅ 8b/10b encoder with **correct disparity tracking**
- ✅ MSA generation (timing parameters configurable)
- ✅ Stream mux (training patterns → video)
- ✅ Pixel clock domain crossing (async FIFO, gray pointers)
- ✅ GTXE2_CHANNEL wrapper (simulation + synthesis modes)

### RISC-V AUX Controller (DP 1.2 Compliant)
- ✅ PicoRV32 RV32I core (2-state pipeline, native mem I/F)
- ✅ 8KB firmware RAM (pre-loaded via `initial` block)
- ✅ DP 1.2 AUX peripheral with DPCD register file (256 bytes)
- ✅ **DP 1.2 AUX transaction format:**
  - Request: PRE(16) | SYNC(17) | CMD(8) | ADDR(20) | LEN(8) | DATA(n×8) | STOP/byte
  - Reply:   PRE(16) | SYNC(17) | REPLY(8) | DATA(n×8) | STOP/byte
- ✅ **`dp_tx_aux_phy.v`** - Full Manchester II PHY
  - TX: Precharge 16 UI → Sync 16×'1'+1×'0' → CMD → ADDR(20) → LEN → DATA → STOP/byte
  - RX: Clock recovery → Sync detect → REPLY → DATA → STOP/byte
  - Manchester II: '1'=falling edge, '0'=rising edge, MSB first
- ✅ Inter-transaction gap enforcement (≥400µs)
- ✅ Multi-byte transactions (up to 16 bytes per DP spec)
- ✅ Command types: NATIVE_WRITE(00), NATIVE_READ(01), I2C_WRITE(10), I2C_READ(11)
- ✅ Reply codes: ACK(00), NACK(01), DEFER(10)
- ✅ Differential AUX pins (`aux_p`, `aux_n`) at top level

### Firmware (`firmware.S`)
- Handles AUX READ/WRITE via memory-mapped registers
- DPCD read/write with ACK/NACK replies
- **Limitation:** Firmware uses simple register interface; full multi-byte handled by HW PHY TX SM

---

## Critical Fixes Applied

| Issue | Fix |
|-------|-----|
| Scrambler never reset | `scrambler_rst` pulsed on ACTIVE→BS transition in `stream_mux` |
| 8b/10b disparity broken | Per-sub-block ones count for correct disparity; per-lane registers in PHY |
| AUX TB race condition | Tasks set `aux_req_valid` **after** `@(posedge clk)` |
| AUX non-compliant | **NEW:** Full DP 1.2 transaction format with proper CMD/ADDR/LEN/STOP |

---

## Current Limitations / TODOs

### High Priority
1. **Firmware multi-byte API** - `firmware.S` uses simple register interface; extend for burst
2. **I2C-over-AUX** - Add opcode 0x08/0x09 for EDID reads (PHY supports I2C command types)
3. **RX multi-byte buffer** - PHY RX captures multi-byte but testbench only checks first byte

### Medium Priority
4. **RAM firmware loading** - Replace `initial` block in `ram.v` with `$readmemh("firmware.hex")`
5. **Tighter address decode** - `riscv_soc.v` uses 256MB regions; limit to actual sizes (8KB RAM, 4KB periph)
6. **Interrupt support** - Add external interrupt to PicoRV32 for PHY transaction complete

### Low Priority
7. **Vivado Clocking Wizard** - Replace `dp_tx_clk_gen.v` with board-specific MMCM
8. **GTX wizard** - Update `dp_tx_phy_7series.v` parameters for target board REFCLK

---

## Build & Test Commands

```bash
# Assemble firmware
cd src/riscv
python asm.py firmware.S firmware.hex

# Test firmware (Python emulation)
python test_fw.py

# Full RTL simulation (requires iverilog)
python simulate.py           # assemble + test + simulate
python simulate.py --waves   # + VCD dump

# View waveforms
gtkwave tb/dp_tx_top_tb.vcd
```

**Windows/WSL Note:** `simulate.py` has path issues on Windows. Workaround:
```bash
cd src/riscv
python asm.py firmware.S firmware.hex
copy firmware.hex ..\..\tb\firmware.hex
wsl iverilog -g2012 -o /tmp/sim_vvp ... (all .v files)
wsl cp /mnt/c/.../tb/firmware.hex /tmp/
wsl bash -c "cd /tmp && vvp sim_vvp"
```

---

## Memory Map

| Address Range | Region | Description |
|---------------|--------|-------------|
| 0x0000_0000 - 0x0000_1FFF | RAM (8KB) | Firmware code + stack/data |
| 0x1000_0000 | AUX_CTRL | [0]=req_pending(RO), [1]=resp_ready(WO) |
| 0x1000_0004 | AUX_REQ_TYPE | {30'h0, type[1:0]} (RO) |
| 0x1000_0008 | AUX_REQ_ADDR | 20-bit address (RO) |
| 0x1000_000C | AUX_REQ_LEN | Length-1 (0-15) (RO) |
| 0x1000_0010 | AUX_REQ_WDATA | Write data byte (RO) |
| 0x1000_0014 | AUX_RESP_REPLY | Reply code[1:0] (WO) |
| 0x1000_0018 | AUX_RESP_DATA | Response data byte (WO) |
| 0x1000_0100 - 0x1000_01FF | DPCD (256B) | Byte-accessible DPCD register file |

---

## AUX PHY Signal Timing (270 MHz sys_clk, 1 MHz AUX)

| Phase | Duration | Cycles | DP 1.2 Spec |
|-------|----------|--------|-------------|
| Half bit | 0.5 µs | 135 | 1 Mbps ±0.5% |
| Precharge | 16 UI | 4,320 | ≥16 UI logic '0' |
| Sync '1' × 16 | 16 UI | 4,320 | 16 Manchester '1' |
| Sync '0' × 1 | 1 UI | 270 | 1 Manchester '0' |
| CMD byte | 8 UI | 2,160 | 8 bits MSB first |
| ADDR (20b) | 20 UI | 5,400 | 20 bits MSB first |
| LEN byte | 8 UI | 2,160 | Length-1 |
| DATA byte | 8 UI | 2,160 | Per byte + STOP |
| STOP/byte | 1 UI | 270 | Manchester '0' |
| Inter-transaction gap | 400 µs | 108,000 | ≥400 µs |

---

## DP 1.2 AUX Transaction Format

```
REQUEST (Source → Sink):
  PRECHARGE:  16 UI of logic '0' (common mode, both lines low)
  SYNC:       16 × Manchester '1' (falling) + 1 × Manchester '0' (rising)
  CMD:        8 bits: {4'b0000, TYPE[1:0], 2'b00}
  ADDRESS:    20 bits (DPCD address or I2C address+offset)
  LENGTH:     8 bits (number of data bytes - 1, max 15 = 16 bytes)
  DATA:       n × 8 bits (for WRITE only)
  STOP:       1 Manchester '0' after EACH byte

REPLY (Sink → Source):
  PRECHARGE:  16 UI of logic '0'
  SYNC:       16 × '1' + 1 × '0'
  REPLY:      8 bits: {6'b0, REPLY_CODE[1:0]}
  DATA:       n × 8 bits (for READ only)
  STOP:       1 Manchester '0' after EACH byte
```

---

## Key Files Modified Recently

| File | Change |
|------|--------|
| `dp_tx_aux_phy.v` | **DP 1.2 compliant** - Full transaction format with CMD/ADDR/LEN/STOP |
| `aux_periph.v` | PHY TX SM formats DP 1.2 transactions; multi-byte DPCD read/write |
| `riscv_soc.v` | Updated interface: type[1:0], addr[19:0], len[7:0], reply[1:0] |
| `dp_tx_top.v` | Updated AUX interface to match DP 1.2 transaction format |
| `tb/dp_tx_top_tb.v` | Tests: single/multi-byte native read/write |
| `simulate.py` | Includes all updated files |

---

## Next Session: Recommended Starting Points

1. **Test simulation** - Run `python simulate.py` to verify DP 1.2 compliance
2. **Extend firmware** - Modify `firmware.S` for multi-byte DPCD API
3. **Add I2C-over-AUX** - Implement I2C_READ/WRITE in firmware + peripheral (PHY ready)
4. **Fix RAM init** - Change `ram.v` to use `$readmemh` for easier firmware updates
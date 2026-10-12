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
│   ├── dp_tx_aux_phy.v       # NEW: Manchester encode/decode PHY
│   └── riscv/
│       ├── picorv32.v        # RV32I core (native memory I/F)
│       ├── ram.v             # Dual-port BRAM (8KB, firmware init)
│       ├── aux_periph.v      # AUX host I/F + DPCD + RISC-V slave + PHY TX SM
│       ├── riscv_soc.v       # SoC: core + decoder + RAM + peripheral
│       ├── firmware.S        # Assembly source (AUX handler)
│       ├── firmware.hex      # Compiled firmware binary
│       ├── asm.py            # RV32I assembler
│       ├── gen_rom.py        # Generates ram.v mem[] init from firmware.hex
│       ├── test_fw.py        # Python firmware emulation tests
│       └── simulate.py       # Full simulation runner
└── tb/
    ├── dp_tx_top_tb.v        # AUX transaction tests
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

### RISC-V AUX Controller (NEW: Manchester PHY)
- ✅ PicoRV32 RV32I core (2-state pipeline, native mem I/F)
- ✅ 8KB firmware RAM (pre-loaded via `initial` block)
- ✅ AUX peripheral with DPCD register file (256 bytes)
- ✅ Host AUX request/response interface
- ✅ **NEW: `dp_tx_aux_phy.v`** - Full Manchester PHY
  - TX: Precharge (16 UI) → Sync (16×'1' + 1×'0') → Data (8b + stop bit)
  - RX: Edge-detection clock recovery → Sync detect → Manchester decode (3/4 sample) → Stop bit verify
- ✅ PHY TX state machine in `aux_periph.v` sends firmware response
- ✅ Differential AUX pins (`aux_p`, `aux_n`) at top level

### Firmware (`firmware.S`)
- Handles AUX READ (opcode 0x02) → DPCD read
- Handles AUX WRITE (opcode 0x01) → DPCD write
- Unknown opcode → NACK (0x5A)
- **Limitation:** Only single-byte transactions (ignores `aux_req_len`)

---

## Critical Fixes Applied (from AGENTS.md)

| Issue | Fix |
|-------|-----|
| Scrambler never reset | `scrambler_rst` pulsed on ACTIVE→BS transition in `stream_mux` |
| 8b/10b disparity broken | Per-sub-block ones count for correct disparity; per-lane registers in PHY |
| AUX TB race condition | Tasks set `aux_req_valid` **after** `@(posedge clk)` |

---

## Current Limitations / TODOs

### High Priority
1. **Firmware multi-byte support** - `firmware.S` ignores `aux_req_len`; add burst loop
2. **I2C-over-AUX** - Add opcode 0x08/0x09 for EDID reads
3. **RX multi-byte** - PHY RX only handles single byte; add buffer for multi-byte replies

### Medium Priority
4. **RAM firmware loading** - Replace `initial` block in `ram.v` with `$readmemh("firmware.hex")` for easier iteration
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
| 0x1000_0000 | AUX_CTRL | [0]=req_pending(RO), [1]=resp_ready(WO), [2]=ack(WO) |
| 0x1000_0004 | AUX_REQ_OPADDR | {opcode, addr_hi, addr_lo, len} (RO) |
| 0x1000_0008 | AUX_REQ_WDATA | Write data byte from host (RO) |
| 0x1000_000C | AUX_RESP_CTRL | Response code[7:0], ack[8] (WO) |
| 0x1000_0010 | AUX_RESP_DATA | Response data byte (WO) |
| 0x1000_0100 - 0x1000_01FF | DPCD (256B) | Byte-accessible DPCD register file |

---

## AUX PHY Signal Timing (270 MHz sys_clk, 1 MHz AUX)

| Phase | Duration | Cycles (270M/1M) |
|-------|----------|------------------|
| Half bit | 0.5 µs | 135 |
| Precharge | 16 UI | 4,320 |
| Sync '1' × 16 | 16 UI | 4,320 |
| Sync '0' × 1 | 1 UI | 270 |
| Data bit | 1 UI | 270 |
| Stop bit | 1 UI | 270 |

---

## Key Files Modified Recently

| File | Change |
|------|--------|
| `dp_tx_aux_phy.v` | **NEW** - Manchester TX/RX PHY |
| `aux_periph.v` | Added PHY TX state machine (sends resp_code + resp_data) |
| `dp_tx_top.v` | Connected PHY; fixed `gt_refclk` typo; removed 1MHz tick gen |
| `tb/dp_tx_top_tb.v` | Added `aux_p`, `aux_n` differential pins |
| `simulate.py` | Added `dp_tx_aux_phy.v` to compile list |

---

## Next Session: Recommended Starting Points

1. **Test simulation** - Run `python simulate.py` to verify PHY integration
2. **Extend firmware** - Modify `firmware.S` for multi-byte DPCD access
3. **Add I2C-over-AUX** - Implement opcodes 0x08/0x09 in firmware + peripheral
4. **Fix RAM init** - Change `ram.v` to use `$readmemh` for easier firmware updates
# DisplayPort TX IP

A Verilog-based DisplayPort TX IP scaffold for 7-series devices (Artix-7 / Kintex-7) with:

- 4-lane TX architecture (DP 1.2 HBR2-oriented data path)
- RISC-V soft-core AUX transaction controller (PicoRV32 + DPCD peripheral)
- 7-series GTX PHY wrapper (`GTXE2_CHANNEL` for synthesis, behavioral model for simulation)
- MSA generation for training/management bytes
- video packing, scrambling, and stream multiplexing between training and video data
- lane mapping for four logical lanes
- asynchronous pixel-to-byte clock domain crossing (async FIFO)
- MMCM clock generation (270 MHz byte clock + 148.5 MHz pixel clock from a 135 MHz ref)

This is still a synthesizable scaffold rather than a production-ready DisplayPort controller, but it is much closer to a complete TX IP skeleton. See **AGENTS.md** for the full build guide (firmware assemble/test, RTL simulation, and Vivado synthesis).

## Structure

- src/dp_tx_top.v — top-level (instantiates `riscv_soc` for AUX)
- src/dp_tx_aux_ctrl.v — original hardwired AUX (replaced, kept for reference)
- src/dp_tx_video_packer.v
- src/dp_tx_pixel_fifo.v — async FIFO, `pixel_clk` → byte `clk` domain crossing
- src/dp_tx_scrambler.v
- src/dp_tx_8b10b_enc.v — fabric 8b/10b encoder with running-disparity tracking
- src/dp_tx_msa_gen.v
- src/dp_tx_stream_mux.v — training/video stream select + scrambler reset pulse
- src/dp_tx_link_layer.v
- src/dp_tx_lane_mapper.v
- src/dp_tx_clk_gen.v — MMCM: 135 MHz ref → 270 MHz byte + 148.5 MHz pixel clk
- src/dp_tx_phy_7series.v — GTXE2_CHANNEL (synthesis) / behavioral 8b/10b (simulation)
- src/riscv/ — RISC-V AUX subsystem (PicoRV32 core, RAM, DPCD peripheral, firmware)
- tb/dp_tx_top_tb.v — testbench with AUX transaction tests
- tb/dp_tx_top_full_tb.v — full 1080p60 video + AUX testbench
- dp_tx_riscv_full.v — single-file pack of all RTL + testbench

## Current capabilities

- AUX request/response handling via a RISC-V firmware handler with ACK/NACK-style response codes
- DPCD register file, byte-accessible from the RISC-V bus
- MSA byte stream generation
- pixel-to-byte packing
- scrambling of video payload bytes
- selection between training and video streams
- lane mapping for transmission to a 4-lane PHY
- GTXE2_CHANNEL instantiation path for Kintex-7

## Notes

- For synthesis the PHY instantiates real `GTXE2_CHANNEL` primitives (selected out under `__ICARUS__` for simulation). Run the Vivado GTX wizard to match your board's REFCLK and update the PLL/`GT_CLK25_DIV` parameters.
- The firmware image is pre-embedded in `ram.v` as an `initial` block (regenerate with `src/riscv/gen_rom.py` from `firmware.hex` after editing `firmware.S`).
- The current implementation is intended for RTL exploration, simulation, and integration planning in Vivado.

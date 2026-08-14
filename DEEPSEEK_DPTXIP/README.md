# DisplayPort TX IP

This workspace now contains a more detailed Verilog-based DisplayPort TX IP scaffold for 7-series devices (Artix-7 / Kintex-7) with:

- 4-lane TX architecture
- HBR2-oriented data-path structure
- a 7-series GTX PHY wrapper placeholder
- AUX control handling with request/response phases and response codes
- MSA generation for training/management bytes
- video packing and scrambling
- stream multiplexing between training and video data
- lane mapping for four logical lanes

This is still a synthesizable scaffold rather than a production-ready DisplayPort controller, but it is much closer to a complete TX IP skeleton.

## Structure

- src/dp_tx_top.v
- src/dp_tx_aux_ctrl.v
- src/dp_tx_msa_gen.v
- src/dp_tx_stream_mux.v
- src/dp_tx_lane_mapper.v
- src/dp_tx_video_packer.v
- src/dp_tx_scrambler.v
- src/dp_tx_phy_7series.v
- tb/dp_tx_top_tb.v

## Current capabilities

- AUX request/response handling through a small transaction-state machine with ACK/NACK-style responses
- MSA byte stream generation
- pixel-to-byte packing
- scrambling of video payload bytes
- selection between training and video streams
- lane mapping for transmission to a 4-lane PHY

## Notes

- The PHY module remains a placeholder wrapper around the real 7-series GTX transceiver interface.
- The current implementation is intended for RTL exploration, simulation, and integration planning in Vivado.
- For a real product-grade implementation, you would replace the placeholders with proper 7-series GTX transceiver instantiation, DP timing, and full training state handling.

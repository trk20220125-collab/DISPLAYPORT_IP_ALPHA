# DP 1.2 AUX Manchester PHY - Block Diagram

## TX Path (Source → Sink)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          dp_tx_aux_phy (TX)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────┐    ┌─────────────┐    ┌────────────┐    ┌────────────────┐  │
│  │  TX IF   │───▶│  TX State   │───▶│  Bit/Byte  │───▶│ Manchester     │  │
│  │  (Input) │    │  Machine    │    │  Counter   │    │ Encoder        │  │
│  └──────────┘    └─────────────┘    └────────────┘    └───────┬────────┘  │
│        │                │                    │                 │           │
│        ▼                ▼                    ▼                 ▼           │
│  tx_start         TX_IDLE            tx_half_bit_cnt      tx_manchester_  │
│  tx_type          TX_GAP             tx_bit_cnt          phase           │
│  tx_addr          TX_PRECHG          tx_byte_cnt                         │
│  tx_len           TX_SYNC_1                                               │
│  tx_data          TX_SYNC_0         ┌────────────────────────────────┐    │
│  tx_data_valid    TX_CMD            │  Current Bit (MSB first)       │    │
│  tx_last          TX_ADDR_HI        │  ┌──────────────────────────┐  │    │
│                   TX_ADDR_MID       │  │ Manchester II Encoding:  │  │    │
│                   TX_ADDR_LO        │  │   '1' → falling edge     │  │    │
│                   TX_LEN            │  │   '0' → rising edge      │  │    │
│                   TX_DATA           │  │   MSB first              │  │    │
│                   TX_STOP           │  │   Stop bit = '0'         │  │    │
│                   TX_DONE_ST        │  └──────────────────────────┘  │    │
│                                     └────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Output Driver (Tri-state)                         │   │
│  │  ┌─────────┐    tx_oe=1:  aux_p = tx_out_p,  aux_n = tx_out_n      │   │
│  │  │ tx_oe   │    tx_oe=0:  aux_p = Z,       aux_n = Z               │   │
│  │  └────┬────┘                                                         │   │
│  └───────│──────────────────────────────────────────────────────────────┘   │
│          │                                                                    │
│          ▼                                                                    │
│    ┌─────────┐     ┌─────────┐                                                │
│    │ aux_p   │     │ aux_n   │  ──▶ Differential pair to Sink               │
│    └─────────┘     └─────────┘                                                │
└─────────────────────────────────────────────────────────────────────────────┘

TX State Machine Flow:
─────────────────────
TX_IDLE ──(tx_start)──▶ TX_GAP ──(400µs)──▶ TX_PRECHG ──(16 UI)──▶ TX_SYNC_1 ──(16 UI)──▶
TX_SYNC_0 ──(1 UI)──▶ TX_CMD ──(8 UI)──▶ TX_ADDR_HI ──(8 UI)──▶ TX_ADDR_MID ──(8 UI)──▶
TX_ADDR_LO ──(8 UI)──▶ TX_LEN ──(8 UI)──▶ TX_DATA ──(n×8 UI)──▶ TX_STOP ──(1 UI)──▶
TX_DONE_ST ──▶ TX_GAP ──▶ TX_IDLE

Each byte (CMD, ADDR_HI, ADDR_MID, ADDR_LO, LEN, DATA[n]) followed by STOP bit (Manchester '0')
```

## RX Path (Sink → Source)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          dp_tx_aux_phy (RX)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ┌─────────┐     ┌─────────┐                                                │
│    │ aux_p   │     │ aux_n   │  ◀── Differential pair from Source          │
│    └────┬────┘     └────┬────┘                                                │
│         │               │                                                     │
│         ▼               ▼                                                     │
│    ┌─────────────────────────────┐                                           │
│    │   Differential Receiver     │  rx_diff = aux_p ^ aux_n                  │
│    │   rx_diff = aux_p ^ aux_n   │                                           │
│    └──────────────┬──────────────┘                                           │
│                   │                                                          │
│                   ▼                                                          │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │                    Edge Detector                                     │   │
│    │  rx_edge = rx_diff ^ rx_prev_diff                                    │   │
│    │  is_falling = rx_prev_diff & ~rx_diff   // Manchester '1'           │   │
│    │  is_rising  = ~rx_prev_diff & rx_diff   // Manchester '0'           │   │
│    └────────────────────────┬────────────────────────────────────────────┘   │
│                             │                                                  │
│                             ▼                                                  │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │                    RX State Machine                                 │   │
│    ├─────────────────────────────────────────────────────────────────────┤   │
│    │ RX_IDLE ──(precharge detect)──▶ RX_PRECHG_DET ──(first edge)──▶     │   │
│    │ RX_SYNC_DET ──(16 falling + 1 rising)──▶ RX_REPLY ──(8 bits)──▶     │   │
│    │ RX_DATA ──(n×8 bits)──▶ RX_STOP ──(rising edge)──▶ RX_GAP ──▶ RX_IDLE│   │
│    └────────────────────────┬────────────────────────────────────────────┘   │
│                             │                                                  │
│                             ▼                                                  │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │                    Bit Sampler (3/4 bit position)                    │   │
│    │  Sample at rx_half_bit_cnt == 3 * HALF_BIT_CYCLES / 2               │   │
│    │  After mid-bit transition, level = data bit                         │   │
│    │  rx_shift_reg <= {rx_shift_reg[6:0], rx_diff}                       │   │
│    └────────────────────────┬────────────────────────────────────────────┘   │
│                             │                                                  │
│                             ▼                                                  │
│    ┌─────────────────────────────────────────────────────────────────────┐   │
│    │                    Output Interface                                  │   │
│    │  rx_valid     ──▶ Reply received                                     │   │
│    │  rx_reply_code──▶ ACK(00)/NACK(01)/DEFER(10)                        │   │
│    │  rx_data      ──▶ Data byte (for READ replies)                      │   │
│    │  rx_last      ──▶ Last data byte                                     │   │
│    │  rx_err       ──▶ Sync error / timeout / invalid stop               │   │
│    └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Manchester II Encoding (DP 1.2 Standard)

```
Bit Value '1' (Falling Edge):
┌─────────┐
│         │──────▶ High-to-Low transition at bit center
│         │
└─────────┘
  0     0.5µs   1µs (at 1 Mbps)

Bit Value '0' (Rising Edge):
        ┌─────────┐
        │         │──────▶ Low-to-High transition at bit center
────────│         │
        └─────────┘
  0     0.5µs   1µs

SYNC Pattern (17 bits):
┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐┌─┐
│1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │1│ │0│  ◀ 16×'1' + 1×'0'
└─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘└─┘
```

## DP 1.2 AUX Transaction Waveform

```
REQUEST (Source → Sink, NATIVE_WRITE to DPCD[0x0005] = 0xAA):

Time ──────────────────────────────────────────────────────────────────────▶

PRECHARGE (16 UI)    SYNC (17 UI)           CMD        ADDR(20b)   LEN   DATA   STOP
┌────────────────┐┌─────────────────────┐┌────┐┌──────────────────────┐┌──┐┌──┐┌─┐
│ Logic '0'      │ 16×'1' + 1×'0'      │CMD │ ADDR[19:0]            │LEN │0xAA│'0'│
│ (common mode)  │ (Manchester)        │0x00│ (0x00005)             │0x00│    │   │
└────────────────┘└─────────────────────┘└────┘└──────────────────────┘└──┘└──┘└─┘

REPLY (Sink → Source, ACK):

PRECHARGE (16 UI)    SYNC (17 UI)           REPLY      STOP
┌────────────────┐┌─────────────────────┐┌────┐┌─┐
│ Logic '0'      │ 16×'1' + 1×'0'      │0x00│'0'│
│ (common mode)  │ (Manchester)        │ACK │   │
└────────────────┘└─────────────────────┘└────┘└─┘
```

## Key Parameters (270 MHz sys_clk, 1 Mbps AUX)

| Parameter | Value | Cycles |
|-----------|-------|--------|
| `HALF_BIT_CYCLES` | 135 | 0.5 µs |
| `BIT_CYCLES` | 270 | 1 µs |
| `PRECHARGE_CYCLES` | 4,320 | 16 µs |
| `SYNC_ONES_CYCLES` | 4,320 | 16 µs |
| `SYNC_ZERO_CYCLES` | 270 | 1 µs |
| `GAP_CYCLES` | 108,000 | 400 µs |
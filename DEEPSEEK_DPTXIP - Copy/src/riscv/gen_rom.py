import sys
with open("firmware.hex") as f:
    words = [line.strip() for line in f if line.strip()]
for i, w in enumerate(words):
    print(f"        mem[{i}] = 32'h{w};")

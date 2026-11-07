"""Independent transcription of tagged OpenUSD's integer-coding example."""
from collections import Counter
import struct


def encode(values):
    deltas = [values[0]] + [b - a for a, b in zip(values, values[1:])]
    counts = Counter(deltas)
    common = max(counts, key=lambda value: (counts[value], value))
    codes = bytearray((len(deltas) + 3) // 4)
    payload = bytearray()
    for i, value in enumerate(deltas):
        if value == common:
            code, packed = 0, b''
        elif -128 <= value < 128:
            code, packed = 1, struct.pack('<b', value)
        elif -32768 <= value < 32768:
            code, packed = 2, struct.pack('<h', value)
        else:
            code, packed = 3, struct.pack('<i', value)
        codes[i // 4] |= code << (2 * (i % 4))
        payload += packed
    return struct.pack('<i', common) + codes + payload


corrected = encode([123, 124, 125, 100125, 100125, 100126, 100126])
printed = encode([123, 124, 125, 100125, 100125, 100126, 10026])
assert corrected.hex() == '01000000c1117ba08601000000'
assert len(corrected) == 13 and len(printed) == 16
print('corrected input:', len(corrected), corrected.hex())
print('printed input:', len(printed), printed.hex())

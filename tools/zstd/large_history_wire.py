"""Independent singleton wire inspector; default table data frozen from MIT-licensed Zstd 1.6.0 01b7154f1172432f8abe9b3bb9909e14a1176b7d."""
LL_DEFAULT = [(0, 0), (0, 0), (0, 1), (0, 3), (0, 4), (0, 6), (0, 7), (0, 9), (0, 10), (0, 12), (0, 14), (1, 16), (1, 20), (1, 22), (2, 28), (3, 32), (4, 48), (6, 64), (7, 128), (8, 256), (10, 1024), (12, 4096), (0, 0), (0, 1), (0, 2), (0, 4), (0, 5), (0, 7), (0, 8), (0, 10), (0, 11), (0, 13), (1, 16), (1, 18), (1, 22), (2, 24), (3, 32), (3, 40), (6, 64), (6, 64), (7, 128), (9, 512), (11, 2048), (0, 0), (0, 1), (0, 2), (0, 3), (0, 5), (0, 6), (0, 8), (0, 9), (0, 11), (0, 12), (0, 15), (1, 18), (1, 20), (2, 24), (2, 28), (3, 40), (4, 48), (16, 65536), (15, 32768), (14, 16384), (13, 8192)]
OF_DEFAULT = [(0, 0), (6, 61), (9, 509), (15, 32765), (21, 2097149), (3, 5), (7, 125), (12, 4093), (18, 262141), (23, 8388605), (5, 29), (8, 253), (14, 16381), (20, 1048573), (2, 1), (7, 125), (11, 2045), (17, 131069), (22, 4194301), (4, 13), (8, 253), (13, 8189), (19, 524285), (1, 1), (6, 61), (10, 1021), (16, 65533), (28, 268435453), (27, 134217725), (26, 67108861), (25, 33554429), (24, 16777213)]
ML_DEFAULT = [(0, 3), (0, 4), (0, 5), (0, 6), (0, 8), (0, 9), (0, 11), (0, 13), (0, 16), (0, 19), (0, 22), (0, 25), (0, 28), (0, 31), (0, 34), (1, 37), (1, 41), (2, 47), (3, 59), (4, 83), (7, 131), (9, 515), (0, 4), (0, 5), (0, 6), (0, 7), (0, 9), (0, 10), (0, 12), (0, 15), (0, 18), (0, 21), (0, 24), (0, 27), (0, 30), (0, 33), (1, 35), (1, 39), (2, 43), (3, 51), (4, 67), (5, 99), (8, 259), (0, 4), (0, 4), (0, 5), (0, 7), (0, 8), (0, 10), (0, 11), (0, 14), (0, 17), (0, 20), (0, 23), (0, 26), (0, 29), (0, 32), (16, 65539), (15, 32771), (14, 16387), (13, 8195), (12, 4099), (11, 2051), (10, 1027)]
LL_BASE = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,18,20,22,24,28,32,40,48,64,128,256,512,1024,2048,4096,8192,16384,32768,65536]
LL_BITS = [0]*16+[1,1,1,1,2,2,3,3,4,6,7,8,9,10,11,12,13,14,15,16]
ML_BASE = list(range(3,35))+[35,37,39,41,43,47,51,59,67,83,99,131,259,515,1027,2051,4099,8195,16387,32771,65539]
ML_BITS = [0]*32+[1,1,1,1,2,2,3,3,4,4,5,7,8,9,10,11,12,13,14,15,16]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def frame_header(wire):
    require(wire[:4] == bytes.fromhex("28b52ffd"), "Zstd frame magic")
    descriptor = wire[4]
    require(not descriptor & 0x18, "reserved/unused header flags")
    single = bool(descriptor & 32)
    cursor = 5
    window = None
    if not single:
        value = wire[cursor]
        cursor += 1
        base = 1 << (10 + (value >> 3))
        window = base + (base >> 3) * (value & 7)
    dictionary_bytes = (0,1,2,4)[descriptor & 3]
    dictionary_id = int.from_bytes(wire[cursor:cursor+dictionary_bytes], "little")
    cursor += dictionary_bytes
    size_bytes = (int(single),2,4,8)[descriptor >> 6]
    content_size = int.from_bytes(wire[cursor:cursor+size_bytes], "little") if size_bytes else None
    if size_bytes == 2:
        content_size += 256
    cursor += size_bytes
    return {"header_bytes":cursor,"window_size":content_size if single else window,"content_size":content_size,
            "dictionary_id":dictionary_id,"single_segment":single,"checksum":bool(descriptor & 4)}


class ReverseBits:
    def __init__(self, data):
        require(data and data[-1], "reverse bitstream stop bit")
        self.data = data
        self.position = (len(data)-1)*8+data[-1].bit_length()-1

    def read(self, count):
        require(self.position >= count, "reverse bitstream truncated")
        self.position -= count
        return sum(((self.data[(self.position+i)//8] >> ((self.position+i)%8)) & 1)<<i for i in range(count))


def literal_section(payload):
    require(payload, "literal section header")
    kind = payload[0] & 3
    size_format = (payload[0] >> 2) & 3
    if kind < 2:
        header_bytes = 1 if size_format in (0,2) else 2 if size_format == 1 else 3
        regenerated = int.from_bytes(payload[:header_bytes], "little") >> (3 if header_bytes == 1 else 4)
        literal_payload = regenerated if kind == 0 else 1
    else:
        header_bytes = 3 if size_format < 2 else 4 if size_format == 2 else 5
        bits = 10 if header_bytes == 3 else 14 if header_bytes == 4 else 18
        packed = int.from_bytes(payload[:header_bytes], "little")
        regenerated = (packed >> 4) & ((1 << bits) - 1)
        literal_payload = (packed >> (4 + bits)) & ((1 << bits) - 1)
    sequence_offset = header_bytes + literal_payload
    require(sequence_offset < len(payload), "literal payload and sequence count bounds")
    return {"kind":kind,"regenerated_size":regenerated,"sequence_count_offset":sequence_offset}


def one_sequence(payload):
    literal_kind = payload[0] & 3
    format = (payload[0] >> 2) & 3
    require(literal_kind in (0,1), "far singleton uses raw/RLE literal section")
    size = 1 if format in (0,2) else (2 if format == 1 else 3)
    regenerated = int.from_bytes(payload[:size], "little") >> (3 if size == 1 else 4)
    cursor = size+(regenerated if literal_kind == 0 else 1)
    require(payload[cursor] == 1, "one actual far sequence")
    cursor += 1
    mode = payload[cursor]
    cursor += 1
    require(mode & 3 == 0, "sequence reserved flags")
    modes = [(mode>>6)&3,(mode>>4)&3,(mode>>2)&3]
    definitions = []
    for kind, selected in zip(('LL','OF','ML'), modes):
        require(selected in (0,1), "far singleton table must be predefined/RLE")
        if selected == 0:
            definitions.append(None)
            continue
        code = payload[cursor]
        cursor += 1
        if kind == 'LL':
            definition = (LL_BITS[code], LL_BASE[code])
        elif kind == 'ML':
            definition = (ML_BITS[code], ML_BASE[code])
        else:
            definition = (code, 0 if code == 0 else 1 if code == 1 else (1<<code)-3)
        definitions.append(definition)
    reader = ReverseBits(payload[cursor:])
    states = [reader.read(bits) if selected == 0 else None for selected, bits in zip(modes,(6,5,6))]
    for i, (table,state) in enumerate(zip((LL_DEFAULT,OF_DEFAULT,ML_DEFAULT), states)):
        if state is not None:
            definitions[i] = table[state]
    ll, offset, match = definitions
    extra = reader.read(offset[0])
    match_len = match[1]+reader.read(match[0])
    literal_len = ll[1]+reader.read(ll[0])
    require(offset[0] > 1, "far sequence uses actual regular distance")
    require(reader.position == 0, "singleton consumes all sequence bits")
    return {"literal_len":literal_len,"match_len":match_len,"distance":offset[1]+extra,
            "offset_extra_bits":offset[0],"offset_extra_value":extra,"table_modes":modes,"initial_states":states}


def inspect_far(wire):
    header = frame_header(wire)
    cursor = header['header_bytes']
    blocks = []
    decoded = 0
    while True:
        require(cursor+3 <= len(wire), "block header bounds")
        value = int.from_bytes(wire[cursor:cursor+3], "little")
        cursor += 3
        last, kind, size = bool(value&1), (value>>1)&3, value>>3
        require(kind < 3, "reserved block kind")
        payload = wire[cursor:cursor+(1 if kind == 1 else size)]
        require(len(payload) == (1 if kind == 1 else size), "block payload bounds")
        entry = {"kind":kind,"last":last,"wire_bytes":len(payload)}
        if kind < 2:
            entry['decoded_bytes'] = size
        else:
            literals = literal_section(payload)
            sequence_count = payload[literals['sequence_count_offset']]
            if not last:
                require(sequence_count == 0, "far prefix is a verified literal-only compressed block")
                require(literals['sequence_count_offset'] + 1 == len(payload), "literal-only prefix consumes complete block")
                entry['literals_kind'] = literals['kind']
                entry['decoded_bytes'] = literals['regenerated_size']
            elif sequence_count == 0:
                require(literals['sequence_count_offset'] + 1 == len(payload), "literal-only final block consumed")
                entry['decoded_bytes'] = literals['regenerated_size']
            else:
                entry['sequence'] = one_sequence(payload)
                entry['decoded_bytes'] = entry['sequence']['literal_len']+entry['sequence']['match_len']
        blocks.append(entry)
        decoded += entry['decoded_bytes']
        cursor += len(payload)
        if last:
            break
    cursor += 4 if header['checksum'] else 0
    require(cursor == len(wire), "complete frame accounting")
    return {'header':header,'blocks':blocks,'decoded_bytes':decoded,'final_sequence':blocks[-1].get('sequence')}

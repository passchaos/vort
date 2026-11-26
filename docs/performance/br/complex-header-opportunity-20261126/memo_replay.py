"""Independent complete-key LRU replay. No producer module is imported."""
from package_io import require


def key_of(record):
    lengths = bytes.fromhex(record['lengths_hex'])
    stop, policy = record['stop_index'], record['policy_id']
    require(len(lengths) == 256 and all(value <= 15 for value in lengths), 'Invalid canonical256u8 lengths')
    require(type(stop) is int and 1 <= stop <= 256 and lengths[stop - 1] != 0 and not any(lengths[stop:]),
            'Invalid canonical stop or zero tail')
    require(type(policy) is int and policy == 1, 'Header policy differs')
    return lengths, stop, policy


def fingerprint(key):
    value = 0xcbf29ce484222325
    for byte in key[0] + key[1].to_bytes(2, 'little') + key[2].to_bytes(2, 'little'):
        value = ((value ^ byte) * 0x100000001b3) & ((1 << 64) - 1)
    return value


def simulate(records, reset_analysis):
    # Each bucket is ordered oldest -> newest, instead of producer tick/LRU
    # fields. Fingerprints choose the bucket; full keys decide every hit.
    buckets, last_seen, last_analysis = [[] for _ in range(16)], {}, object()
    counters = {'requests': len(records), 'additional_hits': 0, 'misses': 0,
                'unique_keys_seen_in_lifetime': 0, 'repeat_requests': 0, 'repeat_misses': 0,
                'max_repeat_gap_requests': 0, 'max_hit_gap_requests': 0, 'cross_analysis_hits': 0,
                'hits_by_scope': {}, 'unknown_requests': 0}
    steps = []
    for ordinal, record in enumerate(records):
        analysis = record['analysis_ordinal']
        if reset_analysis and (analysis is None or analysis != last_analysis):
            buckets, last_seen = [[] for _ in range(16)], {}
        last_analysis = analysis
        key = key_of(record)
        digest = fingerprint(key)
        scope = {0: 'baseline', 1: 'suffix', 2: 'cluster', None: 'unknown'}[record['scope']]
        counters['unknown_requests'] += analysis is None or scope == 'unknown'
        repeat = key in last_seen
        if repeat:
            counters['repeat_requests'] += 1
            counters['max_repeat_gap_requests'] = max(counters['max_repeat_gap_requests'], ordinal - last_seen[key])
        else:
            counters['unique_keys_seen_in_lifetime'] += 1
        bucket = buckets[digest & 15]
        slot = next((i for i, item in enumerate(bucket) if item['key'] == key), None)
        hit = slot is not None
        previous = None
        if hit:
            item = bucket.pop(slot)
            require(item['bits'] == record['header_bits'], 'Same complete key changed exact bit cost')
            previous = item['ordinal']
            counters['additional_hits'] += 1
            counters['hits_by_scope'][scope] = counters['hits_by_scope'].get(scope, 0) + 1
            counters['max_hit_gap_requests'] = max(counters['max_hit_gap_requests'], ordinal - previous)
            if analysis is not None and item['analysis'] is not None and analysis != item['analysis']:
                counters['cross_analysis_hits'] += 1
        else:
            counters['misses'] += 1
            counters['repeat_misses'] += repeat
            if len(bucket) == 2:
                bucket.pop(0)
        bucket.append({'key': key, 'bits': record['header_bits'], 'ordinal': ordinal, 'analysis': analysis})
        steps.append({'hit': hit, 'repeat': repeat, 'repeat_miss': repeat and not hit,
                      'prior_hit_ordinal': previous, 'prefilter_hash64': format(digest, '016x')})
        last_seen[key] = ordinal
    counters['additional_hit_fraction'] = counters['additional_hits'] / len(records) if records else 0
    require(counters['requests'] == counters['additional_hits'] + counters['misses'], 'Memo request accounting differs')
    return counters, steps

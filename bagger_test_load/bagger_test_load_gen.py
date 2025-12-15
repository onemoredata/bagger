#!/usr/bin/env python3

import json
import optparse
import sys
import os

from BaggerTestLoad import *

def main():
    parser = optparse.OptionParser(add_help_option = False)
    parser.add_option('-?', '--help', action = 'store_true')
    parser.add_option('-i', '--input')
    parser.add_option('-o', '--output')
    parser.add_option('-s', '--seed')
    parser.add_option('-m', '--minutes', type = "float", default = 1)
    parser.add_option('-r', '--rpm', type = "float", default = 1000)
    parser.add_option('-t', '--tsoffset', default = '-0.2,0.001')
    parser.add_option('--entry_ts_omit', type = 'float', default = 0.001)
    parser.add_option('--entry_ts_corrupt', type = 'float', default = 0.001)

    opts, args = parser.parse_args()

    if opts.help == True:
        parser.print_help()
        return

    with open(opts.input, 'r') as fd:
        definition = json.loads(fd.read())

    step = 1.0 / (opts.rpm * 60.0)
    rows = int(opts.minutes * opts.rpm)

    tlgen = TestLoadGenerator(definition, seed = opts.seed)

    if opts.output is None or opts.output == '-':
        out = sys.stdout
    else:
        out = open(opts.output, 'w')

    off_min = int(float(opts.tsoffset.split(',')[0]) * 1_000_000)
    off_max = int(float(opts.tsoffset.split(',')[1]) * 1_000_000)

    for i in range (0, rows):
        entry = json.dumps(next(tlgen))
        elen = len(entry) + 1
        due = step * float(i)
        off = float(random.randint(off_min, off_max)) / 1_000_000
        if random.random() < opts.entry_ts_omit:
            off = -666666.666
        if random.random() < opts.entry_ts_corrupt:
            off = -666666.999

        try:
            out.write("{0:.6f} {1:.6f} {2:d}\n{3}\n".format(due, off,
                                                            elen, entry))
        except Exception as ex:
            sys.exit(1)

    if opts.output is not None and opts.output != '-':
        out.close()


if __name__ == "__main__":
    main()

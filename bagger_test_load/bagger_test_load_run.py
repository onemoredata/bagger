#!/usr/bin/env python3

import json
import optparse
import sys
import os
import time
import psycopg
import signal

from BaggerTestLoad import *

sigterm_received = False

progress_stats = {
    'next_report':  0.0,
    'num_batches': 0,
    'num_rows': 0,
    'last_due': 0.0,
    'lag': 0.0
}

def main():
    global opts
    global sigterm_received
    global progress_stats

    signal.signal(signal.SIGTERM, sigterm_handler)

    parser = optparse.OptionParser(add_help_option = False)
    parser.add_option('-?', '--help', action = 'store_true')
    parser.add_option('-i', '--input')
    parser.add_option('-s', '--schute', default = 'bagger_data.schute')
    parser.add_option('-e', '--entry_ts', default = 'logged')
    parser.add_option('-c', '--conninfo', action = 'append')
    parser.add_option('-b', '--batchsize', type = "int", default = 100)
    parser.add_option('-t', '--timing', type = "float", default = 1.0)
    parser.add_option('-P', '--progress_secs', type = "float", default = 10.0)

    opts, args = parser.parse_args()

    if opts.help == True:
        parser.print_help()
        return

    if opts.input is None or opts.input == '-':
        infd = sys.stdin
    else:
        infd = open(opts.input, 'r')

    if opts.conninfo is not None:
        db = []
        for cinfo in opts.conninfo:
            conn = psycopg.connect(cinfo)
            db.append(conn)
            conn.add_notice_handler(log_notice)
            print("connected to '{0}'".format(cinfo))
    else:
        db = None

    progress_stats['next_report'] = time.time() + opts.progress_secs

    tlreader = TestLoadReader(infd, opts.entry_ts, opts.timing)

    batch = []
    bsize = 0

    for due, payload in tlreader:
        if sigterm_received:
            print("terminating reader due to SIGTERM", file = sys.stderr)
            bsize = 0
            break

        progress_stats['last_due'] = due
        batch.append(payload)
        bsize += 1
        if bsize >= opts.batchsize:
            send_batch(db, batch, bsize)
            batch = []
            bsize = 0

    if bsize > 0:
        progress_stats['next_report'] = 0.0
        send_batch(db, batch, bsize)
        
    if opts.conninfo is not None:
        for conn in db:
            conn.close()

    if opts.input is not None and opts.input != '-':
        infd.close()
    
def send_batch(db, batch, bsize):
    global opts
    global progress_stats

    if db is None:
        print("COPY {} (entry) FROM STDIN;".format(opts.schute))
        for entry in batch:
            print(entry)
    else:
        for conn in db:
            cur = conn.cursor()
            with cur.copy("COPY {} (entry) FROM STDIN".format(opts.schute)) as copy:
                for entry in batch:
                    copy.write_row([json.dumps(entry)])

            cur.close()
            conn.commit()

    progress_stats['num_batches'] += 1
    progress_stats['num_rows'] += bsize

    now = time.time()
    if now >= progress_stats['next_report']:
        report = {
            'now': now,
            'bpm': progress_stats['num_batches'] / opts.progress_secs * 60.0,
            'rpm': progress_stats['num_rows'] / opts.progress_secs * 60.0,
            'lag': now - progress_stats['last_due']
        }
        print(json.dumps(report))
        progress_stats['next_report'] += opts.progress_secs
        progress_stats['lag'] = now - progress_stats['last_due']
        progress_stats['num_batches'] = 0
        progress_stats['num_rows'] = 0

def log_notice(diag):
    print(diag.severity, diag.message_primary)

def sigterm_handler(signum, frame):
    global sigterm_received

    sigterm_received = True

if __name__ == "__main__":
    main()

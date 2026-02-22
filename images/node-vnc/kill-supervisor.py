#!/usr/bin/env python3
"""Supervisor event listener that stops supervisord when openclaw-node exits."""

import os
import signal
import sys


def main():
    while True:
        sys.stdout.write("READY\n")
        sys.stdout.flush()

        header = sys.stdin.readline().strip()
        headers = dict(x.split(":") for x in header.split())

        payload_len = int(headers.get("len", 0))
        payload = sys.stdin.read(payload_len) if payload_len > 0 else ""

        payload_data = dict(x.split(":") for x in payload.split())
        process_name = payload_data.get("processname", "")

        if process_name == "openclaw-node":
            sys.stderr.write(
                f"[kill-supervisor] openclaw-node exited "
                f"(event={headers.get('eventname', '?')}), "
                f"stopping supervisord\n"
            )
            sys.stderr.flush()
            os.kill(os.getppid(), signal.SIGTERM)

        sys.stdout.write("RESULT 2\nOK")
        sys.stdout.flush()


if __name__ == "__main__":
    main()

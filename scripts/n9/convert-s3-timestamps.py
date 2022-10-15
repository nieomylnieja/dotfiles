#!/usr/bin/env python
import sys
import csv
import re
from datetime import datetime

if len(sys.argv) != 2:
    print("Provide csv file path to convert!")
    exit(1)


FILE = sys.argv[1]
NANO_PRECISION = "nano"
TIME_FORMAT = "%Y-%m-%dT%H:%M:%S"


def ts_to_date(ts: str, precision="second"):
    ts = ts.removesuffix("i")
    dt = datetime.utcfromtimestamp(int(ts) / 1000000000)
    format = TIME_FORMAT
    if precision is NANO_PRECISION:
        format += ".%f"
    return dt.strftime(format)


with open(FILE, "r") as f:
    regex = re.compile(r"received_time=(\d{19}i?) (\d{19})")
    reader = csv.reader(f, delimiter=",")
    for row in reader:
        result = regex.findall(row[3])
        if len(result) == 0 or len(result[0]) != 2:
            print(row[3])
            continue
        match = result[0]
        print(
            f"{', '.join(row[:3])}, "
            + f"received_time={ts_to_date(match[0], precision=NANO_PRECISION)} "
            + f"{ts_to_date(match[1])}"
        )

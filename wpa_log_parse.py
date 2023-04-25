import argparse
import datetime
import re

from pathlib import Path


def main(args):

    log = Path(args.log)
    if not log.exists():
        printf(f'provided log file {log} does not exist')
        return

    prog = re.compile(r'(^[0-9]+\.[0-9]+): (.*)')

    log_file = open(log, 'r')
    for line in log_file.readlines():

        # extract timestamp and description from log file line

        res = prog.match(line)
        if len(res.groups()) != 2:
            continue

        time_str = res.groups()[0]
        desc_str = res.groups()[1]

        # print line with formatted date

        timestamp = datetime.datetime.fromtimestamp(float(time_str))
        new_line = '[' + timestamp.isoformat(sep=' ') + '] ' + desc_str
        print(new_line)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='format timestamps in wpa_supplicant.log')
    parser.add_argument('--log', type=str, default='/var/log/wpa_supplicant.log',
                        help='wpa supplicant log file to parse')

    args = parser.parse_args()
    main(args)

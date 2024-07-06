#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import zlib
import logging

from urllib import request
from typing import List, Set, Dict, Optional, Tuple
from pathlib import Path

CODENAMES: List[str] = ['noble', 'jammy']
CONTENTS_URL_TEMPLATE: str = '{}/dists/{}/Contents-amd64.gz'
PATH_REGEX: re.Pattern = re.compile(r'/?usr/lib/(?:x86_64-linux-gnu/)?(?P<key>lib[a-zA-Z0-9\-._+]+\.so(?:\.[0-9]+)*)')
CHUNK_SIZE: int = 32768

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def parse_contents_line(line: str) -> Optional[Tuple[str, Set[str]]]:
    parts = line.strip().replace('\t', '').replace('\n', '').rsplit(' ', maxsplit=1)
    if len(parts) != 2:
        return None
    path, packages_str = parts
    packages = {pkg.strip().rsplit('/', maxsplit=1)[-1] for pkg in packages_str.strip().split(',')}
    return path.strip(), packages


def parse_contents_chunk(chunk: str, res: Dict[str, Set[str]]) -> str:
    for line in chunk.splitlines():
        line_data = parse_contents_line(line)
        if line_data is None:
            return line
        path, pkgs = line_data
        path_match = PATH_REGEX.fullmatch(path)
        if not path_match:
            continue
        key = path_match['key']
        v = res.get(key)
        if v is None:
            res[key] = pkgs
        else:
            res[key] = v.union(pkgs)
    return ''


def parse_ubuntu_contents(
        codename: str, out: Dict[str, Set[str]], mirror: str = 'https://mirrors.edge.kernel.org/ubuntu'):
    url = CONTENTS_URL_TEMPLATE.format(mirror, codename)
    logger.info('Reading {}'.format(url))
    d = zlib.decompressobj(zlib.MAX_WBITS | 32)
    with request.urlopen(request.Request(url)) as resp:
        if resp.status != 200:
            logger.error('Failed to download {}: {}'.format(url, resp.status))
            exit(1)
        file_str = d.decompress(resp.read()).decode('utf-8')
        parse_contents_chunk(file_str, out)


if __name__ == '__main__':
    target_path = Path(os.path.dirname(__file__)) / 'data' / 'lut_sonames.csv'
    logger.info('target path: {}'.format(target_path))
    output: Dict[str, Set[str]] = dict()
    for c in CODENAMES:
        parse_ubuntu_contents(c, output)
    logging.info('{} entries found, saving to {}'.format(len(output), target_path))
    csv = '\n'.join(['{},{}'.format(k, ','.join([pkg for pkg in v])) for (k, v) in output.items()])
    with open(target_path, 'w') as target_file:
        target_file.write(csv)

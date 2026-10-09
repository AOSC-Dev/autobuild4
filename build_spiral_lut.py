#!/usr/bin/env python3

import csv
import datetime
import logging
import os
import re
import sys
import zlib
from pathlib import Path
from urllib import request

CODENAMES: list[str] = ["noble", "jammy", "resolute", "stonking"]
CONTENTS_URL_TEMPLATE: str = "{}/dists/{}/Contents-amd64.gz"
PATH_REGEX: re.Pattern = re.compile(
    r"/?usr/lib/(?:x86_64-linux-gnu/)?(?P<key>lib[a-zA-Z0-9\-._+]+\.so(?:\.[0-9]+)*)"
)
CHUNK_SIZE: int = 32768

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def parse_contents_line(line: str) -> tuple[str, set[str]] | None:
    parts = line.strip().replace("\t", "").replace("\n", "").rsplit(" ", maxsplit=1)
    if len(parts) != 2:
        return None
    path, packages_str = parts
    packages = {
        pkg.strip().rsplit("/", maxsplit=1)[-1]
        for pkg in packages_str.strip().split(",")
    }
    return path.strip(), packages


def parse_contents_chunk(chunk: str, res: dict[str, set[str]]) -> str:
    for line in chunk.splitlines():
        line_data = parse_contents_line(line)
        if line_data is None:
            return line
        path, pkgs = line_data
        path_match = PATH_REGEX.fullmatch(path)
        if not path_match:
            continue
        key = path_match["key"]
        v = res.get(key)
        if v is None:
            res[key] = pkgs
        else:
            res[key] = v.union(pkgs)
    return ""


def parse_ubuntu_contents(
    codename: str,
    out: dict[str, set[str]],
    mirror: str = "http://archive.ubuntu.com/ubuntu",
):
    url = CONTENTS_URL_TEMPLATE.format(mirror, codename)
    logger.info(f"Reading {url}")
    d = zlib.decompressobj(zlib.MAX_WBITS | 32)
    with request.urlopen(request.Request(url)) as resp:
        if resp.status != 200:
            logger.error(f"Failed to download {url}: {resp.status}")
            sys.exit(1)
        file_str = d.decompress(resp.read()).decode("utf-8")
        parse_contents_chunk(file_str, out)


def get_active_ubuntu_series() -> list[str]:
    with request.urlopen(
        "https://salsa.debian.org/debian/distro-info-data/-/raw/main/ubuntu.csv?ref_type=heads&inline=false"
    ) as resp:
        if resp.status != 200:
            logger.warning(f"Failed to fetch active Ubuntu series: {resp.status}")
            return CODENAMES
        data = csv.DictReader(resp.read().decode("utf-8").splitlines())
        current_time = datetime.datetime.now(tz=datetime.timezone.utc)
        series = [
            row["series"]
            for row in data
            if datetime.datetime.strptime(row["eol"], "%Y-%m-%d").replace(
                tzinfo=datetime.timezone.utc
            )
            > current_time
        ]
        series.sort()
        logger.info(f"Active Ubuntu series: {series}")
        return series


if __name__ == "__main__":
    target_path = Path(os.path.dirname(__file__)) / "data" / "lut_sonames.cpp.inc"
    logger.info(f"target path: {target_path}")
    output: dict[str, set[str]] = {}
    for c in get_active_ubuntu_series():
        parse_ubuntu_contents(c, output)
    logger.info(f"{len(output)} entries found, saving to {target_path}")
    csv_data = "\n".join(
        [
            '{{"{}","{}"}},'.format(k, ",".join([pkg for pkg in sorted(v)]))
            for (k, v) in output.items()
        ]
    )
    with open(target_path, "w") as target_file:
        target_file.write(csv_data)

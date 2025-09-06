import argparse
from io import BytesIO, TextIOWrapper
from dataclasses import dataclass

from PIL import Image
import numpy as np


@dataclass
class Resolution:
    width: int
    height: int
    color_depth: int


@dataclass
class Arugments:
    source: str
    destination: str
    width: int
    height: int


def convert_image(source: BytesIO, destination: TextIOWrapper, res: Resolution) -> None:
    img = Image.open(source)
    img = img.resize((res.width, res.height))
    arr = np.array(img)

    # image is currently in 8-bit color. Downscale to color depth:
    scale = 2 ** (8 - res.color_depth)
    arr = arr // scale

    for y in range(res.height):
        for x in range(res.width):
            pxl = arr[y][x]
            color = (int(pxl[0]) << (2*res.color_depth)) | (int(pxl[1]) << res.color_depth) | int(pxl[2])
            destination.write(f"{color:x}\n")


def main(source: str, destination: str, res: Resolution) -> None:
    with open(source, "rb") as f_src, open(destination, "w") as f_dst:
        convert_image(f_src, f_dst, res)


def parse_args() -> Arugments:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source", dest="source", help="Path of source image", type=str, required=True
    )
    parser.add_argument(
        "--destination",
        dest="destination",
        help="Path of destionation mem file",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--width",
        dest="width",
        help="Width of resulting image. Will be resized to fit",
        default=640,
        type=int,
    )
    parser.add_argument(
        "--height",
        dest="height",
        help="Height of resulting image. Will be resized to fit",
        default=480,
        type=int,
    )
    args = parser.parse_args()
    return Arugments(**vars(args))


if __name__ == "__main__":
    args = parse_args()

    main(args.source, args.destination, Resolution(args.width, args.height, 4))

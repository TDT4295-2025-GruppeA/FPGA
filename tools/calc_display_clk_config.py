import argparse
import math
from dataclasses import dataclass


@dataclass
class Arguments:
    clk_in: float
    clk_out: list[float]


@dataclass
class ClockConfig:
    actual_freq: float
    master_multiplier: float
    master_divisor: int
    clock_divisor: float


def main(clk_in: float, outputs: list[float]) -> ClockConfig:
    """calculate MMCM config for output clock 0.
    Assumes float clock divider is available
    (only usable for output 0).
    """
    VCO_MIN = 600_000_000
    VCO_MAX = 1_200_000_000
    MUL_STEP = 0.125
    MUL_MIN = 2
    MUL_MAX = 64
    DIV_MIN = 1
    DIV_MAX = 106
    CLKDIV_MIN = 1
    CLKDIV_MAX = 128
    CLKDIV_STEP = 0.125

    if len(outputs) > 6 or len(outputs) == 0:
        raise ValueError(f"Number of output clocks must be between 1 and 6, not {len(outputs)}")

    clk_out = outputs[0]

    best: tuple | None = None
    best_error = float("inf")

    for div in range(DIV_MIN, DIV_MAX):
        multiplier_min = max(
            MUL_MIN, math.ceil(VCO_MIN * div / MUL_STEP / clk_in) * MUL_STEP
        )
        multiplier_max = min(
            MUL_MAX, math.floor(VCO_MAX * div / MUL_STEP / clk_in) * MUL_STEP
        )

        mul = multiplier_min
        while mul <= multiplier_max + 1e-6:
            freq_vco = clk_in * mul / div
            clk_div = round(freq_vco / clk_out / CLKDIV_STEP) * CLKDIV_STEP

            if clk_div >= CLKDIV_MIN and clk_div <= CLKDIV_MAX:
                freq_actual = freq_vco / clk_div
                error = abs(freq_actual - clk_out)
                if error < best_error:
                    best_error = error
                    best = (freq_actual / 1e6, mul, div, clk_div)
            mul += MUL_STEP

    if best is None:
        raise RuntimeError(
            f"Cold not find any solution configuration for clk input {clk_in}MHz and output {clk_out}MHz"
        )

    return ClockConfig(*best)


def parse_args() -> Arguments:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", type=float, help="Input frequency measured in MHz", dest="clk_in", required=True
    )
    parser.add_argument(
        "--output", type=float, help="Output frequency measured in MHz", dest="clk_out", required=True, action="append"
    )
    args = parser.parse_args()

    return Arguments(**vars(args))


if __name__ == "__main__":
    args = parse_args()

    clk_outputs = [clk * 1e6 for clk in args.clk_out]

    clock = main(args.clk_in * 1e6, clk_outputs)

    clk_out = args.clk_out[0]

    # Only display clock diff of up to 3 decimals, because we are not that precise.
    print(f"Input clock: {args.clk_in} MHz")
    print(f"Target output clock: {args.clk_out} MHz")
    print(f"Actual output clock: {round(clock.actual_freq, 3)} MHz")
    clock_diff = round(abs(clk_out - clock.actual_freq), 3)
    print(f"Clock diff: {clock_diff} MHz")
    print()

    print("Calculated clock configuration:")
    print(f"Master multiplier: {clock.master_multiplier}")
    print(f"Master divisor: {clock.master_divisor}")
    print(f"Clock divisor: {clock.clock_divisor}")
    print()
    print(f"{clock.master_multiplier}, {clock.master_divisor}, {clock.clock_divisor}")

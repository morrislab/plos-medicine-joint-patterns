"""
Extracts sites from the validation data.
"""

import collections
import feather
import numpy as np
import pandas as pd
import re

from click import *
from logging import *
from typing import *

COLUMNS = collections.OrderedDict([("ID", "subject_id"), ("TIMEFRAME", "visit_id")])


def get_new_name(x: str) -> str:
    """
    Obtains a new name for the given site.

    Args:
        x: The original name.

    Returns:
        The new name.
    """

    y = x.lower()

    if y == "cervical":

        return "cervical_spine"

    m = re.match(r"^([lr])\s+(.+)$", y)

    if not m:

        raise ValueError("cannot parse site name: {!r}".format(x))

    side = "left" if m.group(1) == "l" else "right"

    site = m.group(2)

    if site == "ip":

        site = "pip1"

    elif site == "si":

        site = "sacroiliac"

    elif re.match(r"tm[jl]", site):

        site = "tmj"

    m_toe = re.match(r"^toe(\d)$", site)

    if m_toe:

        site = "toe_ip{}".format(m_toe.group(1))

    return "{}_{}".format(site, side)

    import IPython

    IPython.embed()
    raise Exception()


def get_new_names(names: pd.Index) -> Dict[str, str]:
    """
    Obtains new names for the sites.

    Args:
        names: The original names.

    Returns:
        A mapping of original names to new names.
    """

    return {x: get_new_name(x) for x in names}


@command()
@option(
    "--input",
    required=True,
    metavar="INPUT",
    help="load input data from Excel file INPUT",
)
@option(
    "--visit",
    type=int,
    required=True,
    metavar="VISIT",
    help="extract information from visit VISIT",
)
@option(
    "--output",
    required=True,
    metavar="OUTPUT",
    help="output extracted data to Feather file OUTPUT",
)
def main(input, visit, output):

    basicConfig(
        level=INFO,
        handlers=[StreamHandler(), FileHandler("{}.log".format(output), mode="w")],
    )

    # Load the data.

    info("Loading and selecting data")

    data = pd.read_excel(input)

    data.info()

    cols_to_select = (
        pd.Index(COLUMNS.keys())
        | data.columns[
            (data.columns == "CERVICAL") | data.columns.str.contains(r"^[LR]\s+")
        ]
    )

    df = data[cols_to_select].copy()

    df.rename(columns=COLUMNS, inplace=True)

    # Filter the visits of interest.

    info("Filtering to visits")

    df = df.query("visit_id == @visit").copy()

    df.drop("visit_id", axis=1, inplace=True)

    # Format the data by removing missing values and setting active sites to 1.

    info("Formatting data")

    df.set_index("subject_id", inplace=True)

    df = pd.DataFrame(
        np.where(df.values == 9999, np.zeros(df.shape), df.values),
        index=df.index,
        columns=df.columns,
    )

    df = df.fillna(0)

    df = df.astype(int)

    df *= -1

    # Rename the joints.

    info("Renaming sites")

    new_names = get_new_names(df.columns)

    df.rename(columns=new_names, inplace=True)

    # Output the resulting data.

    info("Writing data")

    df.reset_index(inplace=True)

    df.info()

    feather.write_dataframe(df, output)


if __name__ == "__main__":
    main()

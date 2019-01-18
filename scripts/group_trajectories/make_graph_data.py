"""
Makes graph data for the group trajectories.
"""

import click
import collections
import colorsys as cs
import io
import networkx as nx
import numpy as np
import pandas as pd
import re
import string

from logging import *
from typing import *


def load_data(handle) -> pd.DataFrame:
    """
    Loads cluster assignments from the given handle.

    Args:
        handle: The handle to load cluster assignments from.

    Returns:
        The cluster assignments.
    """

    result = pd.read_csv(handle, dtype={'classification': str})

    result.info()

    return result


def get_hex(r: float, g: float, b: float) -> str:
    """
    Converts an RGB colour in floats to a string.

    Args:
        r: The red component.
        g: The green component.
        b: The blue component.

    Returns:
        The hex colour.
    """

    r = np.round(r * 255).astype(int)

    g = np.round(g * 255).astype(int)

    b = np.round(b * 255).astype(int)

    return '#{}'.format(''.join('{:2x}'.format(x) for x in [r, g, b]))


def get_cluster_colour_palette(n: int) -> List[str]:
    """
    Obtains a colour palette for cluster colours.

    Args:
        n: The number of colours to generate.

    Returns:
        The colours.
    """

    cluster_colours = [
        get_hex(*cs.hsv_to_rgb(x, 0.75, 0.75)) for x in np.arange(0, 1, 1. / n)
    ]

    return cluster_colours[0::2] + cluster_colours[1::2]


def get_cluster_colours(df: pd.DataFrame) -> Dict[str, str]:
    """
    Obtains a mapping of cluster labels to cluster colours.

    Args:
        df: Cluster assignments.

    Returns:
        A mapping of cluster labels to cluster colours.
    """

    mappings = {}

    unique_clusters = df['classification'].unique()

    # Take care of the zero cluster.

    if '--' in unique_clusters:

        mappings['--'] = '#000000'

    # Take care of the narrow clusters.

    narrow_clusters = sorted(x for x in unique_clusters if re.match(r'^\d', x))

    max_narrow_cluster = int(narrow_clusters[-1])

    narrow_colours = get_cluster_colour_palette(max_narrow_cluster)

    mappings.update(
        {k: colour
         for k, colour in zip(narrow_clusters, narrow_colours)})

    # Then handle the broad clusters.

    broad_clusters = sorted(
        x for x in unique_clusters if re.match(r'^[A-Z]', x))

    max_broad_cluster = broad_clusters[-1]

    broad_colours = get_cluster_colour_palette(
        string.ascii_uppercase.index(max_broad_cluster) + 1)

    mappings.update(
        {k: colour
         for k, colour in zip(broad_clusters, broad_colours)})

    return mappings


def get_paths_to_show(df_chisq: pd.DataFrame,
                      std_residual: float) -> pd.DataFrame:
    """
    Obtains paths to show given a table of chi-square residuals.

    Args:
        df_chisq: Chi-square residuals.
        std_residual: Standardized residual threshold to call a path to show.

    Results:
        A table of paths to show.
    """

    return df_chisq.loc[df_chisq['std_residual'] >= std_residual,
                        ['visit_a', 'visit_b', 'cluster_a', 'cluster_b']]


def get_path_counts(df: pd.DataFrame) -> pd.DataFrame:
    """
    For each unique path in the given table of clusters, calculates the number
    of patients following that path.

    Args:
        df: A table of clusters.

    Returns:
        The number of patients following a given path of cluster assignments.
    """

    info('Calculating path counts')

    df = df.set_index(['subject_id', 'visit_id']).unstack(['visit_id'])

    df.columns = df.columns.levels[1]

    result = df.fillna(-1).groupby(df.columns.tolist()).size().reset_index()

    result.rename(columns={0: 'count'}, inplace=True)

    info('Result is a table with shape {}'.format(result.shape))

    return result


def get_consecutive_path_counts_visits(path_counts: pd.DataFrame,
                                       j1: object,
                                       j2: object) -> pd.DataFrame:
    """
    Obtains path counts between two given consecutive columns from the given
    table of path counts.

    Args:
        path_counts: A table of path counts.
        j1: The first column.
        j2: The second column.

    Returns:
        The number of patients following a given path.
    """

    result = path_counts.groupby([j1, j2])['count'].sum().reset_index()

    result.rename(columns={j1: 'cluster1', j2: 'cluster2'}, inplace=True)

    result = result.loc[(result['cluster1'] != -1) & (result['cluster2'] != -1
                                                      )]

    result['cluster1'] = ['{}_{}'.format(c, j1) for c in result['cluster1']]

    result['cluster2'] = ['{}_{}'.format(c, j2) for c in result['cluster2']]

    return result


def get_consecutive_path_counts(path_counts: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains path counts between pairs of consecutive visits from the given
    table of path counts.

    Args:
        path_counts: A table of path counts.

    Returns:
        The number of patients following a given path.
    """

    info('Calculating path counts between consecutive visits')

    result = pd.concat([
        get_consecutive_path_counts_visits(path_counts, j1, j2)
        for j1, j2 in zip(path_counts.columns[:-2], path_counts.columns[1:-1])
    ])

    result.reset_index(drop=True, inplace=True)

    info('Result is a table with shape {}'.format(result.shape))

    return result


def get_proportions(df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculates proportions of patients in a given column of counts.

    Args:
        df: A table containing counts.

    Returns:
        A table containing proportions.
    """

    df = df.copy()

    df['count'] /= df['count'].sum()

    df.rename(columns={'count': 'proportion'}, inplace=True)

    return df


def get_path_proportions(
        consecutive_path_counts: pd.DataFrame) -> pd.DataFrame:
    """
    For each consecutive path, calculates the proportions of patients in the
    source cluster who follow that path.

    Args:
        consecutive_path_counts: A table of consecutive paths.

    Returns:
        The proportion of patients in a source cluster that follow given paths.
    """

    info('Calculating proportions')

    result = consecutive_path_counts.groupby('cluster1')[['count']].apply(
        get_proportions).reset_index()

    result.drop('cluster1', axis=1, inplace=True)

    result.set_index('level_1', inplace=True)

    result = consecutive_path_counts.merge(
        result, left_index=True, right_index=True)

    return result


def get_cluster_count_visit(df: pd.DataFrame, j: str) -> pd.DataFrame:
    """
    Calculates cluster counts from the given data frame for the given column.

    :param pd.DataFrame df

    :param str j

    :rtype: pd.DataFrame
    """

    result = df.groupby(j)['count'].sum().reset_index()

    result.rename(columns={j: 'cluster'}, inplace=True)

    result = result.loc[result['cluster'] != -1]

    result['clusterletter'] = result['cluster']

    result['visitid'] = j

    result['cluster'] = ['{}_{}'.format(c, j) for c in result['cluster']]

    result['proportion'] = result['count'] / result['count'].sum()

    # Determine the relative display size of the cluster.

    result['size'] = result['proportion']**0.5

    denominator_parts = result.set_index('clusterletter')['size'].drop(
        '--', errors='ignore')

    result['normalizedsize'] = result['size'] / denominator_parts.max(
    ) if denominator_parts.shape[0] > 0 else 1.

    return result


def get_cluster_counts(path_counts: pd.DataFrame) -> pd.DataFrame:
    """
    Obtains cluster counts for each visit.

    Args:
        path_counts: A table counting the number of patients per path.

    Returns:
        A table counting the number of patients per visit.
    """

    info('Calculating cluster counts')

    result = pd.concat([
        get_cluster_count_visit(path_counts, j)
        for j in path_counts.columns[:-1]
    ])

    return result


def make_graph(cluster_counts: pd.DataFrame,
               consecutive_path_counts: pd.DataFrame,
               paths_to_show: pd.DataFrame) -> nx.DiGraph:
    """
    Constructs a graph from the given cluster counts and consecutive visit path
    counts.

    Args:
        cluster_counts: A table of patient counts per cluster.
        consecutive_path_counts: A table counting the number of patients per
            path.
        paths_to_show: A table listing which paths to show.

    Returns:
        The generated graph.
    """

    info('Constructing graph')

    g = nx.DiGraph()

    g.add_nodes_from([(row['cluster'], {
        k: row[k]
        for k in [
            'clusterletter', 'visitid', 'count', 'proportion', 'size',
            'normalizedsize'
        ]
    }) for _, row, in cluster_counts.iterrows()])

    # Add edges only supported by the chi-square test.

    consecutive_path_counts = consecutive_path_counts.set_index(
        ['cluster1', 'cluster2'])

    paths_to_show['cluster1'] = paths_to_show.apply(
        lambda r: '{}_{}'.format(r['cluster_a'], r['visit_a']), axis=1)

    paths_to_show['cluster2'] = paths_to_show.apply(
        lambda r: '{}_{}'.format(r['cluster_b'], r['visit_b']), axis=1)

    # Add edges only from consecutive visits.

    g.add_edges_from([(row['cluster1'], row['cluster2'], {
        'weight': consecutive_path_counts.loc[(row['cluster1'], row['cluster2']
                                               ), 'count'],
        'sourcecluster': row['cluster1'],
        'targetcluster': row['cluster2'],
        'proportion': consecutive_path_counts.loc[(row['cluster1'], row[
            'cluster2']), 'proportion']
    }) for _, row in paths_to_show.iterrows()
                      if row['visit_b'] == row['visit_a'] + 1])

    return g


def get_base_classification(x: str) -> str:
    """
    Obtains the base classification for a given node label.

    Args:
        x: The label from which to obtain the base classification.

    Returns:
        The base classification.
    """

    return x.split('_', 1)[0]


def arrange_graph(graph: nx.DiGraph) -> nx.DiGraph:
    """
    Arranges nodes in the given graph.

    Nodes referring to the same visit will have the same y-coordinate.

    With respect to determining x-coordinates, a weighted sum between pairs of
    clusters is enumerated. This quantity refers to the number of patients who
    transition between any two clusters at any time point. Weights are equal to
    `2 ^ (visit number - 1)`. The edge with the highest sum is used to
    establish the two anchors in a list. For each additional cluster C to
    arrange, we determine the highest sum between it and the already sorted
    clusters. To the right of the sorted cluster with the highest weight
    becomes the new position for that cluster.

    Args:
        graph: The graph to arrange.

    Returns:
        A graph with x- and y-coordinates computed for each node.
    """

    # Attach y-coordinates to the nodes.

    for n in graph.nodes():

        graph.node[n]['y'] = (graph.node[n]['visitid'] - 1) * 72

    # Determine an ordering of clusters.

    edge_lengths = collections.Counter()

    for edge in graph.edges(data=True):

        cluster1 = get_base_classification(edge[2]['sourcecluster'])

        cluster2 = get_base_classification(edge[2]['targetcluster'])

        if cluster1 != cluster2:

            weight = edge[2]['weight'] * 2**(
                graph.node[edge[2]['sourcecluster']]['visitid'] - 1)

            edge_lengths[cluster1, cluster2] += weight

            edge_lengths[cluster2, cluster1] += weight

    cluster_order = None

    for edge, _ in edge_lengths.most_common():

        if not cluster_order:

            cluster_order = list(edge)

        else:

            cluster1, cluster2 = edge

            if cluster1 in cluster_order and cluster2 in cluster_order:

                continue

            if cluster1 in cluster_order:

                cluster_order.insert(
                    cluster_order.index(cluster1) + 1, cluster2)

            elif cluster2 in cluster_order:

                cluster_order.insert(
                    cluster_order.index(cluster2) + 1, cluster1)

            else:

                cluster_order += list(edge)

    # Attach unassigned clusters, i.e., those with no connections.

    all_clusters = {
        graph.node[node]['clusterletter']
        for node in graph.nodes()
    }

    missing_nodes = sorted(all_clusters - set(cluster_order))

    cluster_order += missing_nodes

    # Then attach x-coordinates.

    for node in graph.nodes():

        graph.node[node]['x'] = cluster_order.index(graph.node[node][
            'clusterletter']) * 72

    return graph


def set_edge_transparencies(graph: nx.DiGraph) -> nx.DiGraph:
    """
    Sets edge transparencies.

    Edge transparencies are equal to `255 * sqrt(proportion)`.

    Args:
        graph: The graph to calculate edge transparencies for.

    Returns:
        The modified graph.
    """

    for edge in graph.edges():

        source, target = edge

        graph.edge[source][target]['transparency'] = 255. * graph.edge[source][
            target]['proportion']

    return graph


def set_node_shapes(graph: nx.DiGraph) -> nx.DiGraph:
    """
    Sets node shapes.

    Zero clusters are triangles, narrow clusters are circles, and broad
    clusters are diamonds.

    Args:
        graph: The graph to calculate shapes for.

    Returns:
        The modified graph.
    """

    for node in graph.nodes():

        label = graph.node[node]['clusterletter']

        if label == '--':

            graph.node[node]['shape'] = 'triangle'

        elif re.match(r'^\d', label):

            graph.node[node]['shape'] = 'ellipse'

        else:

            graph.node[node]['shape'] = 'diamond'

    return graph


def set_node_colours(graph: nx.DiGraph,
                     cluster_colours: Dict[str, str]) -> nx.DiGraph:
    """
    Sets node colours.

    Args:
        graph: The graph to calculate shapes for.
        cluster_colours: A mapping from clusters to colours.

    Returns:
        The modified graph.
    """

    for node in graph.nodes():

        graph.node[node]['colour'] = cluster_colours[graph.node[node][
            'clusterletter']]

    return graph


def write_output(graph: nx.DiGraph, path: str):
    """
    Writes the given graph to the given file.

    Args:
        graph: The graph to write.
        path: The path to write the graph to.
    """

    info('Writing output')

    nx.write_gml(graph, path)


@click.command()
@click.option(
    '--input',
    required=True,
    help='read patient group assignments from CSV file INPUT')
@click.option(
    '--all-input',
    required=True,
    help='read all possible patient group assignments from CSV file ALL_INPUT')
@click.option(
    '--chisq-input',
    required=True,
    help='read chi-square residual information from CHISQ_INPUT')
@click.option(
    '--output', required=True, help='write output to GML file OUTPUT')
@click.option(
    '--std-residual',
    type=float,
    default=1.96,
    help=('filter edges to those whose standard residual is at least '
          'STD_RESIDUAL'))
def main(input, all_input, chisq_input, output, std_residual):

    basicConfig(
        level=INFO,
        handlers=[
            StreamHandler(), FileHandler(
                '{}.log'.format(output), mode='w')
        ])

    info('Loading clusters')

    clusters = load_data(input)

    info('Loading all possible cluster assignments')

    all_clusters = load_data(all_input)

    info('Loading chi-square residual information from {}'.format(chisq_input))

    chisq_data = pd.read_csv(chisq_input)

    chisq_data.info()

    # Calculate cluster colours.

    info('Calculating cluster colours')

    cluster_colours = get_cluster_colours(all_clusters)

    # Determine the paths to display.

    info('Calculating paths to display')

    paths_to_show = get_paths_to_show(chisq_data, std_residual)

    path_counts = get_path_counts(clusters)

    consecutive_path_counts = get_consecutive_path_counts(path_counts)

    consecutive_path_counts = get_path_proportions(consecutive_path_counts)

    cluster_counts = get_cluster_counts(path_counts)

    graph = make_graph(cluster_counts, consecutive_path_counts, paths_to_show)

    # Arrange the graph.

    info('Arranging graph')

    graph = arrange_graph(graph)

    # Set edge transparencies.

    info('Setting edge transparencies')

    graph = set_edge_transparencies(graph)

    # Set colours for the nodes.

    info('Setting node colours')

    graph = set_node_colours(graph, cluster_colours)

    # Set shapes for the nodes.

    info('Setting node shapes')

    graph = set_node_shapes(graph)

    # Write the output.

    write_output(graph, output)


if __name__ == '__main__':
    main()
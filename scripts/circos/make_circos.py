"""
Creates files for a Circos figure.
"""

import argparse
import colorsys
import colour
import csv
import functools
import itertools
import logging
import operator
import os
import re
import string
import yaml

import numpy as np
import pandas as pd

from sklearn.decomposition import PCA

BASE_DIR = 'figures/circos'


def get_arguments():
    """
    Obtains command-line arguments.

    :rtype: argparse.Namespace
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--clusters',
        type=argparse.FileType('rU'),
        required=True,
        metavar='CLUSTERS',
        help='read cluster assignments from CSV file %(metavar)s')

    parser.add_argument(
        '--diagnoses',
        type=argparse.FileType('rU'),
        required=True,
        metavar='DIAGNOSES',
        help='read diagnoses from CSV file %(metavar)s')

    parser.add_argument(
        '--scores',
        type=argparse.FileType('rU'),
        required=True,
        metavar='SCORES',
        help='read scores from CSV file %(metavar)s')

    parser.add_argument(
        '--base-dir',
        required=True,
        metavar='BASE-DIR',
        help='output all files under directory %(metavar)s')

    parser.add_argument(
        '--diagnosis-order',
        type=argparse.FileType('rU'),
        metavar='DIAGNOSIS-ORDER',
        help='read the order of diagnoses from text file %(metavar)s')

    parser.add_argument(
        '--diagnosis-map',
        type=argparse.FileType('rU'),
        metavar='DIAGNOSIS-MAP',
        help='load diagnosis mappings from %(metavar)s')

    parser.add_argument(
        '--intraclassification-spacing',
        type=float,
        default=10.,
        metavar='INTRACLASSIFICATION-SPACING',
        help=('set the intraclassification spacing to %(metavar)s (default '
              '%(default)s)'))

    parser.add_argument(
        '--interclassification-spacing',
        type=float,
        default=50.,
        metavar='INTERCLASSIFICATION-SPACING',
        help=('set the interclassification spacing to %(metavar)s (default '
              '%(default)s)'))

    parser.add_argument(
        '--log',
        metavar='LOG',
        help='output logging information to %(metavar)s')

    return parser.parse_args()


def configure_logging(log=None):
    """
    Configures logging.

    :param str log
    """

    if log:

        logging.basicConfig(
            level=logging.DEBUG,
            filename=log,
            filemode='w',
            format='%(asctime)s %(levelname)-8s %(message)s')

        console = logging.StreamHandler()

        console.setLevel(logging.INFO)

        console.setFormatter(logging.Formatter('%(message)s'))

        logging.getLogger().addHandler(console)

    else:

        logging.basicConfig(level=logging.INFO, format='%(message)s')


def load_clusters(handle, **kwargs):
    """
    Loads cluster assignments from the given handle.

    :param io.file handle

    :rtype: pd.DataFrame
    """

    logging.info('Loading cluster assignments')

    result = pd.read_csv(handle, dtype={'classification': str}, **kwargs)

    # letter_map = pd.Series(['0'] + list(string.ascii_uppercase))

    # letter_map.index = list(range(0, 27))

    # result.classification = letter_map[result['classification']].tolist()

    logging.info('Loaded cluster assignments for {} patients'.format(
        *result.shape))

    return result


def load_diagnosis_map(handle):
    """
    Loads a diagnosis map from the given file.

    :param io.file handle

    :rtype: Dict[str, str]
    """

    if not handle:

        return {}

    logging.info('Loading diagnosis map')

    result = yaml.load(handle)

    logging.info('Loaded {} entries'.format(len(result)))

    return result


def load_diagnosis_order(handle, diagnosis_map):
    """
    Loads the order of diagnoses from the given file.

    :param io.file handle

    :param Dict[str, str] diagnosis_map

    :rtype: List[str]
    """

    if not handle:

        return []

    logging.info('Loading diagnosis order')

    result = yaml.load(handle)

    logging.info('Loaded {} entries'.format(len(result)))

    if diagnosis_map:

        return [diagnosis_map.get(x, x) for x in result]

    return result


def load_diagnoses(handle, diagnosis_map, **kwargs):
    """
    Loads diagnoses from the given file.

    :param io.file handle

    :param Dict[str, str] diagnosis_map

    :rtype: pd.DataFrame
    """

    logging.info('Loading diagnoses')

    result = pd.read_csv(handle, **kwargs).dropna(
        subset=['diagnosis'])[['diagnosis']]

    logging.info('Loaded diagnoses for {} patients'.format(*result.shape))

    # Then map the diagnoses if necessary.

    if diagnosis_map:

        logging.info('Mapping diagnoses')

        result.diagnosis = [
            diagnosis_map.get(x, x) for x in result['diagnosis']
        ]

    return result


def load_scores(handle, **kwargs):
    """
    Loads scores from the given handle.

    :param io.file handle

    :rtype: pd.DataFrame
    """

    logging.info('Loading scores')

    result = pd.read_csv(handle, **kwargs)

    logging.info('Loaded a {} x {} table of scores'.format(*result.shape))

    return result


def transform_scores(scores):
    """
    Transforms the given scores.

    :param pd.DataFrame scores

    :rtype: pd.DataFrame
    """

    logging.info('Transforming scores')

    return scores / scores.max()


def merge_data(data_frames):
    """
    Merges the given data frames by index.

    :param List[pd.DataFrame] data_frames

    :rtype: pd.DataFrame
    """

    logging.info('Merging data')

    merge_partial = functools.partial(
        pd.merge, left_index=True, right_index=True, how='inner')

    result = functools.reduce(merge_partial, data_frames)

    logging.info('Result is a {} x {} table'.format(*result.shape))

    return result


def get_sorted_clusters(clusters):
    """
    Obtains a sorted list of clusters.

    :param pd.DataFrame clusters

    :rtype List[str]
    """

    return sorted(clusters['classification'].unique())


def get_sorted_diagnoses(diagnoses, diagnosis_order=()):
    """
    Obtains a sorted list of diagnoses.

    :param pd.DataFrame diagnoses

    :param List[str] diagnosis_order

    :rtype: List[str]
    """

    if diagnosis_order:

        # Verify that all diagnoses are represented.

        bad_diagnoses = pd.np.setdiff1d(diagnosis_order,
                                        diagnoses['diagnosis'])

        if bad_diagnoses.shape[0] > 0:

            raise KeyError('diagnoses in sort order not present in data: {!r}'.
                           format(bad_diagnoses))

        bad_data_diagnoses = pd.np.setdiff1d(diagnoses['diagnosis'],
                                             diagnosis_order)

        if bad_data_diagnoses.shape[0] > 0:

            raise KeyError('diagnoses in data not present in sort order: {!r}'.
                           format(bad_data_diagnoses))

        return diagnosis_order

    return sorted(diagnoses['diagnosis'].unique())


def get_group_ids(labels, prefix):
    """
    Obtains a mapping from label to group ID.

    :param List[str] labels

    :param str prefix

    :rtype: pd.DataFrame
    """

    return pd.DataFrame({
        'label': labels,
        'id': [
            '{}__{}'.format(prefix, re.sub(r'[^a-z0-9_]', '_', k.lower()))
            for k in labels
        ]
    })


def map_ids_to_data(data, cluster_metadata, diagnosis_metadata):
    """
    Maps IDs in the given metadata to the given data.

    :param pd.DataFrame data

    :param pd.DataFrame cluster_metadata

    :param pd.DataFrame diagnosis_metadata
    """

    logging.info('Mapping internally generated IDs to the data')

    cluster_map = cluster_metadata.set_index('label')['id']

    diagnosis_map = diagnosis_metadata.set_index('label')['id']

    data['classification'] = cluster_map[data['classification']].tolist()

    data['diagnosis'] = diagnosis_map[data['diagnosis']].tolist()


def get_cluster_colours(cluster_metadata):
    """
    Adds colours for clusters.

    Colours will be shuffled so that no two adjacent colours appear alike.

    :param pd.DataFrame cluster_metadata
    """

    cluster_colours = np.vectorize(colorsys.hsv_to_rgb)(
        np.arange(0, 1, 1. / cluster_metadata.shape[0]), 0.75, 0.75)

    cluster_colours = [
        np.round(np.array(x) * 255).astype(int) for x in zip(*cluster_colours)
    ]

    cluster_colours = cluster_colours[0::2] + cluster_colours[1::2]

    cluster_metadata['colour'] = cluster_colours


def get_diagnosis_colours(diagnosis_metadata):
    """
    Adds shades of grey for clusters.

    :param pd.DataFrame diagnosis_metadata
    """

    diagnosis_colour_distance = 255. / (diagnosis_metadata.shape[0] + 1)

    diagnosis_colours = [
        np.round(np.tile(diagnosis_colour_distance * (i + 1), 3)).astype(int)
        for i in range(len(diagnosis_metadata))
    ]

    diagnosis_metadata['colour'] = diagnosis_colours


def get_diagnosis_karyotype(data, id, label):
    """
    Obtains karyotype information for the diagnosis specified by the given
    ID and label given the data.

    :param pd.DataFrame data

    :param str id

    :param str label

    :rtype: pd.Series
    """

    return pd.Series([
        'chr', '-', id, label, 0, (data['diagnosis'] == id).sum(),
        'colour_{}'.format(id)
    ]).to_frame().T


def get_cluster_karyotype(data, id, label):
    """
    Obtains karyotype information for the cluster specified by the given ID
    and label given the data.

    :param pd.DataFrame data

    :param str id

    :param str label

    :rtype: pd.Series
    """

    return pd.Series([
        'chr', '-', id, label, 0, (data['classification'] == id).sum(),
        'colour_{}'.format(id)
    ]).to_frame().T


def get_karyotype(data, cluster_metadata, diagnosis_metadata):
    """
    Obtains karyotype information.

    :param pd.DataFrame data

    :param pd.DataFrame cluster_metadata

    :param pd.DataFrame diagnosis_metadata

    :rtype: pd.DataFrame
    """

    diagnosis_karyotype = pd.concat(
        get_diagnosis_karyotype(data, row['id'], row['label'])
        for _, row in diagnosis_metadata.iterrows())

    cluster_karyotype = pd.concat(
        get_cluster_karyotype(data, row['id'], row['label'])
        for _, row in cluster_metadata.iloc[::-1].iterrows())

    result = pd.concat([diagnosis_karyotype, cluster_karyotype])

    result = result[result.iloc[:, 5] > 0]

    return result


def get_cluster_diagnosis_patients(data):
    """
    For each cluster and diagnosis, generates patient IDs that fall under
    both.

    :param pd.DataFrame data

    :rtype: pd.DataFrame
    """

    g = data.groupby(['classification', 'diagnosis'])

    return g.groups


def sort_patients(cluster_diagnosis_patients, data):
    """
    Sorts patients in cluster-diagnosis wedges using PCA on the given data.

    :parma Dict[Tuple[str, str], List[str]] cluster_diagnosis_patients

    :param pd.DataFrame data
    """

    logging.info('Sorting patients in cluster-diagnosis wedges')

    for cluster_diagnosis, pids in cluster_diagnosis_patients.items():

        if len(pids) > 1:

            pca_model = PCA(n_components=1)

            pca_model.fit(data.loc[pids])

            intersection_scores = pca_model.transform(data.loc[pids])

            sort_order = np.argsort(intersection_scores[:, 0])

            cluster_diagnosis_patients[cluster_diagnosis] = [
                pids[k] for k in sort_order
            ]


def get_ribbon_data(data, cluster_metadata, diagnosis_metadata,
                    cluster_diagnosis_patients):
    """
    Calculates ribbon positions.

    :param pd.DataFrame data

    :param pd.DataFrame cluster_metadata

    :param pd.DataFrame diagnosis_metadata

    :param Dict[Tuple[str, str], List[str]] cluster_diagnosis_patients

    :rtype: pd.DataFrame
    """

    current_positions = {
        x: 0
        for x in itertools.chain(cluster_metadata['id'], diagnosis_metadata[
            'id'])
    }

    for cluster in cluster_metadata['id']:

        current_positions[cluster] = (data['classification'] == cluster).sum()

    link_i = 0

    result_parts = []

    for diagnosis in diagnosis_metadata['id']:

        for cluster in cluster_metadata['id']:

            key = cluster, diagnosis

            if len(cluster_diagnosis_patients.get(key, [])) > 0:

                current_positions[cluster] -= len(cluster_diagnosis_patients[
                    key])

                cluster_start = current_positions[cluster]

                cluster_end = cluster_start + \
                    len(cluster_diagnosis_patients[key])

                diagnosis_start = current_positions[diagnosis]

                diagnosis_end = diagnosis_start + \
                    len(cluster_diagnosis_patients[key])

                result_parts.append(
                    pd.Series({
                        'link_id': 'link{:05d}'.format(link_i),
                        'cluster_id': cluster,
                        'cluster_start': cluster_start,
                        'cluster_end': cluster_end,
                        'diagnosis_id': diagnosis,
                        'diagnosis_start': diagnosis_start,
                        'diagnosis_end': diagnosis_end,
                        'ribbon_colour': 'colour_{}_a2'.format(cluster),
                        'cluster_colour': 'colour_{}'.format(cluster),
                        'diagnosis_colour': 'colour_{}'.format(diagnosis)
                    }).to_frame().T)

                current_positions[diagnosis] += len(cluster_diagnosis_patients[
                    key])

                link_i += 1

    return pd.concat(result_parts).reset_index(drop=True)


def get_ribbon_output_row(row):
    """
    Generates ribbon output for the given row.

    :param pd.DataFrame row

    :rtype: pd.DataFrame
    """

    return pd.DataFrame.from_items(
        [(0, [row['link_id']] * 2),
         (1, [row['cluster_id'], row['diagnosis_id']]),
         (2, [row['cluster_start'], row['diagnosis_start']]),
         (3, [row['cluster_end'], row['diagnosis_end']]),
         (4, ['color={}'.format(row['ribbon_colour'])] * 2)])


def get_ribbon_output(data):
    """
    Generates output ribbon data.

    :param pd.DataFrame data

    :rtype: pd.DataFrame
    """

    logging.info('Generating ribbon output')

    return pd.concat(get_ribbon_output_row(row) for _, row in data.iterrows())


def get_membership_output_row(row):
    """
    Generates membership output for the given row.

    :param pd.DataFrame row

    :rtype: pd.DataFrame
    """

    return pd.DataFrame.from_items(
        [(0, [row['cluster_id'], row['diagnosis_id']]),
         (1, [row['cluster_start'], row['diagnosis_start']]),
         (2, [row['cluster_end'], row['diagnosis_end']]), (3, [
             'fill_color=colour_{}'.format(row['diagnosis_id']),
             'fill_color=colour_{}'.format(row['cluster_id'])
         ])])


def get_membership_output(data):
    """
    Generates output membership data.

    :param pd.DataFrame data

    :rtype: pd.DataFrame
    """

    logging.info('Generating membership output')

    return pd.concat(
        get_membership_output_row(row) for _, row in data.iterrows())


def get_heatmap_data(data, cluster_metadata, diagnosis_metadata,
                     cluster_diagnosis_patients):
    """
    Calculates heat map data.

    :param pd.DataFrame data

    :param pd.DataFrame cluster_metadata

    :param pd.DataFrame diagnosis_metadata

    :param Dict[Tuple[str, str], List[str]] cluster_diagnosis_patients

    :rtype Dict[int, pd.DataFrame]
    """

    logging.info('Generating heat map data')

    scores = data.drop(['classification', 'diagnosis'], axis=1)

    scores /= scores.std()

    scores.fillna(0., inplace=True)

    current_positions = {
        x: 0
        for x in itertools.chain(cluster_metadata['id'], diagnosis_metadata[
            'id'])
    }

    for cluster in cluster_metadata['id']:

        current_positions[cluster] = (data['classification'] == cluster).sum()

    heatmap_parts = {
        int(re.sub(r'[^\d]', '', k)): list()
        for k in data.drop(
            ['classification', 'diagnosis'], axis=1).columns
    }

    for diagnosis in diagnosis_metadata['id']:

        for cluster in cluster_metadata['id']:

            key = cluster, diagnosis

            if len(cluster_diagnosis_patients.get(key, [])) > 0:

                for patient_id in cluster_diagnosis_patients[key]:

                    patient_scores = scores.loc[patient_id]

                    current_positions[cluster] -= 1

                    for k, score in patient_scores.iteritems():

                        k = int(re.sub(r'[^\d]', '', k))

                        heatmap_parts[k].append(
                            pd.DataFrame.from_items([(
                                'id', [cluster, diagnosis]), ('start', [
                                    current_positions[cluster],
                                    current_positions[diagnosis]
                                ]), ('end', [
                                    current_positions[cluster] + 1,
                                    current_positions[diagnosis] + 1
                                ]), ('score', [score] * 2)]))

                    current_positions[diagnosis] += 1

    return {
        k: pd.concat(v).reset_index(drop=True)
        for k, v in heatmap_parts.items()
    }


def get_path(filename):
    """
    Produces a path for the given filename.

    :param str filename

    :rtype: str
    """

    return os.path.join(BASE_DIR, filename)


def write_colours(filename, cluster_metadata, diagnosis_metadata):
    """
    Writes the given colours to the given filename.

    :param str filename

    :param Dict[str, str] cluster_metadata

    :param Dict[str, str] diagnosis_metadata
    """

    logging.info('Writing colours to {}'.format(filename))

    with open(filename, 'w') as handle:

        for i, row in itertools.chain(cluster_metadata.iterrows(),
                                      diagnosis_metadata.iterrows()):

            handle.write('colour_{} = {}\n'.format(row['id'], ','.join(row[
                'colour'].astype(str))))


def write_circos_conf(filename, cluster_metadata, diagnosis_metadata, n_pcs,
                      **kwargs):
    """
    Writes a circos.conf to the given filename.

    :param str filename

    :param pd.DataFrame cluster_metadata

    :param pd.DataFrame diagnosis_metadata

    :param int n_pcs
    """

    logging.info('Writing {}'.format(filename))

    colours = _get_indicator_colours()

    colour_definitions = '\n'.join(
        '{} = {}'.format(colour_id, code)
        for colour_id, code in sorted(colours.items()))

    with open(filename, 'w') as handle:

        handle.write(
            CIRCOS_CONF.format(
                first_cluster=cluster_metadata.iloc[0]['id'],
                last_cluster=cluster_metadata.iloc[-1]['id'],
                first_diagnosis=diagnosis_metadata.iloc[0]['id'],
                last_diagnosis=diagnosis_metadata.iloc[-1]['id'],
                label_radius_addition=(n_pcs + 2) * 0.025,
                colour_definitions=colour_definitions,
                **kwargs))


def write_karyotype(filename, karyotype):
    """
    Writes the given karyotype to the given file.

    :param str filename

    :param pd.DataFrame karyotype
    """

    logging.info('Writing karyotype to {}'.format(filename))

    karyotype.to_csv(
        filename,
        sep='\t',
        line_terminator='\n',
        quoting=csv.QUOTE_NONE,
        header=False,
        index=False)


def write_ribbons(filename, ribbon_output):
    """
    Writes the given ribbon output to the given file.

    :param str filename

    :param pd.DataFrame ribbon_output
    """

    logging.info('Writing ribbons to {}'.format(filename))

    ribbon_output.to_csv(
        filename, sep='\t', line_terminator='\n', header=False, index=False)


def write_memberships(filename, membership_output):
    """
    Writes the membership output.

    :param str filename

    :param pd.DataFrame membership_output
    """

    logging.info('Writing memberships to {}'.format(filename))

    membership_output.to_csv(
        filename, sep='\t', line_terminator='\n', header=False, index=False)


def write_heatmaps(heatmap_data):
    """
    Writes the heat map data.

    :param Dict[int, pd.DataFrame] heatmap_data
    """

    logging.info('Writing heat map data')

    for k, v in heatmap_data.items():

        filename = get_path('pc{}.txt'.format(k))

        v.to_csv(
            filename,
            sep='\t',
            line_terminator='\n',
            header=False,
            index=False)


def _format_colour(colour):
    """
    Formats the given colour as an RGB colour with values in the range [0,
    255].

    :param colour.Color colour

    :rtype: str
    """

    return ','.join(
        np.round(np.array(colour.rgb) * 255).astype(int).astype(str))


def _get_indicator_colours():
    """
    Obtains a colour gradient for indicator scores.

    Uses a modified scale consisting of green, yellow, orange, red, and purple.

    :rtype: Dict[str, str]
    """

    base_colours = [
        colour.Color(c)
        for c in ['#BFFFBF', '#FFFF8F', '#FFC760', '#FF3030', '#9F20F2']
    ]

    gradient_colours = (list(c1.range_to(c2, 7))[1:-1]
                        for c1, c2 in zip(base_colours[:-1], base_colours[1:]))

    merged_colours = ([c1] + grad
                      for c1, grad in zip(base_colours[:-1], gradient_colours))

    full_gradient = functools.reduce(
        operator.add, itertools.chain(merged_colours, [[base_colours[-1]]]))

    return {
        'heatmap_{:03d}'.format(i): _format_colour(c)
        for i, c in enumerate(full_gradient)
    }


def write_heatmap_configs(filename, n_pcs, min=0, max=1):
    """
    Writes heat map configuration files.

    :param str filename

    :param int n_pcs
    """

    colours = _get_indicator_colours()

    colour_names = ','.join(['white'] + sorted(colours.keys()))

    subconfs = [
        HEATMAPS_SUBCONF.format(
            k=k + 1,
            r0=1.0 + 0.025 * (n_pcs - k - 1),
            r1=1.0 + 0.025 * (n_pcs - k),
            min=min,
            max=max,
            color=colour_names) for k in range(n_pcs)
    ]

    with open(filename, 'w') as handle:

        handle.write(HEATMAPS_CONF.format(''.join(subconfs)))


CIRCOS_CONF = '''# circos.conf

# Basic parameters

file_delim* = \\t

################################################################
# The remaining content is standard and required. It is imported
# from default files in the Circos distribution.
#
# These should be present in every Circos configuration file and
# overridden as required. To see the content of these files,
# look in etc/ in the Circos distribution.

<image>
# Included from Circos distribution.
<<include etc/image.conf>>
</image>

# RGB/HSV color definitions, color lists, location of fonts, fill patterns.
# Included from Circos distribution.
<<include etc/colors_fonts_patterns.conf>>

# Debugging, I/O and other system parameters
# Included from Circos distribution.
<<include etc/housekeeping.conf>>

<colors>
<<include colours.conf>>
{colour_definitions}
</colors>

<links>
z = 0
radius = 0.975r
crest = 1
bezier_radius = 0.2r
bezier_radius_purity = 0.5
<link clustypes>
ribbon = yes
flat = yes
stroke_color = vdgrey
stroke_thickness = 2
file = ribbons.txt
</link>
</links>

# Karyotype

karyotype = karyotype.txt

<image>
24bit = yes
auto_alpha_colors = yes
auto_alpha_steps = 5
</image>

<ideogram>

label_color = black

show_label = yes
label_radius = dims(ideogram,radius) + {label_radius_addition}r
label_size = 36
label_parallel = no

<spacing>
default = {intraclassification_spacing}u
<pairwise {first_diagnosis};{first_cluster}>
spacing = {interclassification_spacing}u
</pairwise>
<pairwise {last_diagnosis};{last_cluster}>
spacing = {interclassification_spacing}u
</pairwise>
</spacing>

radius    = 0.8r
thickness = 0.1r
fill      = yes
stroke_color = black
stroke_thickness = 2p

</ideogram>

<highlights>
z = 0
<highlight>
file = memberships.txt
r0 = 0.975r
r1 = 1.000r
stroke_color = dgrey
stroke_thickness = 2
</highlight>
</highlights>

<<include heatmaps.conf>>
'''

HEATMAPS_CONF = r'''
<plots>
type = heatmap
# stroke_color = dgrey
stroke_thickness = 0
{}
</plots>
'''

HEATMAPS_SUBCONF = r'''<plot>
file = pc{k}.txt
color = {color}
min = {min}
max = {max}
r0 = {r0}r
r1 = {r1}r
stroke_thickness = 0
</plot>
'''

# XXX: The `colour` library has a buggy colour scale generation function.
# Colours fail to wrap around 0 or 360 degrees hue (that is, the shortest path
# isn't taken). This fix patches the broken function.


def color_scale(begin_hsl, end_hsl, nb):
    """Returns a list of nb color HSL tuples between begin_hsl and end_hsl

    >>> from colour import color_scale

    >>> [rgb2hex(hsl2rgb(hsl)) for hsl in color_scale((0, 1, 0.5),
    ...                                               (1, 1, 0.5), 3)]
    ['#f00', '#0f0', '#00f', '#f00']

    >>> [rgb2hex(hsl2rgb(hsl))
    ...  for hsl in color_scale((0, 0, 0),
    ...                         (0, 0, 1),
    ...                         15)]  # doctest: +ELLIPSIS
    ['#000', '#111', '#222', ..., '#ccc', '#ddd', '#eee', '#fff']

    Of course, asking for negative values is not supported:

    >>> color_scale((0, 1, 0.5), (1, 1, 0.5), -2)
    Traceback (most recent call last):
    ...
    ValueError: Unsupported negative number of colors (nb=-2).

    """

    if nb < 0:
        raise ValueError("Unsupported negative number of colors (nb=%r)." % nb)

    # The fix here is to use the smaller step size.

    step_h, step_s, step_l = 0., 0., 0.

    if nb > 0:
        dist_h = float(end_hsl[0] - begin_hsl[0])
        step_h = (dist_h if abs(dist_h) < 0.5 else
                  (-1 if dist_h > 0 else 1) + dist_h) / nb

        step_s = float(end_hsl[1] - begin_hsl[1]) / nb
        step_l = float(end_hsl[2] - begin_hsl[2]) / nb

    step = (step_h, step_s, step_l)

    def mul(step, value):
        return tuple([v * value for v in step])

    def add_v(step, step2):
        return tuple([v + step2[i] for i, v in enumerate(step)])

    def correct_h(hsl):
        h = hsl[0]
        new_h = h
        if h > 1.:
            new_h = new_h % 1.
        if h < 0.:
            new_h += 1.
        return (new_h, hsl[1], hsl[2])

    return [
        correct_h(add_v(begin_hsl, mul(step, r))) for r in range(0, nb + 1)
    ]


colour.color_scale = color_scale

if __name__ == '__main__':

    # Get arguments.

    args = get_arguments()

    # Configure logging.

    configure_logging(args.log)

    # Set the base directory.

    BASE_DIR = args.base_dir

    # Load the cluster assignments.

    clusters = load_clusters(args.clusters, index_col='subject_id')

    diagnosis_map = load_diagnosis_map(args.diagnosis_map)

    diagnosis_order = load_diagnosis_order(args.diagnosis_order, diagnosis_map)

    diagnoses = load_diagnoses(
        args.diagnoses, diagnosis_map, index_col='subject_id')

    scores = load_scores(args.scores, index_col=0)

    n_pcs = scores.shape[1]

    # Z-transform the scores.

    # scores = transform_scores(scores)

    # Merge the data.

    merged_data = merge_data([clusters, diagnoses, scores])

    # Define sort orders.

    sorted_clusters = get_sorted_clusters(clusters)

    sorted_diagnoses = get_sorted_diagnoses(diagnoses, diagnosis_order)

    # Generate IDs.

    cluster_metadata = get_group_ids(sorted_clusters, 'cluster')

    diagnosis_metadata = get_group_ids(sorted_diagnoses, 'diagnosis')

    # Map the IDs to the original data.

    map_ids_to_data(merged_data, cluster_metadata, diagnosis_metadata)

    # Obtain colours for the clusters and diagnoses.

    get_cluster_colours(cluster_metadata)

    get_diagnosis_colours(diagnosis_metadata)

    # Generate the karyotype table.

    karyotype = get_karyotype(merged_data, cluster_metadata,
                              diagnosis_metadata)

    # For each cluster assignment and diagnosis, generate the patient IDs that
    # fall under both.

    cluster_diagnosis_patients = get_cluster_diagnosis_patients(merged_data)

    # Sort each group using PCA.

    sort_patients(
        cluster_diagnosis_patients,
        merged_data.drop(
            ['classification', 'diagnosis'], axis=1))

    # Generate the ribbons.

    ribbon_data = get_ribbon_data(merged_data, cluster_metadata,
                                  diagnosis_metadata,
                                  cluster_diagnosis_patients)

    ribbon_output = get_ribbon_output(ribbon_data)

    membership_output = get_membership_output(ribbon_data)

    # Generate the heat maps.

    heatmap_data = get_heatmap_data(merged_data, cluster_metadata,
                                    diagnosis_metadata,
                                    cluster_diagnosis_patients)

    # Write out the output.

    write_colours(
        get_path('colours.conf'), cluster_metadata, diagnosis_metadata)

    write_circos_conf(
        get_path('circos.conf'),
        cluster_metadata,
        diagnosis_metadata,
        n_pcs,
        interclassification_spacing=args.interclassification_spacing,
        intraclassification_spacing=args.intraclassification_spacing)

    write_karyotype(get_path('karyotype.txt'), karyotype)

    write_ribbons(get_path('ribbons.txt'), ribbon_output)

    write_memberships(get_path('memberships.txt'), membership_output)

    write_heatmaps(heatmap_data)

    write_heatmap_configs(get_path('heatmaps.conf'), n_pcs)

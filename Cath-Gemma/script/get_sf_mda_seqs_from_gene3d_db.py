#!/usr/bin/env python3

# core
import argparse
import logging
import os
import sys

# include
import cx_Oracle

parser = argparse.ArgumentParser(
    description="Write CATH domain sequences (with MDA info)")

parser.add_argument('--dbname', type=str, default='gene3d_16', dest='tablespace',
    help='database name')

parser.add_argument('--out', '-o', type=str, dest='out_file', required=True,
    help='output file')

parser.add_argument('--sfam', '-s', type=str, dest='sfam_id', required=True,
    help='superfamily id (eg "3.30.1360.30")')

parser.add_argument('--evalue', '-e', type=str, default='0.001', dest='max_evalue',
    help='maximum evalue allowed for predicted CATH domain')

parser.add_argument('--verbose', '-v', required=False, action='count', default=0,
    help='more verbose logging')



class Segment(object):
    def __init__(self, start, stop):
        self.start = start
        self.stop = stop
    
    @classmethod
    def new_from_string(cls, segstr):
        start, stop = segstr.split('-')
        return cls(start, stop)

class Domain(object):
    def __init__(self, id, sfam_id, *, md5=None, mda=None, segments=None):
        self.id = id
        self.sfam_id = sfam_id
        self.md5 = md5
        self.mda = mda
        self.start = None

        if segments:
            if isinstance(segments, str):
                segs = []
                for segstr in segments.split(','):
                    seg = Segment.new_from_string(segstr)
                    segs.append(seg)
                segments = segs
            self.segments = segments
            self.start = segments[0].start

class Protein(object):
    def __init__(self, id, *, seq=None):
        self.id = id
        self.seq = seq
        self.domains = {}

    def to_mda_string(self):
        domains = sorted(self.domains.values(), key=lambda dom: dom.start)
        return '-'.join([d.sfam_id for d in domains])

class GenerateMdaSequences(object):
    """
    Generate CATH domain sequences for a superfamily (including MDA string).

    Note: the final MDA does not take into account discontiguous domains
    in that only the position of the first segment is noted.
    """

    def __init__(self, *, db_conn, sfam_id, uniprot_chunk_size=500):
        self.db_conn = db_conn
        self.sfam_id = sfam_id
        self.uniprot_chunk_size = uniprot_chunk_size
        self._proteins = {}

    def merge_proteins(self, proteins):
        for p in proteins.values():
            domains_to_merge = p.domains
            if p.id in self._proteins:
                p = self._proteins[p.id]
            else:
                self._proteins[p.id] = p
            
            for d in domains_to_merge.values():
                p.domains[d.id] = d

    def run(self):

        # get all the gene3d domains within a superfamily
        sfam_proteins = self.get_proteins_for_sfam(self.sfam_id)

        # merge the individual domains together into proteins
        self.merge_proteins(sfam_proteins)

        # get the unique uniprot ids
        uniq_uniprot_ids = set()
        for p in sfam_proteins.values():
            uniq_uniprot_ids.add(p.id)

        all_uniprot_ids = sorted(uniq_uniprot_ids)
        
        uniprot_from=0
        uniprot_chunk_size=self.uniprot_chunk_size

        def next_uniprot_ids():
            nonlocal uniprot_from
            nonlocal uniprot_chunk_size
            if uniprot_from >= len(all_uniprot_ids):
                return None, None, None
            uniprot_to = uniprot_from + uniprot_chunk_size
            if uniprot_to > len(all_uniprot_ids):
                uniprot_to = len(all_uniprot_ids) - 1
            uniprot_ids = all_uniprot_ids[uniprot_from:uniprot_to]
            uniprot_offset = uniprot_from
            uniprot_from += uniprot_chunk_size
            return uniprot_ids, uniprot_offset, uniprot_to

        # for the uniprot entries we've already seen, go get all 
        # the domains from all the other superfamilies
        while True:
            uniprot_ids, uni_from, uni_to = next_uniprot_ids()
            if not uniprot_ids:
                break
            logger.info("Annotating uniprot_ids {} to {}".format(uni_from, uni_to))
            proteins = self.get_proteins_for_uniprot_ids(uniprot_ids)

            # merge them back in
            self.merge_proteins(proteins)

    def get_mda_summary(self):
        """Returns a dict containing the number of occurences of each MDA."""
        mda_count = {}
        for p in self._proteins.values():
            mda = p.to_mda_string()
            if mda not in mda_count:
                mda_count[mda] = 0
            mda_count[mda] += 1
        return mda_count

    def count_domains(self):
        domain_count=0
        for p in self._proteins.values():
            domain_count += len(p.domains)
        return domain_count

    def write_to_file(self, out_filename):

        with open(out_filename, 'w') as fout:

            # print out the proteins
            for p in self._proteins.values():
                try:
                    mda = p.to_mda_string()
                except:
                    logger.error("failed to generate mda string for protein: {}".format(p.id))
                    raise
                seq = p.seq
                for d in p.domains.values():
                    fout.write("{}\n".format( "\t".join([ p.id, d.id, mda, seq ]) ) )

    def _segs_from_string(self, segs_str):
        return [(seg.split('-')) for seg in segs_str.split(',')]

    def get_proteins_for_uniprot_ids(self, uniprot_ids):
        
        cur = self.db_conn.cursor()
        
        placeholders = ','.join(':x{}'.format(i) for i,_ in enumerate(uniprot_ids))
        sequences_for_uniprot_sql = "{} WHERE uniprot_acc IN ({})".format(
            all_sequences_for_uniprot_sql, placeholders)

        proteins = self._proteins

        cur.execute(sequences_for_uniprot_sql, uniprot_ids)
        for result in cur:
            uniprot_acc, md5, sfam_id, resolved = (result)
            domain_id = '{}/{}'.format(md5, resolved)
            # segs = self._segs_from_string(resolved)
            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }
            dom = Domain(id=domain_id, sfam_id=sfam_id, segments=resolved)
            p = proteins[uniprot_acc]
            p.domains[domain_id] = dom

        return proteins

    def get_proteins_for_sfam(self, sfam_id):

        logger.info("Getting all proteins for superfamily {} ... ".format(sfam_id))

        proteins = self._get_proteins_for_sfam_sql(sequences_for_superfamily_sql, sfam_id=sfam_id)

        logger.info("Getting all 'extra' proteins for superfamily {} ... ".format(sfam_id))

        proteins_extra = self._get_proteins_for_sfam_sql(sequences_extra_for_superfamily_sql, sfam_id=sfam_id)

        proteins.update(proteins_extra)
    
        return proteins

    def _get_proteins_for_sfam_sql(self, sql, *, sfam_id):

        cur = self.db_conn.cursor()
        cur.prepare(sequences_for_superfamily_sql)

        proteins = {}

        record_count=0

        cur.execute(None, { 'sfam_id': sfam_id })
        for result in cur:
            uniprot_acc, md5, seq, resolved = (result)
            domain_id = '{}/{}'.format(md5, resolved)
            seq = seq.read()

            domain_id = '{}/{}'.format(md5, resolved)
            # segs = self._segs_from_string(resolved)
            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }
            dom = Domain(id=domain_id, sfam_id=sfam_id, segments=resolved)

            if uniprot_acc in proteins:
                p = proteins[uniprot_acc]
            else:
                p = Protein(uniprot_acc, seq=seq)
                proteins[uniprot_acc] = p

            p.domains[domain_id] = dom

            record_count += 1
            if record_count % 1000 == 0:
                logger.info("   ... processed {} domain records".format(record_count))

            # print( "{:<10s} {:<10s} {:<10s} {:<10s}".format(uniprot_acc, md5, resolved, seq) )

        logger.info(" ... got {} unique proteins".format(len(proteins)))

        return proteins

def _all_sequences_for_uniprot_sql(*, tablespace, max_evalue):
    return """
SELECT
    uniprot_acc, sequence_md5, sfam_id, resolved
FROM (
    SELECT
        u.accession     AS uniprot_acc,
        c.sequence_md5  AS sequence_md5,
        c.superfamily   AS sfam_id,
        c.resolved      AS resolved
    FROM
        {tablespace}.CATH_DOMAIN_PREDICTIONS_EXTRA c
    INNER JOIN
        {tablespace}.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
    WHERE
        c.independent_evalue < {evalue}
        AND
        c.superfamily IS NOT NULL
    UNION
    SELECT
        u.accession     AS uniprot_acc,
        c.sequence_md5  AS sequence_md5,
        c.superfamily   AS sfam_id,
        c.resolved      AS resolved
    FROM
        {tablespace}.CATH_DOMAIN_PREDICTIONS c
    INNER JOIN
        {tablespace}.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
    WHERE
        c.independent_evalue < {evalue}
        AND
        c.superfamily IS NOT NULL
)
""".format(tablespace=tablespace, evalue=max_evalue)

def _sequences_extra_for_superfamily_sql(*, tablespace, max_evalue):
    return """
SELECT
  u.accession     AS uniprot_acc,
  c.sequence_md5  AS sequence_md5,
  s.aa_sequence   AS sequence,
  c.resolved      AS resolved
FROM
  {tablespace}.CATH_DOMAIN_PREDICTIONS_EXTRA c
INNER JOIN
  {tablespace}.SEQUENCES_EXTRA         s ON c.sequence_md5 = s.sequence_md5
INNER JOIN
  {tablespace}.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
WHERE
  c.superfamily = :sfam_id
  AND
  s.source = 'uniref90'
  AND
  c.independent_evalue < {evalue}
""".format(tablespace=tablespace, evalue=max_evalue)

def _sequences_for_superfamily_sql(*, tablespace, max_evalue):
    return """
SELECT
  u.accession     AS uniprot_acc,
  c.sequence_md5  AS sequence_md5,
  s.aa_sequence   AS sequence,
  c.resolved      AS resolved
FROM
  {tablespace}.CATH_DOMAIN_PREDICTIONS c
INNER JOIN
  {tablespace}.SEQUENCES               s ON c.sequence_md5 = s.sequence_md5
INNER JOIN
  {tablespace}.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
WHERE
  c.superfamily = :sfam_id
  AND
  c.independent_evalue < {evalue}
""".format(tablespace=tablespace, evalue=max_evalue)


if __name__ == '__main__':
    args = parser.parse_args()

    log_level = logging.DEBUG if args.verbose > 0 else logging.INFO
    logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%y %H:%M:%S', level=log_level)
    logger = logging.getLogger(__name__)

    # https://gist.github.com/kimus/10012910

    dbuser="orengoreader"
    dbpass="orengoreader"
    dbhost="odb.cs.ucl.ac.uk"
    dbport=1521
    dbsid='cathora1'

    # 1.get all the uniprot accessions involved in this superfamily
    #
    # 2. for all of these uniprot accessions:
    #   - get all the cath domain predictions
    #   - get all the pfam domains?
    #
    # 3. build mda

    # TODO: sort out a proper ORM to avoid hard-coded SQL
    #       for the moment, it's encapsulated in functions..

    dbargs = { n: getattr(args, n) for n in ["tablespace", "max_evalue"] }

    all_sequences_for_uniprot_sql       = _all_sequences_for_uniprot_sql(**dbargs)
    sequences_extra_for_superfamily_sql = _sequences_extra_for_superfamily_sql(**dbargs)
    sequences_for_superfamily_sql       = _sequences_for_superfamily_sql(**dbargs)

    dsn=cx_Oracle.makedsn(dbhost, dbport, dbsid)
    conn=cx_Oracle.connect(user=dbuser, password=dbpass, dsn=dsn)

    sfam_id = args.sfam_id

    runner = GenerateMdaSequences(db_conn=conn, sfam_id=sfam_id)

    runner.run()

    logger.info("Getting MDA Summary...")
    mda_summary = runner.get_mda_summary()
    logger.info("Found {} unique MDAs".format(len(mda_summary)) )
    for mda, mda_count in sorted(mda_summary.items(), key=lambda kv: kv[1], reverse=True):
        logger.info("MDA_COUNT {:>7}  {}".format(mda_count, mda))

    logger.info("Writing {} domain sequences to {}".format(runner.count_domains(), args.out_file) )

    runner.write_to_file(args.out_file)

    conn.close()

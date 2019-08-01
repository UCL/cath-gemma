import logging
import os
import sys
import re

import numpy
import cx_Oracle

from cathpy.align import Sequence


SQUASH_SEGMENTS_MAX_GAP = 10

LOG = logging.getLogger(__name__)

def init_cli_logging(verbosity=0):
    log_level = logging.DEBUG if verbosity > 0 else logging.INFO
    logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%y %H:%M:%S', level=log_level)

class CathOraConnection(object):
    """Generates a connection to Oracle DB (with sensible defaults)"""
    def __init__(self, *, dbuser="orengoreader", dbpass="orengoreader", 
                 dbhost="odb.cs.ucl.ac.uk", dbport=1521, dbsid="cathora1"):
        dsn = cx_Oracle.makedsn(dbhost, dbport, dbsid)
        self._conn = cx_Oracle.connect(user=dbuser, password=dbpass, dsn=dsn)

    @property
    def conn(self):
        """Returns the database connection"""
        return self._conn

class GenerateUniprotFunfamLookup(object):

    _sql = """
SELECT DISTINCT 
    member_id, uniprot_id, funfam_id
FROM
(
    SELECT
        ff.member_id as member_id,
        u.uniprot_acc || '/' || SUBSTR(ff.member_id, INSTR(ff.member_id, '/', -1, 1) +1) as uniprot_id,
        ff.superfamily_id || '-ff-' || ff.funfam_number as funfam_id
    FROM 
        {tablespace}.funfam_member ff,
        {tablespace}.uniprot_description u
    WHERE
        ff.sequence_md5 = u.sequence_md5
        AND
        ff.superfamily_id = :sfam_id
)
ORDER BY
    uniprot_id
"""

    def __init__(self, *, db_conn, tablespace):
        self.db_conn = db_conn
        self.tablespace = tablespace

    @property
    def sql(self):
        return self._sql.format(tablespace=self.tablespace)

    def run(self, sfam_id):

        LOG.debug("Getting all proteins for superfamily %s ... ",sfam_id)
        cur = self.db_conn.cursor()
        cur.prepare(self.sql)

        db_args = {'sfam_id': sfam_id}
        LOG.debug("GenerateUniprotFunfamLookup: SQL: %s", self.sql.replace('\n', ' '))
        LOG.debug("GenerateUniprotFunfamLookup: ARGS: %s", db_args)

        #print("\t".join(["uniprot_member_id", "funfam_id"]))
        cur.execute(None, db_args)
        for result in cur:
            md5_member_id, uniprot_member_id, funfam_id = (result)
            print("\t".join([uniprot_member_id, funfam_id]))


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
        c.independent_evalue < {evalue:.2E}
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
        c.independent_evalue < {evalue:.2E}
        AND
        c.superfamily IS NOT NULL
)
""".format(tablespace=tablespace, evalue=float(max_evalue))

def _sequences_sql(*, tablespace, max_evalue, 
    sfam_ids=None, taxon_id=None, sequences_extra=False):

    extra_sql = '1=1'
    sequence_table = 'SEQUENCES'
    domain_table = 'CATH_DOMAIN_PREDICTIONS'

    if sequences_extra:
        sequence_table = 'SEQUENCES_EXTRA'
        domain_table = 'CATH_DOMAIN_PREDICTIONS_EXTRA'
        # HACK: yes, this is horrible
        if tablespace == 'gene3d_16':
            extra_sql = "s.source = 'uniref90'"

    sfam_sql = 'c.superfamily IS NOT NULL'
    if sfam_ids:
        sfam_bind_ids = [':sfam_id{}'.format(idx) for idx, sfam_id in enumerate(sfam_ids)]
        sfam_sql = 'c.superfamily IN ({})'.format(', '.join(sfam_bind_ids))

    taxon_sql = 'u.taxon_id IS NOT NULL'
    if taxon_id:
        taxon_sql = 'u.taxon_id = :taxon_id'

    return """
SELECT
  u.accession     AS uniprot_acc,
  c.sequence_md5  AS sequence_md5,
  c.superfamily   AS sfam_id,
  s.aa_sequence   AS sequence,
  c.resolved      AS resolved
FROM
  {tablespace}.{domain_table} c
INNER JOIN
  {tablespace}.{sequence_table}        s ON c.sequence_md5 = s.sequence_md5
INNER JOIN
  {tablespace}.UNIPROT_PRIM_ACC        u ON c.sequence_md5 = u.sequence_md5
WHERE
  {sfam_sql}
  AND
  {taxon_sql}
  AND
  {extra_sql}
  AND
  c.independent_evalue < {evalue:.2E}
""".format(
    tablespace=tablespace, 
    sequence_table=sequence_table, 
    domain_table=domain_table,
    evalue=float(max_evalue),
    sfam_sql=sfam_sql,
    taxon_sql=taxon_sql,
    extra_sql=extra_sql
)

class ArgumentError(Exception):
    pass

class Segment(object):
    def __init__(self, start, stop):
        self.start = int(start)
        self.stop = int(stop)
    
    @classmethod
    def new_from_string(cls, segstr):
        try:
            start, stop = segstr.split('-')
        except:
            raise Exception("failed to parse segment '{}'".format(segstr))

        return cls(start, stop)

    @classmethod
    def merge_segments(cls, segs, max_gap=SQUASH_SEGMENTS_MAX_GAP):
        """
        Merges segments together where the stop/start position is within `n` residues
        
        Note: this could be a class method (or moved elsewhere)
        """

        orig_segs = segs

        LOG.debug("  Squash segments START: %s", [str(s) for s in orig_segs])

        segs = sorted(segs, key=lambda s: s.start)

        seg_idx = 0
        while(True):
            seg = segs[seg_idx]

            if seg_idx + 1 < len(segs):
                next_seg = segs[seg_idx+1]
                gap = next_seg.start - seg.stop
                if gap < max_gap:
                    seg.stop = next_seg.stop
                    segs.pop(seg_idx+1)
                    continue
            else:
                break

            seg_idx += 1

        LOG.debug("  Squash segments END:   %s", [str(s) for s in segs])

        return segs

    def __str__(self):
        return '{}-{}'.format(self.start, self.stop)

    @classmethod
    def render_segments(cls, segs):
        return "_".join(['{}-{}'.format(s.start, s.stop) for s in segs])


class Domain(object):
    def __init__(self, domain_id, *, segments=None, sfam_ids=None):
        self.domain_id = domain_id
        if not sfam_ids:
            raise Exception("expected sfam_ids to be defined (mainly just because I want to check whether this exception is really required...)")
        
        self.sfam_ids = sfam_ids
        if not segments:
            segments = []
        self.segments = segments
        self.seq = None

    @property
    def mda_id(self):
        if not self.sfam_ids:
            return None
        return '-'.join(self.sfam_ids)

    @property
    def start_pos(self):
        if not self.segments:
            return None
        return self.segments[0].start

    @property
    def stop_pos(self):
        if not self.segments:
            return None
        return self.segments[-1].stop

    @property
    def segment_info(self):
        return Segment.render_segments(self.segments)

    def __str__(self):
        return "{}".format(self.domain_id)

    @classmethod
    def new_from_string(cls, domstr, *, sfam_ids=None):

        # 1cukA01
        # Q14119/172-201
        try:
            domain_id, segstr = domstr.split('/')
            segs = segstr.split('_')
        except:
            raise Exception("failed to parse domain '{}'".format(domstr))

        kwargs = {'domain_id': domain_id, 'segments': segs}
        if sfam_ids:
            kwargs['sfam_ids'] = sfam_ids

        dom = cls(**kwargs)
        return dom

class Protein(object):
    """
    Class representing a Protein
    """

    def __init__(self, protein_id, seq=None):
        self.protein_id = protein_id
        self.seq = seq
        self._domains = {}

    def to_mda_string(self):
        domains = sorted(self.domains, key=lambda dom: dom.start_pos)
        domain_ids = [d.mda_id if d.mda_id else 'unknown' for d in domains]
        return '-'.join(domain_ids)

    def remove_domain(self, dom):
        if isinstance(dom, Domain):
            domain_id = dom.domain_id
        else:
            domain_id = dom
        del self._domains[domain_id]

    def add_domain(self, dom):
        self._domains[dom.domain_id] = dom

    @property
    def domains(self):
        """Returns the (unordered) array of :class:`Domain` objects."""
        return list(self._domains.values())

    @property
    def domain_ids(self):
        """Returns the (unordered) array of domain ids."""
        return list(self._domains.keys())

    def merge_mda_domains(self, *, sfam_ids):
        """
        Merges domains that match the given MDA into a single record
        """

        domains = self.domains

        # sort the domains by position of first res
        domains.sort(key=lambda d: d.start_pos)

        current_mda_idx = 0
        current_mda_domains = []

        pid = self.protein_id
        pseq = self.seq

        for dom_idx, domain in enumerate(domains):

            if len(domain.sfam_ids) > 1:
                raise Exception("""
                Trying to merge MDA domains in a protein ({}) that looks like it has already been merged 
                (domain {} has more than one sfam_id: {}). Strictly speaking, this shouldn't be a problem - 
                though the logic will require some thinking through and until this is necessary, it's going 
                on the TODO pile.
                """.replace('\n', ' ').format(self, domain, domain.mda_id))

            sfam_id = None
            if domain.sfam_ids:
                sfam_id = domain.sfam_ids[0]
 
            expected_sfam_id = sfam_ids[current_mda_idx]

            # LOG.debug("Checking MDA: actual[%s]=%s expected[%s]=%s",
            #         dom_idx, sfam_id, current_mda_idx, expected_sfam_id)

            if sfam_id == expected_sfam_id:
                current_mda_domains.extend([domain])
                current_mda_idx += 1

                if current_mda_idx == len(sfam_ids):

                    LOG.debug(
                        "Found %s consecutive MDA domains in %s, creating sequence ...", len(sfam_ids), pid)

                    all_segs = []
                    for d in current_mda_domains:
                        all_segs.extend(d.segments)

                    all_segs.sort(key=lambda s: s.start)

                    squashed_segs = Segment.merge_segments(all_segs)

                    merged_domain_id = '{}/{}'.format(self.protein_id, Segment.render_segments(squashed_segs))
                    merged_domain = Domain(domain_id=merged_domain_id, segments=squashed_segs, sfam_ids=sfam_ids)

                    for dom in current_mda_domains:
                        self.remove_domain(dom)

                    self.add_domain(merged_domain)

                    current_mda_domains = []
                    current_mda_idx = 0

            else:
                current_mda_idx = 0

    def __str__(self):
        domains = sorted(self.domains, key=lambda dom: dom.start_pos)
        desc = "Protein: {} (seq len:{})".format(self.protein_id, len(self.seq) if self.seq else 'None')
        domain_lines = ["  {:<40} [{}]\n".format(d, d.mda_id if d.mda_id else 'unknown') for d in domains]
        desc += "".join(domain_lines)
        return desc

class MdaSummary(object):
    def __init__(self, *, mda, ref_mda_id):
        self.mda = mda
        self.ref_mda_id = ref_mda_id
        self.protein_count = 0
        self.ref_domains = []

    def add_protein(self, p):
        ref_mda_id = self.ref_mda_id
        
        sfam_domains = [d for d in p.domains if d.mda_id == ref_mda_id]

        for d in sfam_domains:
            seg_seqs = [p.seq[s.start-1:s.stop] for s in d.segments]
            d.seq = "".join(seg_seqs)

        self.protein_count += 1
        self.ref_domains.extend(sfam_domains)

    def append_domains_to_fasta(self, fasta_file):
        with open(fasta_file, 'a') as f:
            for d in self.ref_domains:
                f.write('>{}\n{}\n'.format(d.domain_id, d.seq))

    def domain_length_stats(self):
        domain_lengths = [len(d.seq) for d in self.ref_domains]
        stats = {
            "mean": numpy.mean(domain_lengths),
            "min": numpy.min(domain_lengths),
            "max": numpy.max(domain_lengths),
        }
        return stats

class GenerateMdaSequences(object):
    """
    Generate CATH domain sequences for a superfamily or taxon (including MDA string).

    Outputs the following directory structure:

    ::

        <PROJECT>/sequences/<SFAM-MDA-KEY>.seqs
        <PROJECT>/starting_clusters/<SFAM-MDA-KEY>/
        <PROJECT>/projects.txt
        <PROJECT>/mda_lookup.txt

    """

    PERM_NONE = False
    PERM_OVERWRITE = 'w'
    PERM_APPEND = 'a'

    DEFAULT_UNIPROT_CHUNK_SIZE=500

    def __init__(self, *,
        projects_fn='projects.txt',
        mda_fn='mda_lookup.txt',
        perm=PERM_NONE,
        db_conn, tablespace, max_evalue,
        sfam_ids=None, uniprot_file=None,
        taxon_id=None,
        nopartition=False,
        min_partition_size=None,
        uniprot_chunk_size=DEFAULT_UNIPROT_CHUNK_SIZE,
        max_rows=None):
        
        self.db_conn = db_conn
        self.projects_fn = projects_fn
        self.mda_fn = mda_fn
        self.sfam_ids = sfam_ids
        self.uniprot_file = uniprot_file
        self.taxon_id = taxon_id
        self.tablespace = tablespace
        self.max_evalue = max_evalue
        self.uniprot_chunk_size = uniprot_chunk_size
        self.file_perm = perm
        self.max_rows = max_rows
        self.min_partition_size = min_partition_size
        self.nopartition = nopartition

        self._proteins = {}

        dbargs = {"tablespace": tablespace, "max_evalue": max_evalue}

        self.all_sequences_for_uniprot_sql = _all_sequences_for_uniprot_sql(**dbargs)

        if self.sfam_ids:
            dbargs['sfam_ids'] = self.sfam_ids
        if self.taxon_id:
            dbargs['taxon_id'] = self.taxon_id

        self.sequences_sql       = _sequences_sql(**dbargs)
        self.sequences_extra_sql = _sequences_sql(**dbargs, sequences_extra=True)

    @property
    def ref_mda_id(self):
        if not self.sfam_ids:
            return None
        return '-'.join(self.sfam_ids)

    def run(self):

        # get a list of unique uniprot ids to use (from whatever input source)
        uniq_uniprot_ids = set()

        if self.uniprot_file:
            LOG.info("Getting all UniProtKB accs from file %s", self.uniprot_file)
            uniprot_ids = self.get_uniprot_accs_from_file(self.uniprot_file)
            for i in uniprot_ids:
                uniq_uniprot_ids.add(i)
        else:
            if self.sfam_ids:
                # get all the gene3d domains within a superfamily
                LOG.info("Getting all Gene3D domains within MDA: %s", self.ref_mda_id)
                all_proteins = self.get_proteins_for_sfams(sfam_ids=self.sfam_ids)
            elif self.taxon_id:
                LOG.info("Getting all Gene3D domains within taxon %s", self.taxon_id)
                all_proteins = self.get_proteins_for_taxon(self.taxon_id)
            else:
                raise ArgumentError("must specify: sfam_ids, taxon_id or uniprot_file")
            
            # merge the individual domains together into proteins
            # WHAT DOES THIS DO? DO WE NEED ALSO NEED TO DO THIS FOR THE UNIPROT ACCS???
            self.merge_proteins(all_proteins)

            for p in list(all_proteins.values()):
                uniq_uniprot_ids.add(p.protein_id)

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
            LOG.info("Annotating uniprot_ids {} to {}".format(uni_from, uni_to))
            proteins = self.get_proteins_for_uniprot_ids(uniprot_ids)

            # merge them back in
            self.merge_proteins(proteins)

        # we've got all the protein data for all occurrences of the individual
        # sfam ids. If we've asked for more than one sfam, then we need to:
        #   * merge the domain boundaries for the subset MDA
        #   * restrict the list to only include these proteins

        LOG.info("Merging MDAs domains ...")
        for p in self.proteins:
            p.merge_mda_domains(sfam_ids=self.sfam_ids)


    def write_project_files(self, base_dir):

        projects_file = os.path.join(base_dir, self.projects_fn)
        mda_file = os.path.join(base_dir, self.mda_fn)
        seq_file = os.path.join(base_dir, '{}-all.seq'.format(self.ref_mda_id))
        seqs_dir = os.path.join(base_dir, 'sequences')

        file_perm = self.file_perm
        if file_perm == self.PERM_NONE:
            file_perm = 'w'

        for out_file in [projects_file, mda_file, seq_file]:
            if os.path.isfile(out_file) and file_perm == self.PERM_NONE:
                raise IOError("Projects file '{}' exists and permission action is NONE (requires OVERWRITE or APPEND)".format(out_file))

        if not os.path.exists(base_dir):
            LOG.info("Creating base project directory: {}".format(base_dir))
            os.makedirs(base_dir)

        if not os.path.exists(seqs_dir):
            LOG.info("Creating seqs directory: {}".format(seqs_dir))
            os.makedirs(seqs_dir)

        if self.nopartition:
            LOG.info("Creating UNPARTITIONED summary")
            summary_by_mda = self.get_unpartitioned_summary()
        else:
            LOG.info("Creating PARTITIONED summary")
            summary_by_mda = self.get_mda_summary()

        projects = []
        project_index = 1
        all_mda_summaries = sorted(summary_by_mda.values(), key=lambda s: len(s.ref_domains), reverse=True)
        partitioned_mda_summaries = [s for s in all_mda_summaries if len(s.ref_domains) >= self.min_partition_size]
        bin_mda_summaries = [s for s in all_mda_summaries if len(s.ref_domains) < self.min_partition_size]

        def get_project_id(project_index=False, nopartition=False):
            return self.ref_mda_id if nopartition else '{}-mda-{}'.format(self.ref_mda_id, project_index)


        for mda_summary in partitioned_mda_summaries:
            domain_count = len(mda_summary.ref_domains)
            mda = mda_summary.mda
            
            dom_lengths = [len(d.seq) for d in mda_summary.ref_domains]
            len_mean = numpy.mean(dom_lengths)
            len_min = numpy.min(dom_lengths)
            len_max = numpy.max(dom_lengths)
            project = {
                'id': get_project_id(nopartition=self.nopartition, project_index=project_index),
                'mda_entries': [ mda ],
                'protein_count': mda_summary.protein_count,
                'domain_count': len(mda_summary.ref_domains),
                'index': project_index,
                'dom_len_min': len_min,
                'dom_len_max': len_max,
                'dom_len_mean': len_mean,
            }
            project_index += 1
            projects.extend([project])

        if bin_mda_summaries:
            dom_lengths = [len(d.seq) for d in mda_sum.ref_domains for mda_sum in bin_mda_summaries]
            len_mean = numpy.mean(dom_lengths)
            len_min = numpy.min(dom_lengths)
            len_max = numpy.max(dom_lengths)
 
            projects.extend([{
                'id': get_project_id(nopartition=self.nopartition, project_index=project_index),
                'mda_entries': [s.mda for s in bin_mda_summaries],
                'protein_count': sum([s.protein_count for s in bin_mda_summaries]),
                'domain_count': sum([len(s.ref_domains) for s in bin_mda_summaries]),
                'index': project_index,
                'dom_len_min': len_min,
                'dom_len_max': len_max,
                'dom_len_mean': len_mean,
            }])

        file_action = None
        if self.file_perm == self.PERM_NONE:
            file_action = "Writing"
        elif self.file_perm == self.PERM_APPEND:
            file_action = "Appending"
        elif self.file_perm == self.PERM_OVERWRITE:
            file_action = "Overwriting"

        LOG.info("%s project files ...", file_action)

        LOG.info("   %s", projects_file)

        with open(projects_file, file_perm) as f:
            for p in projects:
                f.write("{}\n".format(p['id']))

        LOG.info("   %s", mda_file)
        with open(mda_file, file_perm) as f:
            f.write("{:<30} {:<7} {:<7} {:<3} {} {}\n".format(
                'id', 'protein_count', 'domain_count', 'mda_count', 'min/max/mean', 'mda_entries'))
            for p in projects:
                f.write("{:<30} {:<7} {:<7} {:<3} {}/{}/{} {}\n".format(
                    p['id'], p['protein_count'], p['domain_count'], len(p['mda_entries']),
                    p['dom_len_min'], p['dom_len_max'], p['dom_len_mean'],
                    ",".join(p['mda_entries'])))

        LOG.info("   %s", seq_file)
        self.write_to_file(seq_file)

        for project in projects:
            fasta_file = os.path.join(seqs_dir, '{}.fasta'.format(project['id']))
            if os.path.isfile(fasta_file):
                raise IOError("fasta file {} already exists: cannot continue".format(fasta_file))
            LOG.info("   %s", fasta_file)
            for mda in project['mda_entries']:
                mda_summary = summary_by_mda[mda]
                mda_summary.append_domains_to_fasta(fasta_file)

    def merge_proteins(self, proteins):
        """
        Merges protein domains into the set of proteins already stored
        """
        for p in list(proteins.values()):
            domain_ids_to_merge = p.domains
            if p.protein_id in self._proteins:
                p = self._proteins[p.protein_id]
            else:
                self._proteins[p.protein_id] = p
            
            for d in domain_ids_to_merge:
                if d.domain_id not in p.domain_ids: # make sure we don't overwrite domains with sequences
                    p.add_domain(d)

    def get_chopped_sequence(self, full_sequence, segments):
        domain_seq = ''
        domain_length = sum([(int(s.stop) - int(s.start) + 1) for s in segments])

        # aln_seq = '-' * len(full_sequence)
        for seg in segments:
            domain_seq += full_sequence[int(seg.start)-1:int(seg.stop)]
            # aln_seq = '{}{}{}'.format(aln_seq[:int(seg.start)-1], domain_seq, aln_seq[int(seg.stop):])

        if domain_length != len(domain_seq):
            raise Exception( "expected domain length {} from segment info {}, actually got {} '{}'".format(
                domain_length, 
                ','.join(['{}-{}'.format(s.start, s.stop) for s in segments]),
                len(domain_seq), domain_seq
            ))

        # chopping_str = ",".join(["{}-{}".format(s.start,s.stop) for s in segments])
        # LOG.debug( "SEGMENTS: {}".format(chopping_str) )
        # LOG.debug( "PROTEIN:  {}".format(full_sequence) )
        # LOG.debug( "DOMAIN:   {}".format(aln_seq) )

        return domain_seq
    

    def get_mda_summary(self):
        """
        Returns a dict containing info about each MDA.
        """
        
        ref_mda_id = self.ref_mda_id

        summary_by_mda = {}
        for p in list(self._proteins.values()):
            mda_id = p.to_mda_string()
            if mda_id not in summary_by_mda:
                summary_by_mda[mda_id] = MdaSummary(mda=mda_id, ref_mda_id=ref_mda_id)
            
            summary = summary_by_mda[mda_id]
            summary.add_protein(p)
        return summary_by_mda

    @property
    def proteins(self):
        return list(self._proteins.values())

    def get_unpartitioned_summary(self):
        """
        Returns an equivalent dict without MDA partitioning.
        """
        
        ref_mda_id = '-'.join(self.sfam_ids)

        summary_by_mda = {}
        for p in self.proteins:
            # index by the reference MDA, not the full MDA of the protein
            if ref_mda_id not in summary_by_mda:
                summary_by_mda_id[ref_mda_id] = MdaSummary(mda=ref_mda_id, ref_mda_id=ref_mda_id)
            
            summary = summary_by_mda[ref_mda_id]
            summary.add_protein(p)
        return summary_by_mda


    def count_domains(self):
        domain_count=0
        for p in self.proteins:
            domain_count += len(p.domains)
        return domain_count

    def write_to_file(self, out_filename):
            

        with open(out_filename, 'w') as fout:

            # print out the domains in this superfamily
            for p in self.proteins:
                try:
                    mda = p.to_mda_string()
                except:
                    LOG.error("failed to generate mda string for protein: {}".format(p.protein_id))
                    raise
                
                if self.ref_mda_id:
                    domains = [d for d in p.domains if d.mda_id == self.ref_mda_id]
                else:
                    domains = [d for d in p.domains]

                for d in domains:
                    try:
                        dom_seq = self.get_chopped_sequence(p.seq, d.segments)
                    except:
                        raise Exception("failed to chop segments {} from protein {}".format(d, p))
                    
                    fout.write("{}\n".format("\t".join([ p.protein_id, d.domain_id, mda, dom_seq])))

    def get_uniprot_accs_from_file(self, uniprot_file):

        uniprot_accs = []
        re_uniprot = re.compile(r'(\w+)\b')
        currentline = 0
        with open(uniprot_file, 'r') as uniprot_io:
            for line in uniprot_io:
                currentline += 1
                if line.startswith('#'):
                    continue
                uni_result = re_uniprot.match(line)
                if uni_result:
                    uniprot_accs.extend([uni_result.group(1)])
                else:
                    raise Exception("failed to parse UniProtKB accession from line '{}' ({}: line {})".format(
                        line.strip(), uniprot_file, currentline
                    ))
        
        return uniprot_accs


    def get_proteins_for_uniprot_ids(self, uniprot_ids):
        
        cur = self.db_conn.cursor()
        
        placeholders = ','.join(':x{}'.format(i) for i,_ in enumerate(uniprot_ids))
        sequences_for_uniprot_sql = "{} WHERE uniprot_acc IN ({})".format(
            self.all_sequences_for_uniprot_sql, placeholders)

        proteins = self._proteins

        cur.execute(sequences_for_uniprot_sql, uniprot_ids)
        for result in cur:
            uniprot_acc, md5, sfam_id, resolved = (result)
            resolved = resolved.replace(',', '_')
            domain_id = '{}/{}'.format(uniprot_acc, resolved)
            segs = self._segs_from_string(resolved)
            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }
            p = proteins[uniprot_acc]
            dom = Domain(domain_id=domain_id, sfam_ids=[sfam_id], segments=segs)

            if domain_id not in p.domains: # do not overwrite existing domains (ie with sequence data)
                p.add_domain(dom)

        return proteins

    def get_proteins_for_sfams(self, sfam_ids):

        LOG.info("Getting all proteins for superfamily {} ... ".format('-'.join(sfam_ids)))

        proteins = self._get_proteins_sql(self.sequences_sql, sfam_ids=sfam_ids)

        LOG.info("Getting all 'extra' proteins for superfamily {} ... ".format(sfam_ids))

        proteins_extra = self._get_proteins_sql(self.sequences_extra_sql, sfam_ids=sfam_ids)

        proteins.update(proteins_extra)

        return proteins

    def get_proteins_for_taxon(self, taxon_id):

        LOG.info("Getting all proteins for taxon {} ... ".format(taxon_id))

        proteins = self._get_proteins_sql(self.sequences_sql, taxon_id=taxon_id)

        LOG.info("Getting all 'extra' proteins for taxon {} ... ".format(taxon_id))

        proteins_extra = self._get_proteins_sql(self.sequences_extra_sql, taxon_id=taxon_id)

        proteins.update(proteins_extra)

        return proteins

    def _segs_from_string(self, segments_string):

        re_split_segs = re.compile(r'[,_]')

        segs = []
        for segstr in re_split_segs.split(segments_string):
            seg = Segment.new_from_string(segstr)
            segs.append(seg)

        return segs

    def _get_proteins_sql(self, sql, *, sfam_ids=None, taxon_id=None):

        max_rows = self.max_rows

        cur = self.db_conn.cursor()
        cur.prepare(sql)

        proteins = {}

        record_count=0

        db_args = {}
        if not sfam_ids and not taxon_id:
            raise ArgumentError("must specify at least one of ['sfam_ids' | 'taxon_id']")
        if sfam_ids:
            for idx, sfam_id in enumerate(sfam_ids):
                bind_var = 'sfam_id{}'.format(idx)
                db_args[bind_var] = sfam_id
        if taxon_id:
            db_args['taxon_id'] = taxon_id

        LOG.debug("proteins_sql: %s %s", sql, db_args)

        cur.execute(None, db_args)
        for result in cur:
            uniprot_acc, md5, dom_sfam_id, seq, resolved = (result)
            seq = seq.read()
            resolved = resolved.replace(',', '_')
            domain_id = '{}/{}'.format(uniprot_acc, resolved)

            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }

            if uniprot_acc in proteins:
                p = proteins[uniprot_acc]
            else:
                p = Protein(uniprot_acc, seq=seq)
                proteins[uniprot_acc] = p

            segs = self._segs_from_string(resolved)
            dom = Domain(domain_id=domain_id, sfam_ids=[dom_sfam_id], segments=segs)

            p.add_domain(dom)

            record_count += 1
            if record_count % 1000 == 0:
                LOG.info("   ... processed {} domain records".format(record_count))

            if max_rows and record_count >= max_rows:
                LOG.info("   ... reached max_rows={} (quitting search early)".format(max_rows))
                break

            # LOG.debug( "{:<10s} {:<10s} {:<10s} {}".format(uniprot_acc, md5, resolved, dom_seq) )

        LOG.info(" ... got {} unique proteins".format(len(proteins)))

        return proteins

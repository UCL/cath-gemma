import logging
import os
import sys
import re

import cx_Oracle

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
SELECT
  ff.member_id,
  u.uniprot_acc || '/' || SUBSTR(ff.member_id, INSTR(ff.member_id, '/', -1, 1) +1),
  ff.superfamily_id || '-ff-' || ff.funfam_number
FROM 
  {tablespace}.funfam_member ff,
  {tablespace}.uniprot_description u
WHERE
  ff.sequence_md5 = u.sequence_md5
  AND
  ff.superfamily_id = :sfam_id
ORDER BY
  u.uniprot_acc
"""

    def __init__(self, *, db_conn, tablespace):
        self.db_conn = db_conn
        self.tablespace = tablespace

    @property
    def sql(self):
        return self._sql.format(tablespace=self.tablespace)

    def run(self, sfam_id):

        LOG.debug("Getting all proteins for superfamily {} ... ".format(sfam_id))
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
    sfam_id=None, taxon_id=None, sequences_extra=False):

    extra_sql = '1=1'
    sequence_table = 'SEQUENCES'
    domain_table = 'CATH_DOMAIN_PREDICTIONS'

    if sequences_extra:
        sequence_table = 'SEQUENCES_EXTRA'
        domain_table = 'CATH_DOMAIN_PREDICTIONS_EXTRA'
        extra_sql = "s.source = 'uniref90'"
    
    sfam_sql = 'c.superfamily IS NOT NULL'
    if sfam_id:
        sfam_sql = 'c.superfamily = :sfam_id'
    
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

class Domain(object):
    def __init__(self, id, sfam_id, *, segments):
        self.id = id
        self.sfam_id = sfam_id
        self.segments = segments
        self.start = segments[0].start
        self.seq = None

        if not sfam_id:
            raise Exception("Error: expected sfam_id to be defined")

    @property
    def segment_info(self):
        return "_".join(['{}-{}'.format(s.start, s.stop) for s in self.segments])

    def __str__(self):
        return "{}".format(self.id)

    @classmethod
    def new_from_string(cls, domstr, *, sfam_id=None):

        # 1cukA01
        # Q14119/172-201
        try:
            id, segstr = domstr.split('/')
            segs = segstr.split('_')

        except:
            raise Exception("failed to parse domain '{}'".format(domstr))



        dom = cls()

class Protein(object):
    def __init__(self, id, seq=None):
        self.id = id
        self.seq = seq
        self.domains = {}

    def to_mda_string(self):
        domains = sorted(self.domains.values(), key=lambda dom: dom.start)
        domain_ids = [d.sfam_id if d.sfam_id else 'unknown' for d in domains]
        return '-'.join(domain_ids)

    def __str__(self):
        domains = sorted(self.domains.values(), key=lambda dom: dom.start)
        desc = "Protein: {} (seq len:{})".format(self.id, len(self.seq) if self.seq else 'None')
        desc += "\n".join(["  {:<40} [{}]".format(d, d.sfam_id) for d in domains])
        return desc

class MdaSummary(object):
    def __init__(self, *, mda, ref_sfam_id):
        self.mda = mda
        self.ref_sfam_id = ref_sfam_id
        self.protein_count = 0
        self.ref_domains = []

    def add_protein(self, p):
        ref_sfam_id = self.ref_sfam_id
        
        sfam_domains = [d for d in p.domains.values() if d.sfam_id == ref_sfam_id]

        for d in sfam_domains:
            seg_seqs = [p.seq[s.start-1:s.stop] for s in d.segments]
            d.seq = "".join(seg_seqs)

        self.protein_count += 1
        self.ref_domains.extend(sfam_domains)

    def append_domains_to_fasta(self, fasta_file):
        with open(fasta_file, 'a') as f:
            for d in self.ref_domains:
                f.write('>{}\n{}\n'.format(d.id, d.seq))

"""
<PROJECT>/sequences/<SFAM-MDA-KEY>.seqs
<PROJECT>/starting_clusters/<SFAM-MDA-KEY>/
<PROJECT>/projects.txt
<PROJECT>/mda_lookup.txt
"""

class GenerateMdaSequences(object):
    """
    Generate CATH domain sequences for a superfamily or taxon (including MDA string).

    Note: the final MDA does not take into account discontiguous domains
    in that only the position of the first segment is noted.
    """

    PERM_NONE = False
    PERM_OVERWRITE = 'w'
    PERM_APPEND = 'a'

    DEFAULT_UNIPROT_CHUNK_SIZE=500

    def __init__(self, *,
        projects_fn='projects.txt',
        mda_fn='mda_lookup.txt', 
        perm=PERM_NONE,
        db_conn, tablespace, max_evalue, sfam_id,
        taxon_id=None,
        nopartition=False,
        min_partition_size=None, 
        uniprot_chunk_size=DEFAULT_UNIPROT_CHUNK_SIZE, 
        max_rows=None):
        
        self.db_conn = db_conn
        self.projects_fn = projects_fn
        self.mda_fn = mda_fn
        self.sfam_id = sfam_id
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

        if self.sfam_id:
            dbargs['sfam_id'] = self.sfam_id
        if self.taxon_id:
            dbargs['taxon_id'] = self.taxon_id

        self.sequences_sql       = _sequences_sql(**dbargs)
        self.sequences_extra_sql = _sequences_sql(**dbargs, sequences_extra=True)

    def run(self):

        if self.sfam_id:
            # get all the gene3d domains within a superfamily
            LOG.info("Getting all Gene3D domains within superfamily %s", self.sfam_id)
            all_proteins = self.get_proteins_for_sfam(self.sfam_id)
        elif self.taxon_id:
            LOG.info("Getting all Gene3D domains within taxon %s", self.taxon_id)
            all_proteins = self.get_proteins_for_taxon(self.taxon_id)
        else:
            raise ArgumentError("must specify either sfam_id or taxon_id")

        # merge the individual domains together into proteins
        self.merge_proteins(all_proteins)

        # get the unique uniprot ids
        uniq_uniprot_ids = set()
        for p in all_proteins.values():
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
            LOG.info("Annotating uniprot_ids {} to {}".format(uni_from, uni_to))
            proteins = self.get_proteins_for_uniprot_ids(uniprot_ids)

            # merge them back in
            self.merge_proteins(proteins)

    def write_project_files(self, base_dir):

        projects_file = os.path.join(base_dir, self.projects_fn)
        mda_file = os.path.join(base_dir, self.mda_fn)
        seq_file = os.path.join(base_dir, '{}-all.seq'.format(self.sfam_id))
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
            return self.sfam_id if nopartition else '{}-mda-{}'.format(self.sfam_id, project_index)


        for mda_summary in partitioned_mda_summaries:
            domain_count = len(mda_summary.ref_domains)
            mda = mda_summary.mda
            project = {
                'id': get_project_id(nopartition=self.nopartition, project_index=project_index),
                'mda_entries': [ mda ],
                'protein_count': mda_summary.protein_count,
                'domain_count': len(mda_summary.ref_domains),
                'index': project_index,
            }
            project_index += 1
            projects.extend([project])

        if bin_mda_summaries:
            projects.extend([{
                'id': get_project_id(nopartition=self.nopartition, project_index=project_index),
                'mda_entries': [s.mda for s in bin_mda_summaries],
                'protein_count': sum([s.protein_count for s in bin_mda_summaries]),
                'domain_count': sum([len(s.ref_domains) for s in bin_mda_summaries]),
                'index': project_index,
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
            f.write("{:<30} {:<7} {:<7} {:<3} {}\n".format(
                'id', 'protein_count', 'domain_count', 'mda_count', 'mda_entries'))
            for p in projects:
                f.write("{:<30} {:<7} {:<7} {:<3} {}\n".format(
                    p['id'], p['protein_count'], p['domain_count'], len(p['mda_entries']), ",".join(p['mda_entries'])))

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
        for p in proteins.values():
            domains_to_merge = p.domains
            if p.id in self._proteins:
                p = self._proteins[p.id]
            else:
                self._proteins[p.id] = p
            
            for d in domains_to_merge.values():
                if d.id not in p.domains: # make sure we don't overwrite domains with sequences
                    p.domains[d.id] = d

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
    
    def get_unpartitioned_summary(self):
        """Returns an equivalent dict without MDA partitioning."""
        sfam_id = self.sfam_id

        summary_by_sfam_id = {}
        for p in self._proteins.values():
            if sfam_id not in summary_by_sfam_id:
                summary_by_sfam_id[sfam_id] = MdaSummary(mda=sfam_id, ref_sfam_id=sfam_id)
            
            summary = summary_by_sfam_id[sfam_id]
            summary.add_protein(p)
        return summary_by_sfam_id


    def get_mda_summary(self):
        """Returns a dict containing info about each MDA."""
        ref_sfam_id = self.sfam_id

        summary_by_mda = {}
        for p in self._proteins.values():
            mda = p.to_mda_string()
            if mda not in summary_by_mda:
                summary_by_mda[mda] = MdaSummary(mda=mda, ref_sfam_id=ref_sfam_id)
            
            summary = summary_by_mda[mda]
            summary.add_protein(p)
        return summary_by_mda

    def count_domains(self):
        domain_count=0
        for p in self._proteins.values():
            domain_count += len(p.domains)
        return domain_count

    def write_to_file(self, out_filename):

        with open(out_filename, 'w') as fout:

            # print out the domains in this superfamily
            for p in self._proteins.values():
                try:
                    mda = p.to_mda_string()
                except:
                    LOG.error("failed to generate mda string for protein: {}".format(p.id))
                    raise
                
                if self.sfam_id:
                    domains = [d for d in p.domains.values() if d.sfam_id == self.sfam_id]
                else:
                    domains = [d for d in p.domains.values()]

                for d in domains:
                    try:
                        dom_seq = self.get_chopped_sequence(p.seq, d.segments)
                    except:
                        raise Exception("failed to chop segments {} from protein {}".format(d, p))
                    
                    fout.write("{}\n".format( "\t".join([ p.id, d.id, mda, dom_seq]) ) )

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
            dom = Domain(id=domain_id, sfam_id=sfam_id, segments=segs)

            if domain_id not in p.domains: # do not overwrite existing domains (ie with sequence data)
                p.domains[domain_id] = dom

        return proteins

    def get_proteins_for_sfam(self, sfam_id):

        LOG.info("Getting all proteins for superfamily {} ... ".format(sfam_id))

        proteins = self._get_proteins_sql(self.sequences_sql, sfam_id=sfam_id)

        LOG.info("Getting all 'extra' proteins for superfamily {} ... ".format(sfam_id))

        proteins_extra = self._get_proteins_sql(self.sequences_extra_sql, sfam_id=sfam_id)

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

    def _get_proteins_sql(self, sql, *, sfam_id=None, taxon_id=None):

        max_rows = self.max_rows

        cur = self.db_conn.cursor()
        cur.prepare(sql)

        proteins = {}

        record_count=0

        db_args = {}
        if not sfam_id and not taxon_id:
            raise ArgumentError("must specify at least one of ['sfam_id' | 'taxon_id']")
        if sfam_id:
            db_args['sfam_id'] = sfam_id
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
            dom = Domain(id=domain_id, sfam_id=dom_sfam_id, segments=segs)

            p.domains[domain_id] = dom

            record_count += 1
            if record_count % 1000 == 0:
                LOG.info("   ... processed {} domain records".format(record_count))

            if max_rows and record_count >= max_rows:
                LOG.info("   ... reached max_rows={} (quitting search early)".format(max_rows))
                break

            # LOG.debug( "{:<10s} {:<10s} {:<10s} {}".format(uniprot_acc, md5, resolved, dom_seq) )

        LOG.info(" ... got {} unique proteins".format(len(proteins)))

        return proteins

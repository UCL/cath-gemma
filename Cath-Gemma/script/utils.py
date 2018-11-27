import logging
import os
import sys
import re

logger = logging.getLogger(__name__)


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


class Segment(object):
    def __init__(self, start, stop):
        self.start = start
        self.stop = stop
    
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

    @property
    def segment_info(self):
        return ",".join(['{}-{}'.format(s.start, s.stop) for s in self.segments])

    def __str__(self):
        return "{}".format(self.id)

class Protein(object):
    def __init__(self, id, seq=None):
        self.id = id
        self.seq = seq
        self.domains = {}

    def to_mda_string(self):
        domains = sorted(self.domains.values(), key=lambda dom: dom.start)
        return '-'.join([d.sfam_id for d in domains])

    def __str__(self):
        domains = sorted(self.domains.values(), key=lambda dom: dom.start)
        desc = "Protein: {} (seq len:{})".format(self.id, len(self.seq) if self.seq else 'None')
        desc += "\n".join(["  {:<40} [{}]".format(d, d.sfam_id) for d in domains])
        return desc

class GenerateMdaSequences(object):
    """
    Generate CATH domain sequences for a superfamily or taxon (including MDA string).

    Note: the final MDA does not take into account discontiguous domains
    in that only the position of the first segment is noted.
    """

    def __init__(self, *, db_conn, tablespace, max_evalue, taxon_id=None, sfam_id=None, 
        uniprot_chunk_size=500, ):
        self.db_conn = db_conn
        self.sfam_id = sfam_id
        self.taxon_id = taxon_id
        self.tablespace = tablespace
        self.max_evalue = max_evalue
        self.uniprot_chunk_size = uniprot_chunk_size
        self._proteins = {}

        dbargs = {"tablespace": tablespace, "max_evalue": max_evalue} 
        self.all_sequences_for_uniprot_sql       = _all_sequences_for_uniprot_sql(**dbargs)
        self.sequences_extra_for_superfamily_sql = _sequences_extra_for_superfamily_sql(**dbargs)
        self.sequences_for_superfamily_sql       = _sequences_for_superfamily_sql(**dbargs)

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
        # logger.debug( "SEGMENTS: {}".format(chopping_str) )
        # logger.debug( "PROTEIN:  {}".format(full_sequence) )
        # logger.debug( "DOMAIN:   {}".format(aln_seq) )

        return domain_seq


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

            # print out the domains in this superfamily
            for p in self._proteins.values():
                try:
                    mda = p.to_mda_string()
                except:
                    logger.error("failed to generate mda string for protein: {}".format(p.id))
                    raise
                
                sfam_domains = [d for d in p.domains.values() if d.sfam_id == self.sfam_id]

                for d in sfam_domains:
                    try:
                        dom_seq = self.get_chopped_sequence(p.seq, d.segments)
                    except:
                        raise Exception("failed to chop segments {} from protein {}".format(d, p))
                    
                    fout.write("{}\n".format( "\t".join([ p.id, d.id, mda, dom_seq]) ) )

    def get_proteins_for_uniprot_ids(self, uniprot_ids):
        
        cur = self.db_conn.cursor()
        
        placeholders = ','.join(':x{}'.format(i) for i,_ in enumerate(uniprot_ids))
        sequences_for_uniprot_sql = "{} WHERE uniprot_acc IN ({})".format(
            all_sequences_for_uniprot_sql, placeholders)

        proteins = self._proteins

        cur.execute(sequences_for_uniprot_sql, uniprot_ids)
        for result in cur:
            uniprot_acc, md5, sfam_id, resolved = (result)
            resolved = resolved.replace(',', '_')
            domain_id = '{}/{}'.format(md5, resolved)
            segs = self._segs_from_string(resolved)
            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }
            p = proteins[uniprot_acc]
            dom = Domain(id=domain_id, sfam_id=sfam_id, segments=segs)

            if domain_id not in p.domains: # do not overwrite existing domains (ie with sequence data)
                p.domains[domain_id] = dom

        return proteins

    def get_proteins_for_sfam(self, sfam_id):

        logger.info("Getting all proteins for superfamily {} ... ".format(sfam_id))

        proteins = self._get_proteins_for_sfam_sql(sequences_for_superfamily_sql, sfam_id=sfam_id)

        logger.info("Getting all 'extra' proteins for superfamily {} ... ".format(sfam_id))

        proteins_extra = self._get_proteins_for_sfam_sql(sequences_extra_for_superfamily_sql, sfam_id=sfam_id)

        proteins.update(proteins_extra)

        return proteins

    def _segs_from_string(self, segments_string):

        re_split_segs = re.compile(r'[,_]')

        segs = []
        for segstr in re_split_segs.split(segments_string):
            seg = Segment.new_from_string(segstr)
            segs.append(seg)

        return segs

    def _get_proteins_for_sfam_sql(self, sql, *, sfam_id):

        cur = self.db_conn.cursor()
        cur.prepare(sequences_for_superfamily_sql)

        proteins = {}

        record_count=0

        cur.execute(None, { 'sfam_id': sfam_id })
        for result in cur:
            uniprot_acc, md5, seq, resolved = (result)
            seq = seq.read()
            resolved = resolved.replace(',', '_')
            domain_id = '{}/{}'.format(md5, resolved)

            # dom = { "id": domain_id, "sfam_id": sfam_id, "segments": segs }

            if uniprot_acc in proteins:
                p = proteins[uniprot_acc]
            else:
                p = Protein(uniprot_acc, seq=seq)
                proteins[uniprot_acc] = p

            segs = self._segs_from_string(resolved)
            dom = Domain(id=domain_id, sfam_id=sfam_id, segments=segs)

            p.domains[domain_id] = dom

            record_count += 1
            if record_count % 1000 == 0:
                logger.info("   ... processed {} domain records".format(record_count))

            # logger.debug( "{:<10s} {:<10s} {:<10s} {}".format(uniprot_acc, md5, resolved, dom_seq) )

        logger.info(" ... got {} unique proteins".format(len(proteins)))

        return proteins

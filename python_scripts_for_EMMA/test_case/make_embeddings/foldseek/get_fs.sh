rm -r dbs
mkdir dbs
/home/clemens/programs/foldseek/foldseek/bin/foldseek createdb $1 dbs/fs_db
/home/clemens/programs/foldseek/foldseek/bin/foldseek search dbs/fs_db dbs/fs_db dbs/db_vs_db tmp
mmseqs convertalis dbs/fs_db dbs/fs_db dbs/db_vs_db db_vs_db.m8 --format-output "query,target,qlen,tlen,alnlen,bits"
awk '{print $1,$2,$5/$3,$5/$4,$6}' db_vs_db.m8 | awk '{m=$3; for (i=4; i<=4; i++) if ($i < m) m = $i; print $1,$2,m,$5}' | awk '$3 > 0.6' | sed 's/.pdb//g' | sed 's?p?/?g' | awk '{print $1,$2,$4}' > fs.out

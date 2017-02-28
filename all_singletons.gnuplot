set terminal postscript eps enhanced color
set output "all_singletons.multiply.eps"
set title "BLAST results vs COMPASS results for *singleton* families in 2.20.100.10"
set xlabel 'blast\_sequence\_identity * blast\_overlap\_fraction' font "Helvetica,20"
set ylabel 'log_1_0( COMPASS\_evalue )' font "Helvetica,20"
set size square 3,3
set palette defined ( 20 "red", 30 "dark-yellow", 40 "dark-green" ) 
set xtics 0,10
#set ytics 0,0.1
set xrange [0:100]
#set yrange [0:100]
set style line 11 lc rgb "#808080" lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb "#808080" lt 0 lw 1
set grid back ls 12
set key bottom right
set key font ",11"
set key spacing 0.7
set xtics font "Helvetica,18"
set ytics font "Helvetica,18"
plot 'all_singletons.correl_data.subset.txt' using 1:2:3 with points pt 7 pointsize 0.5 lt palette notitle

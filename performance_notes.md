Performance Notes
=================

How well do COMPASS Comparisons Parallelise?
--------------------------------------------

Running simple tests on v4.1 data for 2.20.100.10 (with 2878 families)...

Using `xargs` to run 10 randomly-selected families' profiles against a database of all 2,878, gives these results:

| Number of threads | Rate of COMPASS comparisons|
|:-- |:-- |
|1 | 1,320 / second |
|4 | 1,140 / second |
|8 |   720 / second |

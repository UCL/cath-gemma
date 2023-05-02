**CATH-eMMA**
==========

Overview
---------

Fork of CATH-Gemma switching the core from HHsuite to embeddings or structural distances. 
Main features/wishlist

- Revised protocol to use MMseqs2 instead of CD-HIT. 
- Wrap pipeline in Python
- Add flags to use either embedding distances or 1/bitscore distances from Foldseek.
- Create infrastructure for multiple iterations (MARC)
- Create partitions using MDAs

This repo is part of the FunFams pipeline as an intermediate step before FunFHMMER.
The master FunFams repo is https://github.com/UCL/cath-funfam



See the GeMMA [Wiki](https://github.com/UCL/cath-gemma/wiki) for documentation (to expand with new usage).

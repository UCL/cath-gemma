#!/usr/bin/env python3
import sys
import traceback

# Take the cluster membership file generated at the end of the FunFHMMer process and map the clusters:
#
#     cath-map-clusters 1.10.10.1140.working_clustmemb --map-from-clustmemb-file 1.10.10.1140.prev_release_final_clustmemb > cluster_mapping
#
# ...or if no final_clustmemb file is available for the previous release, then:
#
#     cath-map-clusters 1.10.10.1140.working_clustmemb                                                                     > cluster_mapping
#
# ...and then use this script with the cluster mapping to generate a final clustmemb file:
#
#     script/map_clusters.py 1.10.10.1140.working_clustmemb cluster_mapping > 1.10.10.1140.final_clustmemb

def read_cluster_mapping(cluster_mapping_filename):
	'''
	Read the specified file into a key-value dictionary (where the first column is
	treated as the key and the second as the value)
	Skips any lines beginning with a hash symbol
	'''
	cluster_mapping = {}
	with open( cluster_mapping_filename, 'r' ) as cluster_mapping_file:
		for line in cluster_mapping_file:
			# Skip comment lines
			if line.startswith( '#' ):
				continue

			# Strip and split on whitespace; raise an Error if there aren't two parts
			line_parts = line.rstrip().split()
			if len( line_parts) != 2:
				raise Exception(
					  "Whilst parsing cluster_mapping_filename file " + cluster_mapping_filename
					+ ", found there weren't two parts to line"       + line
				)

			# Store the key-value pair in the dictionary
			key, value = line_parts
			cluster_mapping[ key ] = value

	return cluster_mapping

def the_main_function():
	# If there aren't two command line arguments, print the usage and stop
	# Otherwise, grab the arguments
	if len( sys.argv ) != 3:
		print( 'Usage: ' + sys.argv[ 0 ] + ' input_clustmemb_filename cluster_mapping_filename' )
		sys.exit( 1 )
	_, input_clustmemb_filename, cluster_mapping_filename = sys.argv

	# Call read_cluster_mapping() on cluster_mapping_filename and store the result
	cluster_mapping = read_cluster_mapping( cluster_mapping_filename )

	# Read the lines in the input_clustmemb_filename and map each cluster ID
	with open( input_clustmemb_filename, 'r' ) as input_clustmemb_file:
		for line in input_clustmemb_file:

			# Strip and split on whitespace; raise an Error if there aren't two parts
			line_parts = line.rstrip().split()
			if len( line_parts ) != 2:
				raise Exception(
					  "Whilst parsing input_clustmemb_filename file " + input_clustmemb_filename
					+ ", found there weren't two parts to line"       + line
				)

			# Try to map the cluster and print the result
			# Add more info to any KeyError that's raised
			cluster, member_id = line_parts
			try:
				mapped_cluster = cluster_mapping[ cluster ]
			except KeyError as ex:
				ex.args = ("Couldn't find entry in cluster mapping for cluster " + ex.args[ 0 ] , )
				raise

			print( cluster_mapping[ cluster ], member_id )

the_main_function()

# # Alternative pandas approach:
# my_dictionary = pd.read_csv( cluster_mapping_filename, sep=' ', index=0 ).to_dict()
# print(repr(my_dictionary))
# exit()


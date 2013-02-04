somsds
======

A lightweight system for managing large neuroimaging datasets in a 
shared computing environment. There are two main components of _somsds_: 

* A backend SQL database, which may be queried directly using `somsds_sql`.
* A Perl interface giving access to the most common use cases: archiving and retrieving data.

There is no public documentation yet on how to archive data. In any case, only 
superusers of the shared computing environment can archive data. Thus most users 
will only want to know how to retrieve data files from _somsds_.

## Installation

_somsds_ should work out of the box on most Linux distributions and on Mac OS X. 
In theory it should work also under Windows with some minor modifications. 

	clone git://github.com/germangh/somsds
	cd sosmds
	./somsds_install.pl
	
## Retrieving data

	somsds_link2rec [recid] [--]
	
where `[recid]` is the ID of the _recording_ from which data should be retrieved. A
series of optional arguments will typically follow indicating the subset of data 
that we want to gain access to. For instance, one could retrieve all structural 
MRI datasets for subjects 3 to 10, for condition `rs-ec`, from recording `ssmd` using:

	somsds_link2rec ssmd --condition rs-ec --modality smri --subject 3..10
	
Apart from `condition`, `modality`, and `subject` there are several other _tags_ 
that may be used to filter the set of files to be retrieved, e.g. `technique`, 
`device`, `sex`, `age`, etc. See the command line documentation of script 
`somsds_link2rec` for more information.


## Recording IDs, condition IDs, etc...

To produce a list of the available recordings together with a short description:

	somsds_rec_list

To list all valid condition IDs (together with a short description)
 for recording `ssmd`:
 
	somsds_rec_get ssmd condition
	
In general, the accepted values of tag `[tagname]` for recording `[recid]` can be
listed using:

	somsds_rec_get [recid] [tagname]
	
	
## Symbolic links

Script `somsds_link2rec` will __not__ create copies of the relevant data files. 
Instead it will create symbolic links with to the actual data files. The main 
reasons for this being the desired behaviour are:

* It is unaffordable (and wasteful) to create copies of the raw data files each 
time they are retrieved. _Raw_ data files should be (and, in fact, _somsds_ 
enforces them to be) inmutable so there is no need of keeping multiple copies. 

* Raw data files may have arbitrary file names. In some cases, the names of such 
files are automatically given by the recording device (e.g. an MR scanner), and 
those names give no clue of the actual contents of the data file (e.g. Philips MR 
scanners' physiology files). Lacking standard file naming conventions is a great 
obstacle to scripting analysis pipelines. By using symbolic links, the _somsds_ 
system is able to name the symbolic links so that they follow (user configurable) naming 
conventions. 


## License

Released under the [Creative Commons Attribution-NonCommercial-ShareAlike licence](http://creativecommons.org/licenses/by-nc-sa/3.0/)


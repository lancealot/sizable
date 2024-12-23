Sizable is a filesystem crawler that can return statistics about the contents of a given directory.  
By default the crawler will run with eight parallel processes which can be tuned at runtime.  
The size distribution works on a sliding scale, depending on the contents of the directory.  

  
> GNU Parallel, bc, awk, find, and stat (GNU Coreutils) are all required to be installed. 

  
```
./sizable.sh -h
Usage: sizable.sh -p <path> [OPTIONS]

A parallel filesystem analyzer that provides detailed statistics about files and directories.

Required:
    -p <path>    Specify the filesystem path to analyze

Options:
    -j <num>     Number of parallel processes (default: 8)
    -v           Enable verbose logging
    -s <num>     Sample size for calculating file size ranges (default: 1000)
    -h           Show this help message

Example:
    sizable.sh -p /home/user/data -j 4 -v
```

Examples of output:
```
./sizable.sh -p /root/
Total Files: 7388

Size Distribution:
  Files under 256 B: 736
  Files between 256 B and 1 KB: 3018
  Files between 1 KB and 16 KB: 2771
  Files over 16 KB: 863

Average File Size: 43 KB
Total Size: 317 MB
Total Directories: 1058

Execution time: 18.48 seconds
```
```
# ./sizable.sh -j 8 -p /ceph/data/
Total Files: 5001

Size Distribution:
  Files under 512 MB: 1
  Files between 512 MB and 1 GB: 0
  Files between 1 GB and 64 GB: 4250
  Files over 64 GB: 750

Average File Size: 9 GB
Total Size: 47 TB
Total Directories: 252

Execution time: 2.75 seconds
```

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

Example output:
```
# ./sizable.sh -p /tmp/
Total Files: 48

Size Distribution:
  Files under 4 KB: 8
  Files between 4 KB and 8 KB: 13
  Files between 8 KB and 128 KB: 12
  Files over 128 KB: 15

Average File Size: 96 KB
Total Directories: 7

Execution time: 0.31 seconds
```

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

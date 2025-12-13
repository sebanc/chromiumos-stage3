# Building the ChromiumOS Stage3

### Requirements

- root access.  
- `coreutils` and `git` packages.  

## Getting the source

Clone the main branch and enter the source directory:  

```
git clone -b main https://github.com/sebanc/chromiumos-stage3.git chromiumos-stage3
cd chromiumos-stage3
```

## Building

To build the ChromiumOS Stage3, you need to have root access and 10 GB of free disk space available.  

1. Launch the build:  
```
sudo ./build.sh
```
3. Make yourself a few coffees (the build will take several hours, it mostly depends on your cpu and hdd speed).  

4. That's it. You should have a ChromiumOS Stage3 archive in your current directory.  


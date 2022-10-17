# funLOCI: a local clustering algorithm for functional data - library and scripts
Welcome to the repository containing the library and the scripts for the paper **funLOCI: a local clustering algorithm for functional data**!
This folder contains:
- **the funloci folder:** a folder containing the funloci R package (work in progress);
- **funLOCI_functions.R:** a script with all the funloci functions;
- **funLOCI_aneurisk.R:** a script with the code to reproduce the case study **Case Study 2 - Aneurisk Project** (Sec. 4.2)
- **50patients.RData:** the 50 z-first derivative vessel centerline curves obtained after registration for the Aneurisk project data;

# How to reproduce the Aneurisk Case Study
To reproduce the **Case Study 2 - Aneurisk Project** (Sec. 4.2):
1. Download the **50patients.RData** file;
2. Download and run the **funLOCI_functions.R** script after installing all the required packages;
3. Download and run the **funLOCI_aneurisk.R** script paying attention to change the path where the **50patients.RData** are stored in your computer;

# How to install the funloci library
The **funloci** library is inside the funloci folder. It is still a work in progress and for the moments it only contains the Rcpp code to compute the H-score (MSR) based dissimilarity matrix. It is mandatory to install it to run the other scripts here presented. To install the library the user can run the script **funLOCI_functions.R:** or use the following R codes:

```
install.packages("devtools")
library(devtools)
install_github("JacopoDior/funloci/funloci")
library(funloci)
```

# RapidACi

An R package for the batch treatment of Rapid carbon dioxide response curves (A-Ci) generated by the LI-COR<sup>&reg;</sup> portable photosynthesis systems.    

The Rapid A-Ci measurement method (RACiR<sup>&trade;</sup>) can save a lot of time characterising photosynthetic capacity of multiple plants. However, this gain in time is rapidly lost during post processing following the response curve measurements to obtain the Vcmax and Jmax values, especially since this repetitive task can produce errors. This script was created to help with the analysis of hundreds of measurement files at once. It will automatically match empty chamber measurement files to A-Ci files. When the leaf area does not entirely cover the chamber opening, like in conifers, it will insert the real leaf area into the measurement files and extract recalculated measurement values before correcting the A and Ci values required to compute Vcmax and Jmax. 

For more information on the Rapid A-Ci method (RACiR<sup>&trade;</sup>), see [Stinziano et al. (2017)](https://onlinelibrary.wiley.com/doi/full/10.1111/pce.12911) and [this video](https://www.licor.com/env/support/LI-6800/videos/fast-a-ci-curves.html) produced by LI-COR<sup>&reg;</sup> Inc. For the application of this method to conifers, see [Coursolle _et al._ (2019)](https://www.frontiersin.org/articles/10.3389/fpls.2019.01276/abstract).  

Note: the package __works with the Excel files generated by the LI-COR<sup>&reg;</sup> systems only__ (not the text files) which contain formulas that need to be recalculated when the surface areas are measured after the RACiR<sup>&trade;</sup> curves.    

IMPORTANT: the actual version is not yet adapted for files produced by the LI-6400 model.     

## Installation     

```{r}
if(!require("devtools")) install.packages("devtools")    
devtools::install_github("ManuelLamothe/RapidACi")     
```
The package requires the _tidyverse_ and _XLConnect_ packages to work. The plantecophys package is recommended for the calculation of Vcmax and Jmax on the corrected values but is optional (another model could be prefered by the user)

```{r}
if (!require("plantecophys")) install.packages("plantecophys"); library(plantecophys)
```

## Usage       

### First step: Generate a list of files

- All measurement files (including empty and dark chamber measurements, when available) can be placed in a single folder. The file names must include a common part that identifies each **type of file** ("mpty", "fast", "slow", and "dark" are actual default R regex patterns that recognise empty chamber, rapid A-Ci, standard A-Ci, and dark chamber measurements, respectively) and a **unique sample identifier** that can unambiguously be retrieved by a regex pattern (default recognises a sequence of 3 uppercase letters, followed by an underscore and 3 numbers). The build_list function will then generate a list of the files that are present in the folder and that can be used for the calculations.  
    
- The empty chamber measurements files are paired to A-Ci measurement files automatically if an A-Ci and an empty chamber measurements are given the same 'match adjustment' during the measurements. Otherwise, the script will take the nearest starting time as timestamp to pair A-Ci and empty chamber measurements. (It is also possible to 'manually' modify a match by placing the same value in the 'Match Time' column (timestamp) of an Excel measurement file and its corresponding Empty chamber measurement file).

- By default, 'Match Time' column is the 66th column in LI-6800 Excel files ("BN"). This value can vary depending on the user definable settings. Check this value by opening anyone of your LI-6800 measurement files.

- If, later on, you need to adjust leaf area values, you need to provide a dataframe containing at least one column for the unique sample identifier (named: “sample_ID”), and one column with the leaf area in mm2 (named: “LeafArea_mm2”). Note: If you use WinSEEDLE, the following hidden function could work to produce the leaf area dataframe (`your_leafArea_df <- RapidACi:::extr_leafArea("some_WinSEEDLE_file.txt"`)


```{r}
LeafArea_df <- read_tsv("data/leafArea.tsv")   #optional

list_files <- build_list(path_to_licor_files = "data/",
                         pattern_empty       = "^(mpty)+.xls",      
                         pattern_rapidACi    = "^(fast)+.xls",      
                         pattern_standardACi = "^(slow)+.xls",      
                         pattern_dark        = "^(dark)+.xls",
                         sampleID_format     = "[:upper:]{3}_[:digit:]{3}",
                         timestamp_column    = "BN",
                         leafArea_df         = LeafArea_df)    
```

### Second step: Use empty chamber measurements to correct A and Ci values

There are two possible scenarios. The simple scenario is when leaves cover the whole opening of the chamber, so no leaf areaThese could help you diagnose problems or to verify that the measurements have been carried out correctly correction is required. The alternative, is when the measured leaf area is smaller than the chamber opening and/or when leaves are distributed in multiple layers (e.g. conifers) and a correction is thus required. Since leaf area (“Const_S”) is generally evaluated after theTo produce a file for all samples consisting of multiple diagnostic plots measurements, both the A-Ci measurement files and matching empty chamber files have to be modified with the correct leaf area and their values recalculated before proceeding to the A and Ci corrections. Similarly, if you use your own measures of respiration (from the measurements of the samples in a dark chamber), these values will also be recalculated according to the leaf area provided.    

For the correction of A and Ci, we use the coefficients of the best fitting polynomial curve (up to the fifth degree, optional with the *max_degree* argument) on the empty chamber measurements. *delta_max* can also be changed from the default settings (0.05). Before doing this, we recommand the use of the function *diagnose_sample* to see the impact of a possible change.    

```{r}
results <- Rapid_aci_correction(list_files, 
                                delta_max = 0.05, 
                                max_degree = 3,
                                priority_curve = "positive")

```
To produce a file for all samples consisting of multiple plots (they will be place in the _figure/_ directory of your working directory). These could help you diagnose problems or to verify that the measurements have been carried out correctly)
  
```{r}
for(i in names(results)) diagnose_sample(results, i)
```

### 3. Calculate Vcmax and Jmax 

The plantecophys package by [Duursma (2015)](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0143346) to calculate Vcmax and Jmax for each samples. The option `*useRd* = TRUE` let you use your own measures of respiration (missing values will be estimated).

```{r}
# We recommand to launch the fitaci function with the *safely* function from the purrr package to produce a list of separated `result` and `error` elements. This prevent the script to fail in the presence of a problematic sample.

X <- map(results, `[[`, "Raci") %>%
     map(safely(~plantecophys::fitaci(., useRd=TRUE, Tcorrect=FALSE)))
```

Here are useful bit of codes to help you extract data from the list object X:

```{r}     
# Generate the A-Ci plots
map(X, "result") %>% compact() %>% walk(plot)     

# See error messages
map(X, "error") %>% compact() 

# See variables names (in an Excel file generated by the LI-6800)
get_fromExcel(list_files$path[1], show.variables = TRUE)

# Wrapping things up for Vcmax and Jmax!
Y  <- map(X, "result") %>% map(`[[`, "pars") %>% compact()
data.frame(sample_ID = names(Y),
           Vcmax = unlist(map(Y, `[[`, 1)) %>% as.vector(),
           Jmax = unlist(map(Y, `[[`, 2)) %>% as.vector(),
           Rd = unlist(map(Y, `[[`, 3)) %>% as.vector(),
           GammaStar = map(X, "result") %>% map(`[[`, "GammaStar") %>% unlist() %>% as.vector())
                 
# Extract plantecophys Photosyn results
Z <- map(X, "result") %>% map(`[[`, "Photosyn") %>% compact()
photo_res <- vector("list", length(Z))
for (i in 1:length(Z)) photo_res[[i]] <- bind_cols(sample_ID = names(Z)[i], Z[[i]]()) 
plyr::ldply(photo_res)

# Save the results for R
saveRDS(X, "some_name.rds")     #retrivable with: X <- readRDS("some_name.rds")

```


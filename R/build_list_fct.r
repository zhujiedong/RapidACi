#' build_list function
#'
#' @description  Generates a list of the files present in a specified directory. By
#'   default, the function uses the MATCH timestamp generated by the Li-Cor system to pair
#'   an A-Ci measurement file to its identify which corresponding 'empty chamber' file is
#'   to used to for its correction. If the Li-Cor MATCH function
#'   is not used, the option can be turned off and the closest empty chamber file will be
#'   used.
#'
#' @param path_to_licor_files Directory path where all files are stored
#' @param sampleID_format Regex pattern that uniquely identifies the sample ID in
#'   filenames. For example (default), "[:upper:]{3}_[:digit:]{3}" will extract sample ID
#'   of the format ABC_123 from a filename like
#'   "2019-03-20_456_Logdata_ABC_123_Fast_KF.xlsx"
#' @param pattern_empty Regex pattern that must only match filenames for empty chamber
#'   files
#' @param pattern_rapidACi Regex pattern that must only match filenames for rapid A-Ci
#'   measurement files
#' @param pattern_standardACi Regex pattern that must only match filenames for standard
#'   A-Ci measurement files
#' @param pattern_dark Regex pattern that identifies measurements in dark chamber files
#' @param timestamp_column Column index corresponding to the MATCH TIME column in all
#'   Li-Cor Excel files. By default this corresponds to column BN (index = 66) in Excel
#'   files.
#' @param leafArea_df A dataframe containing at least a "sample_ID" column and a
#'   "leafArea_mm2" column (default = NULL)
#'
#' @return The function returns a dataframe that includes the path to the Li-Cor
#'   files to use, the type of measurements, the starting time of the measure, the
#'   timestamps, and how the timestamp was acquired. It also includes leaf area if
#'   available.
#'
#' @export


build_list <- function(path_to_licor_files = "data/",
                       sampleID_format     = "[:upper:]{3}_[:digit:]{3}",
                       pattern_empty       = "(mpty).*\\.xls",     
                       pattern_rapidACi    = "(fast).*\\.xls",
                       pattern_standardACi = "(slow).*\\.xls",
                       pattern_dark        = "(dark).*\\.xls",
                       timestamp_column    = "BN",
                       leafArea_df         =  NULL) {

  x <- path_to_licor_files

  lst_A <- list.files(x, pattern = pattern_empty, ignore.case = TRUE)
  lst_B <- list.files(x, pattern = pattern_rapidACi, ignore.case = TRUE)
  lst_C <- list.files(x, pattern = pattern_standardACi, ignore.case = TRUE)
  lst_D <- list.files(x, pattern = pattern_dark, ignore.case = TRUE)
  lst <- paste0(x, c(lst_A, lst_B, lst_C, lst_D))

  df <- 
    tibble(
      path = lst,
      sample_ID = ifelse(is.na(str_extract(lst, sampleID_format)), "none",
                         str_extract(lst, sampleID_format)),
      LiCor_system = get_system(lst),
      chamber = c(rep("EMPTY", length(lst_A)), 
                  rep("FAST",  length(lst_B)),
                  rep("SLOW",  length(lst_C)),
                  rep("DARK",  length(lst_D))), 
      START_time = extr_timestamps(lst, timestamp_column = "G"),
      timestamp =  extr_timestamps(lst, timestamp_column),
      MATCH_type = NA,
      nearest = NA) %>%
    mutate(
      START_time = ifelse(grepl("6400", LiCor_system) | 
                          grepl("DARK", chamber), NA, START_time),
      timestamp  = ifelse(grepl("6400", LiCor_system) | 
                          grepl("DARK", chamber), NA, timestamp))
  
  empty <- dplyr::filter(df, chamber == "EMPTY")
  fast  <- dplyr::filter(df, chamber == "FAST")

  for(i in 1:nrow(fast)) {
    fast$nearest[i] <- unlist(empty[which(abs(empty$START_time - fast$START_time[i]) == 
                                          min(abs(empty$START_time - fast$START_time[i]))), 
                                    "START_time"])
  }
  
  suppressMessages(
  df <- left_join(select(df, -nearest), fast) %>%
        mutate(MATCH_type = ifelse(timestamp == 0, "closest_time",
                              ifelse(is.na(timestamp), NA, "MATCH")),
               timestamp = ifelse(timestamp == 0, nearest, timestamp),
               timestamp = ifelse(is.na(timestamp), START_time, timestamp),
               START_time = lubridate::as_datetime(START_time)) %>%
        select(-nearest) %>%
        arrange(START_time)
  )

  if(sum(is.na(df$START_time)) > 0 & sum(is.na(df$LiCor_system)) > 0) {
    warning("Time data cannot be retrieved for some of the files. Makes sure that these files are valid measurement files")
  }
  
  # If dataframe for leaf area is provided...
  if (is.null(leafArea_df)) {
    df$leafArea_mm2 <- NA
  } else {
    df <- left_join(df, select(leafArea_df, sample_ID, "leafArea_mm2"))
  }

  return(df)
}

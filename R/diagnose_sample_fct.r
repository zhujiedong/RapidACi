#' diagnose_sample function
#'
#' @param results list generated by the main function Rapid_aci_correction
#' @param sample_name sample_ID
#' @param delta_max delta_max as specified to obtain results from the Rapid_aci_correction
#'   function
#'
#' @return Several plots for diagnosing potential failure or problems
#' @export
#'
#' @note IN CONSTRUCTION

diagnose_sample <- function(results, sample_name, delta_max){

 data <- results[[sample_name]]

 empty1 <-     
    ggplot(data$empty_chamber_data, aes(x = n, y= delta, color = curve)) + 
      geom_point() +
      geom_hline(aes(yintercept = -delta_max)) + 
      geom_hline(aes(yintercept =  delta_max)) +
      labs(title = paste("Stable selected empty curve (delta_max =", delta_max, ")")) +
      theme(legend.position = "none")
    
 empty2 <-
    ggplot(data$empty_chamber_data, aes(x = Meas_CO2_r, y = GasEx_A, color = good)) + 
      geom_point() +
      labs(title = paste("Portion of the empty chamber curve used (in blue)")) +
      theme(legend.position = "none")
 
 deg <- length(data$posCurve_coefs) 
    if(deg > 0){
      if(deg==2){oi<-"st"}else if(deg==3){oi<-"nd"}else if(deg==4){oi<-"rd"}else{oi<-"th"}
      empty3 <- 
        ggplot(dplyr::filter(data$empty_chamber_data, good == 1), aes(x = Meas_CO2_r, y = GasEx_A)) + 
          geom_point() +
          geom_smooth(method='lm',formula = y~x + poly(x, deg), color = "green2", se = FALSE) +
          labs(title = paste("Best fitting on positive curve :", paste0(deg-1, oi), "degree"))
    } else {
      deg <- length(data$negCurve_coefs)
      if(deg > 0){
        if(deg==2){oi<-"st"}else if(deg==3){oi<-"nd"}else if(deg==4){oi<-"rd"}else{oi<-"th"}
      empty3 <-
        ggplot(data$empty_chamber_data, aes(x = Meas_CO2_r, y = GasEx_A, color = as.factor(good))) + 
          geom_point() +
          geom_smooth(method='lm',formula=y~x + poly(x, deg), color = "green1", se = FALSE) +
          labs(title = paste("Best fitting on negative curve :", paste0(deg-1, oi), "degree"))
      }
    }

    corr1 <- 
    ggplot(data = cbind("Aleaf" = data$Aleaf[[1]], "GasEx_A" = data$ACi_data$GasEx_A, 
                 "Ci_corrected" = data$Ci_corrected[[1]], "GasEx_Ci" = data$ACi_data$GasEx_Ci) %>% 
           as_tibble()) + 
      geom_point(aes(Ci_corrected, Aleaf), color = "blue") + 
      geom_point(aes(GasEx_Ci, GasEx_A), color = "red") +
      labs(title = "Raw (RED) vs Corrected (BLUE) A - Ci measures", subtitle = sample_name) + 
      xlab("Ci") + ylab("A")
    
    raci1 <-
    ggplot(data$Raci, aes(Ci, Photo)) + 
      geom_point() +
      labs(title = "Portion passed to plantecophys", subtitle = sample_name) + 
      xlab("Ci") + ylab("A")
    
    # raci2 <- 
    #   data$Raci %>% 
    #   plantecophys::fitaci(., useRd=TRUE, Tcorrect=FALSE) %>% plot()

#better place...
  dir.create(file.path("figure"), showWarnings = FALSE)  
  
  png(paste0("figure/", sample_name, ".png"), pointsize = 10, height = 1500, width = 2000)
    gridExtra::grid.arrange(empty1, empty2, empty3, corr1, raci1,
                            layout_matrix = rbind(c(1,1,2,2,3,3), c(4,4,4,5,5,5)))

  
  dev.off()
  
}  
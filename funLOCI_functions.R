# funLOCI functions -
# to install the funloci package (work in progress)
# it presents the Rcpp HscoreC() function (which should be stored in a package to
# be used in a parallel way with future_lapply)
library(devtools)
install_github("JacopoDior/funloci/funloci")
library(funloci)
## Step 1 -----
# create the structure of the lotting, i.e., a list with
# positions: all the possible starting positions
# elem: all the possible lengths

# input:
# - mat: the matrix;
# - int: minimum length of the interval;
# - sequential: TRUE or FALSE if a sequential strategy is applied
# - pos_step: how much to move the left boundary of the sub-interval (default = 1)
# - int_step: how much to enlarge the sub-interval (default = 1)
funLOCI_lotting <- function(mat, int, sequential, pos_step = 1, int_step = 1){
  if(sequential == TRUE){
    positions <- seq(1, by = pos_step, ncol(mat)-1)
    elem <- unique(c( seq(int,by = int_step,ncol(mat)), ncol(mat)) ) # to be sure to keep the maximum length
  }else{
    positions <- seq(1, by = int - 1, ncol(mat))
    elem <- unique(c(int * (1:floor(ncol(mat)/int)), ncol(mat)))
  }
  return(list(positions, elem))
}

# create a list with all sub-intervals represented with their boundaries

# input:
# - lotting: a lotting structure generated by funLOCI_lotting
# - n_col: number of columns of th original matrix
cppFunction('Rcpp::List create_lots(Rcpp::List lotting, int n_col){
  std::vector<int> position = lotting[0]; //taking vector of elements
  int n_pos = position.size();
  
  std::vector<int> elem = lotting[1]; //taking vector of elements
  int n_elem = elem.size();
  
  int k = 0;
  int end_lot = 0;
  
  // first run to get the number of elements
  for (int i = 0; i < n_elem; i++){
    for (int j = 0; j < n_pos; j++){
      end_lot = position[j] + elem[i] - 1;
      if (end_lot <= n_col){
        k = k + 1;
      }
    }
  }
  
  Rcpp::List lots (k);
  int q = 0;
  
  // final run
  for (int i = 0; i < n_elem; i++){
    for (int j = 0; j < n_pos; j++){
      end_lot = position[j] + elem[i] - 1;
      if (end_lot <= n_col){
        lots[q] = NumericVector::create(position[j], end_lot); 
        q = q + 1;
      }
    }
  }
  return lots;
}')

## Step 2 ----
# Performs DIANA with h-score (MSR) as height to a matrix
# output:
# hc - hierarchy resulting from DIANA

# input: 
# mat - a matrix
funLOCI_diana <- function(mat) 
{
  mydist <- HscoreC(mat)
  hc <- cluster::diana(mydist, diss = TRUE, keep.diss = TRUE)
  addinfo <- score_merging(mat, hc)
  hc$height <- addinfo[[1]]
  hc$position <- addinfo[[2]]
  return(hc)
}

# Used by funLOCI_diana. Gets the h-score height of every single DIANA merging step;
# Returns a list containing the hscores of every single DIANA merging steps and
# the resulting groups of those steps.

# input:
# - mat: a matrix;
# - hc: a hierarchy resulting from DIANA;
score_merging <- function (mat, hc) 
{
  mergelist <- list()
  for (i in 1:dim(hc$merge)[1]) {
    if (sum(hc$merge[i, ] < 0) == 2) {
      mergelist[[i]] <- abs(hc$merge[i, ][which(hc$merge[i, 
      ] < 0)])
    }
    else if (sum(hc$merge[i, ] < 0) == 1) {
      mergelist[[i]] <- c(abs(hc$merge[i, ][which(hc$merge[i, 
      ] < 0)]), mergelist[[hc$merge[i, ][which(hc$merge[i, 
      ] > 0)]]])
    }
    else {
      mergelist[[i]] <- c(mergelist[[hc$merge[i, ][1]]], 
                          mergelist[[hc$merge[i, ][2]]])
    }
  }
  mergehscore <- c()
  for (i in 1:length(mergelist)) {
    mergehscore[i] <- ccscore(as.matrix(mat[mergelist[[i]], 
    ]))
  }
  return(list(mergehscore, mergelist[[i]]))
}


# Embeds funLOCI_diana in a parallel framework (see funLOCI_diana)
diana_parallel <- function(case, mat){
  a <- case[1]
  b <- case[2]
  hc <- funLOCI_diana(mat[, a:b])
  hc$elements <- c(a, b)
  return(hc)
}

## Step 3 ----
# Harvest candidates loci from a hierarchy by using a delta threshold
# output: a list of loci
# input:
# - list_hc: a list of hierarchies (hc)
# - delta: a delta threshold
# - mat: a matrix

funLOCI_harvesting_delta <- function(list_hc, delta, mat){
  require(future.apply)
  biclist <- future_lapply(list_hc, parallel_delta, mat=mat, delta=delta) #delta cut
  for(i in 1:length(biclist)){
    biclist[[i]] <- lapply(biclist[[i]], add_index, i = i) # add index i as 4th element of each bicluster
  }
  return (unlist(biclist, recursive= FALSE)) # flatten the list to one level for reduction
}

# Perform delta_cutting using an h-score threhsold. Return a list of loci (biclist).
# To be used inside funLOCI_harvesting_delta
# input: 
# - hc: hierarchy
# - mat: a matrix
# - delta: a H-score delta threshold

parallel_delta <- function(hc, mat, delta){
  k <- 1
  bic <- delta_cutter(mat, hc, delta)
  biclist <- list()
  for (j in 1:max(bic)) {
    biclist[[k]] <- list(which(bic == j), hc$elements, 
                         ccscore(as.matrix(mat[which(bic == j), hc$elements[1]:hc$elements[2]])),0) 
    # in biclist there's no index of the corresponding list_hc element because it is already
    # the index of the biclist
    k <- k + 1
  }
  return(biclist)
}


# Harvest candidates loci from a hierarchy by using a percentage threshold
# output: a list of loci
# input:
# - list_hc: a list of hierarchies (hc)
# - perc: a delta threshold
# - mat: a matrix
funLOCI_harvesting_perc <- function(list_hc, perc, mat){
  require(future.apply)
  biclist <- future_lapply(list_hc, parallel_perc, mat=mat, perc=perc) #perc cut
  for(i in 1:length(biclist)){
    biclist[[i]] <- lapply(biclist[[i]], add_index, i = i) # add index i as 4th element of each bicluster
  }
  return (unlist(biclist, recursive= FALSE)) # flatten the list to one level for reduction
}

# Perform delta_cutting using a percentage threshold Return a list of loci (biclist)
# To be used inside funLOCI_harvesting_perc
# input: 
# - hc: hierarchy
# - mat: a matrix
# - perc: a percentage delta threshold

parallel_perc <- function(hc, mat, perc){
  # Perform delta_cutting using lapply based on percentage
  # The last element (the corresponding flower id) is not here.
  k <- 1
  totalscore <- ccscore(as.matrix(mat[,hc$elements[1]:hc$elements[2] ]))
  delta <- totalscore*perc
  bic <- delta_cutter(mat, hc, delta)
  biclist <- list()
  for (j in 1:max(bic)) {
    biclist[[k]] <- list(which(bic == j), hc$elements, 
                         ccscore(as.matrix(mat[which(bic == j), hc$elements[1]:hc$elements[2]])),0) 
    # in biclist there's no index of the corresponding list_hc element because it is already
    # the index of the biclist
    k <- k + 1
  }
  return(biclist)
}


# add index of the corresponding list_hc element
# Used in funLOCI_harvesting_delta and funLOCI_harvesting_perc
add_index <- function(bic, i){
  bic[[4]] <- i
  return(bic)
}

## Step 4 ----

# Perform Step 4 - Tasting to set of candidate loci
# output: 
# input: 
# -biclist: a list of candidate loci;
funLOCI_tasting <- function(biclist){
  resinfo <- getInfo(biclist)
  info_df <- cbind.data.frame('num_elem'= unlist(resinfo[[1]]),
                              'int_len' = unlist(resinfo[[2]]),
                              'a' = unlist(resinfo[[3]]),
                              'b' = unlist(resinfo[[4]]),
                              'hscore'= unlist(resinfo[[5]]),
                              'index'= unlist(resinfo[[6]]))
  
  myorder <- info_df %>%
    arrange(desc(int_len), desc(num_elem), hscore)  #reordering first by int_len
  best_biclist <- biclist[myorder$index]
  
  # reduce results
  res <- reduce_res(best_biclist)
  res <- cbind.data.frame('keep'= res[[1]], 'kill'= res[[2]])
  selected_biclist <- best_biclist[res$keep]
  return(list(res, selected_biclist))
}

# Returns details of each candidate
# input:
# - biclist: a list of candidate loci;
# output:
# - L: a list with number of elements, interval length, a, b, hscore, and index;
cppFunction('Rcpp::List getInfo(Rcpp::List biclist){
  int n = biclist.size(); 
  int np = 0;
  
  for (int i = 0; i < n; i++){
    Rcpp::List temp = biclist[i];
    NumericVector elem = temp[0];
    if( elem.size()>1 ){
      np++;
    }
  }
  
  NumericVector num_elem (np);
  NumericVector int_len (np);
  IntegerVector a (np);
  IntegerVector b (np);
  NumericVector hscore (np);
  IntegerVector index (np);
  
  
  int j = 0;
  
  for (int i = 0; i < n; i++){
    Rcpp::List temp = biclist[i];
    NumericVector elem = temp[0];
    if( elem.size()>1 ){
      num_elem[j] = elem.size();
      
      IntegerVector interval = temp[1];
      int_len[j] = interval[1] - interval[0] +1;
      
      a[j] = interval[0];
      b[j] = interval[1];
    
      hscore[j] = temp[2];
      
      index[j] = i + 1;
      j++;
    }
  }
  
  List L = List::create(num_elem, int_len, a, b, hscore, index);
  return L;
}')



# reduce the number of candidates in case of affiliation. It receives as input
# a list of candidates arranged and sorted. Every single element is compared
# with the ones sorted higher and deleted in case of affiliation. Two elements are 
# affiliated if they share some instances and they overlap for at least 50% of its
# interval
# input:
# - biclist: a list of candidate loci;

# output:
# - 
cppFunction('Rcpp::List reduce_res(Rcpp::List biclist){
   // [[Rcpp::plugins("cpp11")]]
  int n = biclist.size();
  LogicalVector res (n);
  IntegerVector killer (n);
  res[0] = true;
  
  for (int i = 1; i < n; i++){
  
    Rcpp::List temp = biclist[i];  //taking the bicluster
    std::vector<int> temp_elem = temp[0]; //taking vector of elements
    NumericVector temp_int = temp[1]; //
    int temp_a = temp_int[0]; //inferior boundary of the interval
    int temp_b = temp_int[1]; //superior boundary of the interval

    res[i] = true; //assuming I want to keep it
    killer[i] = 0;
    
    for(int j = 0; j < i; j++){ //cheking every top element
    
      if(res[j] == true){
        Rcpp::List compare = biclist[j];
        std::vector<int> compare_elem = compare[0];
        bool affiliates = true; //setting affiliates to true

        // checking if the top element to compare (i) includes the temp element (i)
        for (auto temp_elt: temp_elem) {
          if (std::find(compare_elem.begin(), compare_elem.end(), temp_elt) == compare_elem.end()) {
            affiliates = false;
          }
        }
      
        // affiliation! we need to get the extreme of compare
        if(affiliates){
          NumericVector compare_int = compare[1];
          int compare_a = compare_int[0];
          int compare_b = compare_int[1];
        
          // not overlapping
          if( !(temp_a > compare_b) || (temp_b < compare_a) ){
        
            int temp_len = temp_b - temp_a;
            double overlap_a = max( NumericVector::create(compare_a, temp_a) );
            double overlap_b = min( NumericVector::create(compare_b, temp_b) );
            double overlap_perc = (overlap_b - overlap_a)/temp_len;
          
            if( overlap_perc >= 0.5){
              res[i] = false;
              killer[i] = j + 1;
              break;
            }
          }
        }
      }
    }
  }
  List L = List::create(res, killer);
  return L;
}')


# an interactive function based on Shiny R to explore the funLOCI results
# input:
# - selected_biclist: a list of loci;
# - mat: the original data matrix;
tastingexplorer <- function(selected_biclist, mat){
  require(tidyverse)
  require(shiny)
  ciao <- getInfo(selected_biclist)
  bestinfo_df <- cbind.data.frame('num_elem'= unlist(ciao[[1]]),
                                  'int_len' = unlist(ciao[[2]]),
                                  'a' = unlist(ciao[[3]]),
                                  'b' = unlist(ciao[[4]]),
                                  'hscore'= unlist(ciao[[5]]),
                                  'index'= unlist(ciao[[6]]))
  
  bestinfo_df$mid <- (bestinfo_df$a +  bestinfo_df$b)/2
  bestinfo_df$jitnum <- jitter(bestinfo_df$num_elem, factor = 2)
  
  shinyApp(
    ui = fluidPage(
      plotOutput("christmas",width = 1200, height = 800,
                 click = "plot_click",
                 dblclick = "plot_dblclick",
                 brush = brushOpts(
                   id = "plot_brush",
                   resetOnNew = TRUE
                 )
      ),
      actionButton("reset","Reset!"),
      tableOutput("check"),
      downloadButton("pdf", "Generate pdf")
    ), 
    server = function(input, output) {
      
      ranges <- reactiveValues(x = NULL, y = NULL)
      click_saved <- reactiveValues(singleclick = NULL) #no click
      table <- reactiveValues(show = NULL)
      
      output$christmas <- renderPlot({ 
        p <- ggplot(bestinfo_df, aes(x = mid, y = jitnum, label=index)) + 
          geom_point(alpha = 0.4, aes(colour = hscore, size = hscore)) +
          geom_segment(aes(x = a, xend = b, y= jitnum, yend = jitnum, colour = hscore), alpha = 0.3) +
          scale_colour_gradient(low = "#e36d7f", high = "#37AEBA") +
          coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE)
        theme_bw()
        p
      })
      
      # When a double-click happens, check if there's a brush on the plot.
      # If so, zoom to the brush bounds; if not, reset the zoom.
      observeEvent(input$plot_dblclick, {
        brush <- input$plot_brush
        if (!is.null(brush)) {
          ranges$x <- c(brush$xmin, brush$xmax)
          ranges$y <- c(brush$ymin, brush$ymax)
          
        } else {
          ranges$x <- NULL
          ranges$y <- NULL
        }
        
        closest_point <- nearPoints(bestinfo_df, input$plot_click, addDist = FALSE)[1,]
        click_saved$singleclick <- rbind(click_saved$singleclick, closest_point$index)
      })
      
      # if you click on dots
      observeEvent(eventExpr = input$plot_click, handlerExpr = { 
        closest_point <- nearPoints(bestinfo_df, input$plot_click, addDist = FALSE)[1,]
        click_saved$singleclick <- rbind(click_saved$singleclick, closest_point$index)
        
        table$show <-  bestinfo_df %>%
          filter(index %in% click_saved$singleclick)
        
        output$check <- renderTable(table$show)
      })
      
      # if you click on Reset
      observeEvent(eventExpr = input$reset, handlerExpr = { 
        # back no click
        click_saved$singleclick <- c() #niente cliccato
        
        output$check <- renderTable({
          as.data.frame(c(NULL, NULL))
        })
      })
      
      
      output$pdf <- downloadHandler(
        filename = function() {
          paste("selectedLoci.pdf")
        },
        content = function(file) {
          pdf(file, paper = "default")
          for(k in table$show$index){ 
            plotme <- selected_biclist[[k]]
            number <- length(plotme[[1]])
            interval <- plotme[[2]]
            hscore <- plotme[[3]]
            matplot(t(mat), type='l', col = transgrey,
                    main = paste0('# ', number, ' - Interval: ', interval, ' - Hscore:', hscore), ylab='', axes='FALSE', lty=1)
            matplot(plotme[[2]][1]:plotme[[2]][2], t(mat[ plotme[[1]], plotme[[2]][1]:plotme[[2]][2]]), type='l', col = '#e36d7f', add=TRUE, lty=1 , lwd = 2)
            box(col="#78d0db",lwd = 2)
            axis(1, at=seq(1,dim(mat)[2],by=10), labels=seq(1,dim(mat)[2],by=10), col="#78d0db", col.ticks="#78d0db", col.axis="grey60", cex.axis=0.8)
            axis(2, col="#78d0db", col.ticks="#78d0db", col.axis="grey60", cex.axis=0.8)
          }
          dev.off()
        }
      )
    }
    
  )
  
}






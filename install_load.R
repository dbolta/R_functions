# install(if needed), load multiple unquoted packages in one call 
# Example: install_load(dplyr, ggplot, e1071)
# Supports quasiquotatation. Also accepts string arguments.

install_load <- function (package1, ...)  {
  # convert arguments to vector
  packages = as.character(substitute(expr= c(package1, ...)))
  packages = packages[2:length(packages)]
  
  # start loop to determine if each package is installed
  for(package in packages){
    if (!missing(package)) {
      package <- as.character(substitute(package))
    }
    # if package is installed locally, load
    if(package %in% rownames(installed.packages()))
      suppressPackageStartupMessages(do.call("library", list(package)))
    
    # if package is not installed locally, download, then load
    else {
      install.packages(package, repos="https://cloud.r-project.org/")
      suppressPackageStartupMessages(do.call("library", list(package)))
    }
  }
}

#install_load(doParallel,
#             parallel,
#             foreach,
#             
#             dplyr, 
#             tidyr,
#             purrr,
#             broom,
#             
#             data.table)

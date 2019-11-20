install_load <- function(package1, ...)  {
  # convert arguments to vector
  packages = as.character(substitute(expr = c(package1, ...)))
  packages = packages[2:length(packages)]
  
  # start loop to determine if each package is installed
  for (package in packages) {
    if (!missing(package)) {
      package <- as.character(substitute(package))
    }
    # if package is installed locally, load
    if (package %in% rownames(installed.packages()))
      suppressPackageStartupMessages(do.call("library", list(package)))
    
    # if package is not installed locally, download, then load
    else {
      install.packages(package, repos = "https://cloud.r-project.org/")
      suppressPackageStartupMessages(do.call("library", list(package)))
    }
  }
}
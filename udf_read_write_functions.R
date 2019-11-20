udf_fread_csv = function(csv_file){
  csv_file = enexpr(csv_file) 
  fread(paste0(analytics_folder = "", working_folder, csv_file, ".csv"),
        stringsAsFactors = FALSE) %>% 
    as.data.frame(stringsAsFactors = FALSE)
}

udf_fwrite_csv = function(obj_to_save, csv_file, subfolder = data_subfolder){
  csv_file = enexpr(csv_file) 
  fwrite(obj_to_save,
         paste0(analytics_folder = "", working_folder, subfolder, csv_file, ".csv"))
}

udf_read_xlsx = function(xlsx_file){
  xlsx_file = enexpr(xlsx_file)
  read.xlsx(paste0(analytics_folder = "", working_folder, xlsx_file, ".xlsx")) %>% 
    as.data.frame(stringsAsFactors = FALSE)
}

udf_write_rds = function(obj_to_save, rds_file, subfolder = data_subfolder){
  rds_file = enexpr(rds_file)
  if (length(rds_file) > 1) {
    rds_file = eval(rds_file)
  }
  obj_to_save %>% 
    write_rds(paste0(analytics_folder = "", working_folder, subfolder, rds_file, ".rds"),
              compress = "gz")
}

udf_read_rds = function(rds_file, subfolder = data_subfolder){
  rds_file = enexpr(rds_file)
  read_rds(paste0(analytics_folder = "", working_folder, subfolder, rds_file, ".rds"))
}
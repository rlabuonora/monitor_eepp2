app_dir <- normalizePath(file.path("monitor", "app"), winslash = "/", mustWork = TRUE)

shiny::shinyAppDir(app_dir)

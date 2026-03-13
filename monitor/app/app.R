library(bslib)
library(shiny)
library(ggplot2)
library(htmltools)
library(dplyr)
library(scales)
library(tibble)
library(stringr)

resolve_app_bootstrap_path <- function() {
  candidates <- c("bootstrap.R", file.path("monitor", "app", "bootstrap.R"))

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }

  stop("Unable to resolve monitor/app/bootstrap.R path.", call. = FALSE)
}

source(resolve_app_bootstrap_path(), local = TRUE)
app_source("R/data.R")
app_source("R/theme.R")
app_source("R/mod_principal.R")
app_source("R/mod_indicadores.R")

ui <- shiny::navbarPage(
  windowTitle = "OPP - Monitor Empresas Públicas",
  title = htmltools::div(class = "navbar-title", ""),
  theme = opp_theme,
  header = htmltools::tagList(
    htmltools::tags$head(
      if (identical(Sys.getenv("APP_TEST_MODE"), "1")) {
        htmltools::tags$style(htmltools::HTML("
          *, *::before, *::after {
            animation: none !important;
            transition: none !important;
            scroll-behavior: auto !important;
          }
        "))
      },
      htmltools::tags$link(rel = "icon", href = "favicon.ico"),
      htmltools::tags$link(rel = "stylesheet", type = "text/css", href = "estilos.css")
    ),
    htmltools::div(
      id = "app-ready",
      `data-ready` = "1",
      style = "display:none;"
    )
  ),
  shiny::tabPanel(title = "Inicio", principal_ui("principal")),
  shiny::tabPanel(title = "ANCAP", indicadores_ui("ANCAP")),
  shiny::tabPanel(title = "UTE", indicadores_ui("UTE")),
  shiny::tabPanel(title = "ANTEL", indicadores_ui("ANTEL")),
  shiny::tabPanel(title = "OSE", indicadores_ui("OSE")),
  shiny::tabPanel(title = "AFE", indicadores_ui("AFE")),
  shiny::tabPanel(title = "ANV", indicadores_ui("ANV")),
  shiny::tabPanel(title = "ANP", indicadores_ui("ANP")),
  shiny::tabPanel(title = "ANCO", indicadores_ui("ANCO")),
  shiny::tabPanel(title = "INC", indicadores_ui("INC")),
  shiny::tabPanel(title = "URSEA", indicadores_ui("URSEA")),
  shiny::tabPanel(title = "URSEC", indicadores_ui("URSEC")),
  bslib::nav_spacer(),
  bslib::nav_item(
    shiny::actionLink(
      inputId = "open_methodology",
      label = NULL,
      icon = shiny::icon("info-circle"),
      class = "nav-link d-flex align-items-center",
      title = "Nota metodológica",
      `aria-label` = "Abrir nota metodológica"
    )
  ),
  bslib::nav_item(
    htmltools::tags$a(
      href = "https://opp-eepp.s3.us-east-1.amazonaws.com/Informe+Octubre+2025.pdf",
      download = NA,
      class = "nav-link d-flex align-items-center",
      title = "Descargar PDF",
      `aria-label` = "Descargar PDF",
      shiny::icon("download")
    )
  )
)

server <- function(input, output, session) {
  series_anuales <- read_required_dataset("series_anuales")
  series_mensuales <- read_required_dataset("series_mensuales")
  caja_mensual <- read_required_dataset("caja_mensual")

  shiny::observeEvent(input$open_methodology, {
    shiny::showModal(
      shiny::modalDialog(
        title = "Nota metodológica",
        easyClose = TRUE,
        footer = shiny::modalButton("Cerrar"),
        htmltools::tags$p(
          "Las cifras en precios corrientes se presentan en pesos uruguayos del año correspondiente, sin ajuste por variación de precios."
        ),
        htmltools::tags$p(
          "Las cifras en precios constantes de 2024 se obtienen deflactando los valores corrientes con el IPC reexpresado con base 2024 = 100."
        ),
        htmltools::tags$p(
          "Las cifras en millones de USD se calculan convirtiendo los montos corrientes con el tipo de cambio promedio anual 2025 ($39.86)"
        ),
        htmltools::tags$p(
          "Las cifras como % del PIB se calculan sobre el PIB nominal anual. Para 2025, mientras no exista cierre anual observado, se utiliza un PIB nominal anual proyectado con un crecimiento de 2,5%."
        )
      )
    )
  })

  principal_server("principal", series_anuales)
  indicadores_server("ANCAP", series_mensuales, caja_mensual)
  indicadores_server("UTE", series_mensuales, caja_mensual)
  indicadores_server("ANTEL", series_mensuales, caja_mensual)
  indicadores_server("OSE", series_mensuales, caja_mensual)
  indicadores_server("AFE", series_mensuales, caja_mensual)
  indicadores_server("ANV", series_mensuales, caja_mensual)
  indicadores_server("ANP", series_mensuales, caja_mensual)
  indicadores_server("ANCO", series_mensuales, caja_mensual)
  indicadores_server("INC", series_mensuales, caja_mensual)
  indicadores_server("URSEA", series_mensuales, caja_mensual)
  indicadores_server("URSEC", series_mensuales, caja_mensual)
}

shiny::shinyApp(ui, server)

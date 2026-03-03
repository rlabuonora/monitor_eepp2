principal_ui <- function(id, title = "OPP - Monitor Empresas Publicas") {
  ns <- shiny::NS(id)
  plot_height <- "540px"

  bslib::page_fillable(
    theme = bslib::bs_theme(version = 5),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(
        htmltools::div(
          class = "d-flex justify-content-between align-items-center w-100",
          htmltools::tags$h2(title),
          shiny::radioButtons(
            inputId = ns("units"),
            label = "Expresar cifras en:",
            choices = c(
              "Millones de $ corr." = "valor",
              "Millones de $ ctes. 2024" = "valor_2024",
              "Millones de USD" = "valor_usd",
              "% del PIB" = "valor_pct_pib"
            ),
            inline = TRUE,
            selected = "valor"
          )
        )
      ),
      bslib::card_body(
        bslib::layout_columns(
          gutter = 16,
          col_widths = c(3, 9),
          htmltools::div(
            bslib::value_box(
              title = "Resultado",
              value = shiny::textOutput(ns("resultado")),
              showcase = safe_bs_icon("bank")
            ),
            bslib::value_box(
              title = "Ingresos Corrientes",
              value = shiny::textOutput(ns("ingresos")),
              showcase = safe_bs_icon("cash-coin")
            ),
            bslib::value_box(
              title = "Gastos",
              value = shiny::textOutput(ns("gastos")),
              showcase = safe_bs_icon("graph-up-arrow")
            ),
            bslib::value_box(
              title = "Impuestos y Transferencias",
              value = shiny::textOutput(ns("impuestos")),
              showcase = safe_bs_icon("piggy-bank")
            ),
            bslib::value_box(
              title = "Inversiones",
              value = shiny::textOutput(ns("inversiones")),
              showcase = safe_bs_icon("tools")
            )
          ),
          bslib::navset_pill(
            id = ns("which_plot"),
            bslib::nav_panel("Resultado", spinner_wrap(girafe_output_widget(ns("plot_resultado"), height = plot_height))),
            bslib::nav_panel("Ingresos", spinner_wrap(girafe_output_widget(ns("plot_ingresos"), height = plot_height))),
            bslib::nav_panel("Gastos", spinner_wrap(girafe_output_widget(ns("plot_gastos"), height = plot_height))),
            bslib::nav_panel("Transferencias", spinner_wrap(girafe_output_widget(ns("plot_transferencias"), height = plot_height))),
            bslib::nav_panel("Inversiones", spinner_wrap(girafe_output_widget(ns("plot_inversiones"), height = plot_height)))
          )
        )
      )
    )
  )
}

principal_server <- function(id, series_anuales) {
  shiny::moduleServer(id, function(input, output, session) {
    data <- shiny::reactive({
      series_anuales |>
        dplyr::mutate(ejecutado_select = .data[[input$units]])
    })

    common_plot_theme <- ggplot2::theme(
      legend.position = "bottom",
      plot.margin = ggplot2::margin(t = 24, r = 2, b = 8, l = 2),
      axis.text = ggplot2::element_text(size = 13),
      axis.title = ggplot2::element_text(size = 15),
      strip.text = ggplot2::element_text(size = 14),
      legend.text = ggplot2::element_text(size = 13),
      legend.title = ggplot2::element_text(size = 13)
    )

    add_bar_layer <- function(position = NULL, ...) {
      if (is.null(position)) {
        return(ggiraph::geom_col_interactive(ggplot2::aes(tooltip = .data$tooltip), ...))
      }

      ggiraph::geom_col_interactive(ggplot2::aes(tooltip = .data$tooltip), position = position, ...)
    }

    output$ingresos <- shiny::renderText({
      data() |>
        dplyr::filter(.data$facet_col == "Ingresos", .data$year == 2025) |>
        dplyr::summarise(total = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(lbl = fmt_amount(.data$total, input$units)) |>
        dplyr::pull(.data$lbl)
    })

    output$resultado <- shiny::renderText({
      data() |>
        dplyr::filter(.data$facet_col == "Resultado", .data$year == 2025) |>
        dplyr::summarise(total = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(lbl = fmt_amount(.data$total, input$units)) |>
        dplyr::pull(.data$lbl)
    })

    output$gastos <- shiny::renderText({
      data() |>
        dplyr::filter(.data$facet_col == "Gastos", .data$year == 2025) |>
        dplyr::summarise(total = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(lbl = fmt_amount(.data$total, input$units)) |>
        dplyr::pull(.data$lbl)
    })

    output$impuestos <- shiny::renderText({
      data() |>
        dplyr::filter(.data$facet_col == "Impuestos y Transferencias", .data$year == 2025) |>
        dplyr::summarise(total = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(lbl = fmt_amount(.data$total, input$units)) |>
        dplyr::pull(.data$lbl)
    })

    output$inversiones <- shiny::renderText({
      data() |>
        dplyr::filter(.data$facet_col == "Inversiones", .data$year == 2025) |>
        dplyr::summarise(total = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(lbl = fmt_amount(.data$total, input$units)) |>
        dplyr::pull(.data$lbl)
    })

    output$plot_ingresos <- render_girafe_widget({
      plot_object <- data() |>
        dplyr::filter(.data$facet_col == "Ingresos") |>
        dplyr::mutate(tooltip = fmt_amount(.data$ejecutado_select, input$units)) |>
        ggplot2::ggplot(ggplot2::aes(.data$year, .data$ejecutado_select, fill = "Ejecutado")) +
        escala_y(input$units) +
        add_bar_layer() +
        ggplot2::scale_fill_manual(values = c("Ejecutado" = scales::alpha(opp_cols$dark_blue, 1)), name = NULL) +
        ggplot2::facet_wrap(~empresa, scales = "free_y") +
        ggplot2::labs(x = "Año", y = "") +
        common_plot_theme

      make_girafe_widget(plot_object)
    })

    output$plot_gastos <- render_girafe_widget({
      plot_object <- data() |>
        dplyr::filter(.data$facet_col == "Gastos") |>
        dplyr::mutate(tooltip = fmt_amount(.data$ejecutado_select, input$units)) |>
        ggplot2::ggplot(ggplot2::aes(.data$year, .data$ejecutado_select, fill = .data$fill_col)) +
        escala_y(input$units) +
        add_bar_layer(position = "dodge") +
        ggplot2::scale_fill_discrete("") +
        ggplot2::facet_wrap(~empresa, scales = "free_y") +
        ggplot2::labs(x = "Año", y = "") +
        common_plot_theme

      make_girafe_widget(plot_object)
    })

    output$plot_transferencias <- render_girafe_widget({
      plot_object <- data() |>
        dplyr::filter(.data$facet_col == "Impuestos y Transferencias") |>
        dplyr::group_by(.data$year, .data$empresa, .data$fill_col) |>
        dplyr::summarise(ejecutado = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(tooltip = fmt_amount(.data$ejecutado, input$units)) |>
        ggplot2::ggplot(ggplot2::aes(.data$year, .data$ejecutado, fill = .data$fill_col)) +
        escala_y(input$units) +
        add_bar_layer(position = "dodge") +
        ggplot2::scale_fill_discrete("") +
        ggplot2::facet_wrap(~empresa, scales = "free_y") +
        ggplot2::labs(
          x = "Año",
          y = "",
          caption = paste(
            "Los impuestos y contribuciones a la seguridad social se muestran con signo negativo.",
            "En el caso de las transferencias, el signo negativo muestra una version de resultados",
            "de la empresa y un signo positivo una transferencia recibida por la empresa.",
            sep = "\n"
          )
        ) +
        common_plot_theme

      make_girafe_widget(plot_object)
    })

    output$plot_inversiones <- render_girafe_widget({
      plot_object <- data() |>
        dplyr::filter(.data$facet_col == "Inversiones") |>
        dplyr::group_by(.data$year, .data$empresa, .data$fill_col) |>
        dplyr::summarise(ejecutado = sum(.data$ejecutado_select), .groups = "drop") |>
        dplyr::mutate(tooltip = fmt_amount(.data$ejecutado, input$units)) |>
        ggplot2::ggplot(ggplot2::aes(.data$year, .data$ejecutado, fill = .data$fill_col)) +
        escala_y(input$units) +
        add_bar_layer(position = "dodge") +
        ggplot2::scale_fill_manual(
          values = c(
            "Formación de Capital" = scales::alpha(opp_cols$dark_blue, 1),
            "Variación de Stocks" = scales::alpha(opp_cols$light_blue, 1)
          ),
          name = NULL
        ) +
        ggplot2::facet_wrap(~empresa, scales = "free_y") +
        ggplot2::labs(x = "Año", y = "") +
        common_plot_theme

      make_girafe_widget(plot_object)
    })

    output$plot_resultado <- render_girafe_widget({
      plot_object <- data() |>
        dplyr::filter(.data$facet_col == "Resultado") |>
        dplyr::mutate(tooltip = fmt_amount(.data$ejecutado_select, input$units)) |>
        ggplot2::ggplot(ggplot2::aes(.data$year, .data$ejecutado_select, fill = "Ejecutado")) +
        escala_y(input$units) +
        add_bar_layer() +
        ggplot2::scale_fill_manual(values = c("Ejecutado" = scales::alpha(opp_cols$dark_blue, 1)), name = NULL) +
        ggplot2::facet_wrap(~empresa, scales = "free_y") +
        ggplot2::labs(x = "Año", y = "") +
        common_plot_theme

      make_girafe_widget(plot_object)
    })
  })
}

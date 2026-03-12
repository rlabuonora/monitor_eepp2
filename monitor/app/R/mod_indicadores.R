indicadores_ui <- function(id, title) {
  ns <- shiny::NS(id)

  bslib::page_sidebar(
    theme = bslib::bs_theme(version = 5),
    sidebar = bslib::sidebar(
      open = "open",
      width = 320,
      htmltools::tags$style(htmltools::HTML("
    .sidebar .nav.nav-pills { flex-direction: column !important; gap: .25rem; }
    .sidebar .nav.nav-pills .nav-link { width: 100%; text-align: left; white-space: normal; }
  ")),
      bslib::navset_pill(
        id = ns("which_plot"),
        bslib::nav_panel("1.          Ingresos Corrientes", value = "Ingresos"),
        bslib::nav_panel("2.          Gastos", value = "Gastos"),
        bslib::nav_panel("3.          Transferencias e Impuestos", value = "Impuestos y Transferencias"),
        bslib::nav_panel("4.          Inversiones", value = "Inversiones"),
        bslib::nav_panel("5.          Resultado     ", value = "Resultado"),
        bslib::nav_panel("6.         Caja", value = "I")
      )
    ),
    bslib::card(
      full_screen = TRUE,
      bslib::card_header(shiny::textOutput(ns("plot_title"))),
      spinner_wrap(girafe_output_widget(ns("plot"), height = "540px"))
    )
  )
}

indicadores_server <- function(id, data, caja_mensual) {
  shiny::moduleServer(id, function(input, output, session) {
    output$plot_title <- shiny::renderText({
      switch(
        input$which_plot,
        Ingresos = stringr::str_c(id, " - Ingresos Corrientes"),
        Gastos = stringr::str_c(id, " - Gastos"),
        `Impuestos y Transferencias` = stringr::str_c(id, " - Transferencias e impuestos"),
        Inversiones = stringr::str_c(id, " - Inversiones"),
        Resultado = stringr::str_c(id, " - Resultado"),
        I = stringr::str_c(id, " - Caja Mensual")
      )
    })

    fmt_millions <- function(x) {
      scales::dollar(
        x,
        scale = 1e-6,
        prefix = "$ ",
        big.mark = ".",
        decimal.mark = ","
      )
    }

    scale_y_millions <- ggplot2::scale_y_continuous(
      labels = scales::dollar_format(
        scale = 1e-6,
        prefix = "$ ",
        big.mark = ".",
        decimal.mark = ","
      )
    )

    add_bar_layer <- function(position = NULL, ...) {
      if (is.null(position)) {
        return(ggiraph::geom_col_interactive(ggplot2::aes(tooltip = .data$tooltip), ...))
      }

      ggiraph::geom_col_interactive(ggplot2::aes(tooltip = .data$tooltip), position = position, ...)
    }

    month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sept", "Oct", "Nov", "Dic")
    tipo_levels <- c("Ejecutado", "Firmado")

    complete_monthly_plot_data <- function(df) {
      template <- expand.grid(
        label = levels(df$label),
        month_label = levels(df$month_label),
        tipo = tipo_levels,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
      ) |>
        dplyr::mutate(
          label = factor(.data$label, levels = levels(df$label)),
          month_label = factor(.data$month_label, levels = levels(df$month_label)),
          tipo = factor(.data$tipo, levels = tipo_levels)
        )

      template |>
        dplyr::left_join(df, by = c("label", "month_label", "tipo")) |>
        dplyr::mutate(
          observed = dplyr::coalesce(.data$observed, FALSE),
          valor = dplyr::coalesce(.data$valor, 0),
          tooltip = dplyr::if_else(.data$observed, .data$tooltip, NA_character_),
          alpha_value = dplyr::if_else(.data$observed, 1, 0)
        )
    }

    output$plot <- render_girafe_widget({
      if (input$which_plot == "I") {
        linea_label <- if (id %in% entes_minimo_gasto) {
          "Un mes de Gastos + Impuestos"
        } else if (id %in% entes_minimo_ingreso) {
          "Un mes de Ingresos "
        }

        plot_object <- caja_mensual |>
          dplyr::filter(.data$empresa == id) |>
          dplyr::mutate(
            tooltip = paste0(
              format(.data$fecha, "%b %Y"),
              ": ",
              fmt_millions(.data$saldo)
            )
          ) |>
          ggplot2::ggplot(ggplot2::aes(.data$fecha, .data$saldo)) +
          add_bar_layer(fill = opp_cols$dark_blue) +
          ggplot2::geom_hline(ggplot2::aes(yintercept = .data$saldo_minimo, color = linea_label), linetype = 2) +
          scale_y_millions +
          ggplot2::scale_color_manual("", values = setNames(opp_cols$gold, linea_label)) +
          ggplot2::scale_x_date(
            date_breaks = "1 month",
            labels = function(x) {
              stringr::str_to_title(scales::label_date("%b", locale = "es")(x))
            },
            expand = ggplot2::expansion(mult = c(0, 0))
          ) +
          ggplot2::labs(x = "Año", y = "", title = "")

        return(make_girafe_widget(plot_object))
      }

      plot_data <- data |>
        dplyr::filter(.data$empresa == id, .data$facet_col == input$which_plot) |>
        dplyr::filter(!is.na(.data$valor), is.finite(.data$valor)) |>
        dplyr::mutate(tooltip = fmt_millions(.data$valor)) |>
        droplevels()

      if (nrow(plot_data) == 0) {
        plot_object <- ggplot2::ggplot() +
          ggplot2::annotate(
            "text",
            x = 0,
            y = 0,
            label = "No hay datos disponibles para este indicador.",
            size = 6
          ) +
          ggplot2::xlim(-1, 1) +
          ggplot2::ylim(-1, 1) +
          ggplot2::theme_void()

        return(make_girafe_widget(plot_object))
      }

      plot_data <- plot_data |>
        dplyr::mutate(
          tipo = factor(.data$tipo, levels = tipo_levels),
          month_label = factor(
            stringr::str_to_title(scales::label_date("%b", locale = "es")(.data$fecha)),
            levels = month_levels
          ),
          observed = TRUE
        )

      facet_order <- plot_data |>
        dplyr::group_by(.data$label) |>
        dplyr::summarise(facet_size = max(abs(.data$valor), na.rm = TRUE), .groups = "drop") |>
        dplyr::arrange(dplyr::desc(.data$facet_size)) |>
        dplyr::pull(.data$label)

      plot_data <- plot_data |>
        dplyr::mutate(label = factor(.data$label, levels = facet_order)) |>
        complete_monthly_plot_data()

      dodge_pos <- ggplot2::position_dodge(width = 0.82)

      plot_object <- plot_data |>
        ggplot2::ggplot(ggplot2::aes(.data$month_label, .data$valor, fill = .data$tipo, group = .data$tipo)) +
        ggiraph::geom_col_interactive(
          ggplot2::aes(tooltip = .data$tooltip, alpha = .data$alpha_value),
          position = dodge_pos,
          width = 0.72
        ) +
        ggplot2::scale_fill_manual(
          "",
          values = c(
            "Ejecutado" = opp_cols$dark_blue,
            "Firmado" = opp_cols$light_blue
          ),
          breaks = c("Ejecutado", "Firmado"),
          drop = FALSE
        ) +
        ggplot2::scale_alpha_identity() +
        ggplot2::facet_wrap(~label, scales = "free_y", drop = TRUE) +
        scale_y_millions +
        ggplot2::scale_x_discrete(
          drop = FALSE,
          expand = ggplot2::expansion(mult = c(0.01, 0.01))
        ) +
        ggplot2::labs(x = "Año", y = "", title = "", fill = "") +
        ggplot2::theme(
          axis.text.x = ggplot2::element_text(size = 12),
          strip.text = ggplot2::element_text(size = 12)
        )

      make_girafe_widget(plot_object)
    })
  })
}

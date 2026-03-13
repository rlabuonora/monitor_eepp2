source(project_path("monitor", "shared", "R", "monetary_methodology.R"), local = FALSE)

run_test("monetary unit choices expose the configured 2024 constant-price label", {
  choices <- monetary_unit_choices("annual")
  assert_true(identical(unname(choices[["Millones de $ ctes. 2024"]]), "valor_2024"), "Annual unit choices no longer expose the expected constant-price label.")
})

run_test("augment_monetary_measures preserves nominal values and computes rebased outputs", {
  macro_series <- list(
    ipc_anual = data.frame(year = c(2024L, 2025L), ipc_base_24 = c(100, 110)),
    pib_nominal_anual = data.frame(year = c(2024L, 2025L), pib_nominal = c(1000, 2000)),
    dolar_promedio_anual = data.frame(year = c(2024L, 2025L), dolar_promedio = c(40, 50))
  )
  input <- data.frame(year = c(2024L, 2025L), valor = c(100, 220))

  out <- augment_monetary_measures(input, nominal_col = "valor", macro_series = macro_series)

  assert_true(identical(out$valor, input$valor), "Nominal values should remain unchanged.")
  assert_true(isTRUE(all.equal(out$valor_2024, c(100, 200))), "Constant-price conversion is incorrect.")
  assert_true(isTRUE(all.equal(out$valor_usd, c(2.5, 4.4))), "USD conversion is incorrect.")
  assert_true(isTRUE(all.equal(out$valor_pct_pib, c(0.1, 0.11))), "PIB share conversion is incorrect.")
})

run_test("augment_monetary_measures fails when a required year is missing from reference data", {
  macro_series <- list(
    ipc_anual = data.frame(year = 2024L, ipc_base_24 = 100),
    pib_nominal_anual = data.frame(year = 2024L, pib_nominal = 1000),
    dolar_promedio_anual = data.frame(year = 2024L, dolar_promedio = 40)
  )
  input <- data.frame(year = c(2024L, 2025L), valor = c(100, 220))

  err <- tryCatch(
    {
      augment_monetary_measures(input, nominal_col = "valor", macro_series = macro_series)
      NULL
    },
    error = function(e) conditionMessage(e)
  )

  assert_true(is.character(err) && grepl("missing required years: 2025", err, fixed = TRUE), "Missing-year validation did not trigger as expected.")
})

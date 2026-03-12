run_test("live processed caja_mensual matches expected firm thresholds and saldo path", {
  caja_mensual <- readRDS(project_path("monitor", "data", "processed", "caja_mensual.rds"))

  assert_true(is.data.frame(caja_mensual), "Processed caja_mensual is not a data frame.")
  assert_true(nrow(caja_mensual) == 132, "Processed caja_mensual row count changed.")
  assert_setequal(
    names(caja_mensual),
    c(
      "header_code", "sub_header_code", "item_code", "empresa",
      "saldo", "saldo_minimo_gastos", "saldo_minimo_ingresos", "saldo_minimo", "fecha"
    ),
    "Processed caja_mensual schema changed."
  )

  expected_minimos <- data.frame(
    empresa = c("AFE", "ANCAP", "ANCO", "ANP", "ANTEL", "ANV", "INC", "OSE", "URSEA", "URSEC", "UTE"),
    saldo_minimo = c(
      172474688,
      21822288449,
      687419343,
      777620642,
      4481573039,
      299242798,
      96049414,
      1889418443,
      22476692,
      77412972,
      7816657261
    ),
    stringsAsFactors = FALSE
  )

  actual_minimos <- unique(caja_mensual[c("empresa", "saldo_minimo")])
  assert_data_frame_equal(actual_minimos, expected_minimos, key_cols = "empresa", tolerance = 1e-6)

  afe_expected <- data.frame(
    fecha = as.Date(sprintf("2025-%02d-01", 1:12)),
    saldo = c(
      38381669, 67779676, 52098376, 65343576, 68758576, 73591576,
      84310276, 81022976, 87793276, 89850376, 100175276, 122321076
    )
  )
  afe_actual <- caja_mensual[caja_mensual$empresa == "AFE", c("fecha", "saldo")]
  assert_data_frame_equal(afe_actual, afe_expected, key_cols = "fecha", tolerance = 1e-6)
})

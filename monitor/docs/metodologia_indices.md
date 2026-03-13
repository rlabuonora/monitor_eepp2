# Metodologia indices

## Diagnostico breve

- La serie monetaria canonica del tablero es la serie anual nominal en pesos corrientes:
  - `valor` en [`series_anuales.rds`](../data/processed/series_anuales.rds)
- A partir de esa serie nominal se calculan:
  - precios constantes de 2024 (`valor_2024`)
  - millones de USD (`valor_usd`)
  - porcentaje del PIB (`valor_pct_pib`)
- La metodologia esta centralizada en:
  - [`monitor/shared/R/monetary_methodology.R`](../shared/R/monetary_methodology.R)
- La construccion de las series de referencia se realiza en:
  - [`monitor/shared/R/proyecciones.R`](../shared/R/proyecciones.R)
- La app consume los datasets ya transformados desde:
  - [`monitor/data/processed/`](../data/processed)

## Series de referencia utilizadas

Las series de referencia ya no se leen desde `series.xlsx`. El pipeline usa directamente los archivos fuente en [`monitor/data/raw/`](../data/raw):

- IPC:
  - archivo local: [`ipc_gral_y_variaciones_base_2022.xlsx`](../data/raw/ipc_gral_y_variaciones_base_2022.xlsx)
  - hoja: `IPC_Cua 2.0`
  - criterio: promedio anual del indice mensual
- Tipo de cambio:
  - archivo local: [`cotizacion_monedas.xlsx`](../data/raw/cotizacion_monedas.xlsx)
  - hoja: `Fuente BROU`
  - criterio: promedio anual de la cotizacion diaria del dolar
- PIB nominal:
  - archivo local: [`actividades_c.xlsx`](../data/raw/actividades_c.xlsx)
  - hoja: `Valores_C`
  - criterio: suma anual de los valores trimestrales del `PRODUCTO INTERNO BRUTO`

## Transformaciones implementadas

### Precios corrientes

Las cifras en precios corrientes se muestran en pesos uruguayos del ano correspondiente, sin ajuste por inflacion.

### Precios constantes de 2024

Las cifras en precios constantes de 2024 se calculan deflactando los montos corrientes con un indice anual reexpresado con base `2024 = 100`.

Formula aplicada:

- `valor_2024 = 100 * valor / ipc_base_24`

Donde:

- `ipc_base_24` es el promedio anual del IPC, rebasado para que `2024 = 100`

### Millones de USD

Las cifras en USD se calculan dividiendo el monto corriente por el tipo de cambio promedio anual.

Formula aplicada:

- `valor_usd = valor / dolar_promedio`

Convencion usada:

- tipo de cambio promedio anual

### Porcentaje del PIB

Las cifras como porcentaje del PIB se calculan dividiendo el monto corriente por el PIB nominal anual.

Formula aplicada:

- `valor_pct_pib = valor / pib_nominal`

## Parametros metodologicos actuales

Definidos en [`monitor/shared/R/monetary_methodology.R`](../shared/R/monetary_methodology.R):

- ano base para precios constantes: `2024`
- ano proyectado: `2025`
- crecimiento supuesto del PIB nominal para 2025: `2.5%`

Valores 2025 actualmente utilizados:

- IPC 2025 observado, con base 2024 = 100: `104.64918`
- dolar promedio anual 2025 observado: `39.86895`
- PIB nominal 2025: proyectado a partir de 2024 mientras no exista cierre anual observado

## Nota metodologica para usuarios

Las cifras en **precios corrientes** se presentan en pesos uruguayos del ano correspondiente, sin ajuste por variacion de precios.  
Las cifras en **precios constantes de 2024** se obtienen deflactando los valores corrientes mediante un indice anual reexpresado con base **2024 = 100**.  
Las cifras en **millones de USD** se calculan convirtiendo los montos corrientes con el **tipo de cambio promedio anual** disponible para cada ano.  
Las cifras como **% del PIB** se calculan sobre el **PIB nominal anual**.  
Las series de referencia utilizadas para estas conversiones se actualizan cuando se incorporan nuevos datos oficiales al tablero.

## Fuentes de actualizacion manual

- IPC (INE): `https://www5.ine.gub.uy/documents/Estad%C3%ADsticasecon%C3%B3micas/SERIES%20Y%20OTROS/IPC/Base%20Octubre%202022=100/IPC%20gral%20y%20variaciones_base%202022.xlsx`
- Cotizacion de monedas / dolar (INE): `https://www5.ine.gub.uy/documents/Estad%C3%ADsticasecon%C3%B3micas/SERIES%20Y%20OTROS/Cotizaci%C3%B3n%20monedas/Cotizaci%C3%B3n%20monedas.xlsx`
- PIB por industrias en valores corrientes (BCU):
  - fuente: `https://www.bcu.gub.uy/Estadisticas-e-Indicadores/Paginas/Series-Estadisticas-del-PIB-por-industrias.aspx`
  - archivo local: [`actividades_c.xlsx`](../data/raw/actividades_c.xlsx)

## Flujo de actualizacion

1. Actualizar los archivos fuente en [`monitor/data/raw/`](../data/raw):
   - [`ipc_gral_y_variaciones_base_2022.xlsx`](../data/raw/ipc_gral_y_variaciones_base_2022.xlsx)
   - [`cotizacion_monedas.xlsx`](../data/raw/cotizacion_monedas.xlsx)
   - [`actividades_c.xlsx`](../data/raw/actividades_c.xlsx)
2. Revisar si corresponde actualizar los supuestos del ano proyectado en:
   - [`monitor/shared/R/monetary_methodology.R`](../shared/R/monetary_methodology.R)
   - [`monitor/shared/R/proyecciones.R`](../shared/R/proyecciones.R)
3. Ejecutar `make app-data`
4. Ejecutar `make test-pipeline`
5. Ejecutar `make screenshots`

## Validaciones incorporadas

- unicidad por ano en IPC, PIB nominal y tipo de cambio
- ausencia de valores faltantes en las series de referencia
- valores estrictamente positivos en las series de referencia
- presencia de todos los anos requeridos antes de transformar montos monetarios

## Riesgos metodologicos vigentes

- El PIB para 2025 sigue dependiendo de un supuesto parametrizado mientras no exista cierre anual observado.
- La conversion a USD usa promedio anual; por eso solo debe considerarse cerrada cuando el ano de referencia esta completo.
- El PIB anual se toma desde la fila `PRODUCTO INTERNO BRUTO` de la hoja `Valores_C`; si el formato del archivo cambia, esa lectura debe revisarse.

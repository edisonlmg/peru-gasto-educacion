# =============================================================================
# IMPORTANCIA DE LA EDUCACIÓN EN EL PRESUPUESTO PÚBLICO Y EN EL PIB
#
# Objetivo: estimar el % que el gasto público en educación representa respecto
#           al gasto público total y al PIB
#
# Período de estimación: anual del 2016 – Actualidad
# =============================================================================


# --- Settings ---


if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(
  tidyverse,
  jsonlite,
  plotly,
  vroom,
  readxl,
  glue,
  renv,
  fs
  )

current_year <- as.integer(format(Sys.Date(), "%Y"))
years <- 2016:current_year-1


path_edu_pib_escale <- path("data/B._Recursos_Invertidos_en_Educación-Gasto_público_en_educación_como_porcentaje_del_PBI.xls")

path_edu_share_escale <- path("data/B._Recursos_Invertidos_en_Educación-Gasto_público_en_educación_como_porcentaje_del_gasto_público_total.xls")

url_pib <- "https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PM04946AA/json"

urls_gasto <- glue(
  "https://fs.datosabiertos.mef.gob.pe/datastorefiles/{years}-Gasto-Devengado",
  "{ifelse(years >= current_year - 1, '-Diario', '')}.csv"
)


# --- load & processing datasets ---


raw_edu_pib_escale <- read_excel(path_edu_pib_escale, skip = 4)

raw_edu_share_escale <- read_excel(path_edu_share_escale, skip = 4)

pib <- url_pib %>%
  fromJSON() %>%
  .$periods %>%
  mutate(values = as.numeric(values)) %>%
  rename(PERIODO = name, PIB_NOMINAL = values) %>%
  mutate(
    PIB_NOMINAL = round(as.numeric(PIB_NOMINAL) * 1e6, 0)
  )


# =============================================================================
# Debido al gran tamaño de los archivos de gasto (alrededor de 2Gb por año) se
# cargan y se procesan al mismo tiempo en cada iteración para no sobrecargar
# la memoria.
# 
# De acuerdo con la metodología del Minedu, se aplican los siguientes filtros
# a los dataset de gastos para obtener el gasto en Educación de acuerdo con los
# estándares de la Unesco:
# 
#   - Obtener FUNCION 22: EDUCACION.
#   - Excluir DIVISION_FUNCIONAL 48: EDUCACION SUPERIOR, mediante 
#     FUENTE_FINANCIAMIENTO 2: RECURSOS DIRECTAMENTE RECAUDADOS.
#   - Excluir PLIEGO:
#       - 114: CONSEJO NACIONAL DE CIENCIA, TECNOLOGIA E INNOVACION TECNOLOGICA
#       - 342: INSTITUTO PERUANO DEL DEPORTE
#       - 111: CENTRO VACACIONAL HUAMPANI
#   - Excluir cadenas de gasto:
#       - 4.1.3.1.2: A OTRAS UNIDADES DEL GOBIERNO REGIONAL
#       - 4.1.3.1.3: A OTRAS UNIDADES DEL GOBIERNO LOCAL
#       - 4.1.3.1.4: A OTRAS ENTIDADES PUBLICAS
#   - Excluir GENERICA 2:PENSIONES Y OTRAS PRESTACIONES SOCIALES
#   - Excluir GRUPO_FUNCIONAL 113: BECAS Y CREDITOS EDUCATIVOS
#   - Ecluir ACTIVIDAD_ACCION_OBRA 5000432: ALFABETIZACION
# =============================================================================


minedu_filters <- function(df) {
  df %>%
    filter(FUNCION == 22) %>%
    filter(!(DIVISION_FUNCIONAL == "048" & FUENTE_FINANCIAMIENTO == 2)) %>%
    filter(!(PLIEGO %in% c("114", "342", "111"))) %>%
    mutate(
      CADENA_GASTO = str_c(GENERICA, SUBGENERICA, SUBGENERICA_DET,
                     ESPECIFICA, ESPECIFICA_DET, sep = ".")
    ) %>%
    filter(!(CADENA_GASTO %in% c("4.1.3.1.2", "4.1.3.1.3", "4.1.3.1.4"))) %>%
    filter(GENERICA != 2) %>%
    filter(GRUPO_FUNCIONAL != "0113") %>%
    filter(ACTIVIDAD_ACCION_OBRA != 5000432)
}


summarize_spending <- function(df) {
  df %>%
    summarise(
      PERIODO         = first(ANO_EJE),
      PIA             = sum(MONTO_PIA,                            na.rm = TRUE),
      PIM             = sum(MONTO_PIM,                            na.rm = TRUE),
      DEVENGADO       = sum(MONTO_DEVENGADO_ANUAL,                na.rm = TRUE)
    )
}


processing_file <- function(url) {
  
  dataset_name <- basename(url)
  message("Procesando: ", dataset_name)
  
  df_raw <- vroom(url, show_col_types = FALSE)
  
  total_spending <- summarize_spending(df_raw)
  
  edu_spending <- df_raw %>% 
    minedu_filters() %>% 
    summarize_spending()
  
  total_spending %>%
    left_join(
      edu_spending,
      by = "PERIODO",
      suffix = c("", "_EDUCACION")
    )
}


education_spending <- map_dfr(urls_gasto, processing_file)


# --- transform dataset ---


edu_pib_escale <- raw_edu_pib_escale %>%
  select(-1) %>%
  slice(1) %>%
  unlist()

edu_share_escale <- raw_edu_share_escale %>%
  select(-1) %>%
  slice(1) %>%
  unlist()

education_spending <- education_spending %>%
  left_join(
    pib,
    by = "PERIODO"
  ) %>%
  mutate(
    EDUCACION_PRESUPUESTO = round(DEVENGADO_EDUCACION/DEVENGADO * 100, 1),
    EDUCACION_PIB = round(DEVENGADO_EDUCACION/PIB_NOMINAL * 100, 1),
    EDUCACION_PRESUPUESTO_ESCALE = edu_share_escale,
    EDUCACION_PIB_ESCALE = edu_pib_escale
  )

write_csv(education_spending, "data/peru_gasto_educacion.csv")


# --- Comparación de estimaciones ---


# 1. Cargar los datos
# Reemplaza estos valores con tus series reales
datos <- tibble(
  Anio = 2018:2023,
  ESCALE = c(17.5, 17.8, 18.2, 18.0, 18.5, 19.1),
  Estimacion_Propia = c(16.8, 17.0, 17.1, 17.5, 17.9, 18.4)
)

# 2. Calcular RMSE y Correlación de Pearson
metricas <- datos %>%
  summarise(
    RMSE = sqrt(mean((ESCALE - Estimacion_Propia)^2)),
    Correlacion = cor(ESCALE, Estimacion_Propia, method = "pearson")
  )

# Imprimir los resultados en consola
print("Métricas de Comparación:")
print(metricas)

# 3. Preparar los límites del gráfico para asegurar proporciones exactas
min_val <- min(c(datos$ESCALE, datos$Estimacion_Propia)) - 0.5
max_val <- max(c(datos$ESCALE, datos$Estimacion_Propia)) + 0.5

# 4. Construir el Gráfico de Dispersión (Scatter Plot) con Línea de 45°
grafico_dispersion <- ggplot(datos, aes(x = ESCALE, y = Estimacion_Propia)) +
  # Línea de identidad (45 grados) trazada primero para quedar al fondo
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#555555", linewidth = 0.8) +
  # Puntos de dispersión
  geom_point(color = "#002147", size = 3, alpha = 0.8) + # Tono azul formal/académico
  # Asegurar que los ejes tengan la misma escala (aspect ratio 1:1)
  coord_fixed(xlim = c(min_val, max_val), ylim = c(min_val, max_val)) +
  # Etiquetas y títulos
  labs(
    title = "Comparación de Estimaciones de Gasto Público en Educación",
    subtitle = "Reporte ESCALE vs. Estimación Propia (% del Presupuesto)",
    x = "Estimación ESCALE (Minedu)",
    y = "Estimación Propia",
    caption = "Nota: La línea punteada representa la coincidencia perfecta (identidad)."
  ) +
  # Tema visual formal y sobrio
  theme_bw() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 11, color = "#333333", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "grey30", hjust = 0.5),
    axis.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank() # Retirar cuadrícula menor para mayor limpieza
  )

# Visualizar el gráfico
print(grafico_dispersion)

# Opcional: Guardar el gráfico en alta calidad
# ggsave("comparacion_escale_propia.png", plot = grafico_dispersion, width = 6, height = 6, dpi = 300)




# --- visualizations ---





fig_educacion_presupuesto <- ggplot(
  education_spending, aes(x = PERIODO, y = EDUCACION_PRESUPUESTO)
  ) +
  # Línea de datos
  geom_line(color = "#005596", size = 1.2) + 
  # Puntos para resaltar cada periodo
  geom_point(color = "#005596", size = 3) +
  # Líneas de referencia (metas UNESCO)
  geom_hline(
    yintercept = c(15, 20), color = "red", linetype = "dashed", size = 0.8
  ) +
  # Mostrar todos los periodos en eje x
  scale_x_continuous(breaks = seq(2015, 2026, by = 1)) +
  # Etiquetas de ejes
  labs(
    title = "GASTO EN EDUCACIÓN COMO % DEL PRESUPUESTO PÚBLICO TOTAL",
    x = "", 
    y = "Porcentaje %"
    )

fig_educacion_presupuesto

ggsave("figures/fig_educacion_presupuesto.png", fig_educacion_presupuesto)


fig_educacion_pib <- ggplot(
  education_spending %>% slice(-n()), aes(x = PERIODO, y = EDUCACION_PIB)
  ) +
  # Línea de datos (azul ejecutivo)
  geom_line(color = "#005596", size = 1.2) + 
  # Puntos para resaltar cada periodo
  geom_point(color = "#005596", size = 3) +
  # Líneas de referencia (metas UNESCO)
  geom_hline(yintercept = c(4, 6), color = "red", linetype = "dashed", size = 0.8) +
  # Mostrar todos los periodos en eje x
  scale_x_continuous(breaks = seq(2015, 2025, by = 1)) +
  # Etiquetas de ejes
  labs(
    title = "GASTO EN EDUCACIÓN COMO % DEL PIB",
    x = "", 
    y = "Porcentaje %"
    )

fig_educacion_pib

ggsave("figures/fig_educacion_pib.png", fig_educacion_pib)


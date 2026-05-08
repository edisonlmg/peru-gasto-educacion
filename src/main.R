# =============================================================================
# IMPORTANCIA DE LA EDUCACIÓN EN EL PRESUPUESTO PÚBLICO Y EN EL PIB
#
# Objetivo: estimar el % que el gasto público en educación representa respecto
#           al gasto público total y al PIB
#
# Período de estimación: anual del 2016 – Actualidad
# =============================================================================


# --- instalar y activar librerias ---

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


# --- establecer parametros ---

current_year <- as.integer(format(Sys.Date(), "%Y"))
years <- 2016:(current_year - 1)


# --- establecer rutas ---

path_edu_pib_escale <- path("data/B._Recursos_Invertidos_en_Educación-Gasto_público_en_educación_como_porcentaje_del_PBI.xls")
path_edu_share_escale <- path("data/B._Recursos_Invertidos_en_Educación-Gasto_público_en_educación_como_porcentaje_del_gasto_público_total.xls")


# --- establecer urls ---

url_pib <- "https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PM04946AA/json"

urls_spending <- glue(
  "https://fs.datosabiertos.mef.gob.pe/datastorefiles/{years}-Gasto-Devengado",
  "{ifelse(years >= current_year - 1, '-Diario', '')}.csv"
)


# --- abrir datasets de ESCALE ---

raw_edu_pib_escale <- read_excel(path_edu_pib_escale, skip = 4)
raw_edu_share_escale <- read_excel(path_edu_share_escale, skip = 4)


# --- descargar PIB ---

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


# funcion que aplica filtros del Minedu

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


# funcion que agrega gasto por PIA, PIM y devengado

summarize_spending <- function(df) {
  df %>%
    summarise(
      PERIODO   = first(ANO_EJE),
      PIA       = sum(MONTO_PIA,             na.rm = TRUE),
      PIM       = sum(MONTO_PIM,             na.rm = TRUE),
      DEVENGADO = sum(MONTO_DEVENGADO_ANUAL, na.rm = TRUE)
    )
}


# funcion que orquesta descargas, filtros y agregacion

processing_file <- function(url) {
  
  dataset_name <- basename(url)
  message("Procesando: ", dataset_name)
  
  # Asignamos el resultado de tryCatch a df_raw
  df_raw <- tryCatch(
    expr = {
      vroom(url, show_col_types = FALSE)
    },
    error = function(e) {
      message("Error en: ", dataset_name, " - ", conditionMessage(e))
      return(NULL) # Este NULL ahora se asignará a df_raw
    }
  )
  
  # Ahora esta validación funcionará correctamente
  if(is.null(df_raw)) {
    message("Saltando archivo por error previo...")
    return(NULL)
  }
  
  total_spending <- summarize_spending(df_raw)
  
  edu_spending <- df_raw %>% 
    minedu_filters() %>% 
    summarize_spending()
  
  resultado <- total_spending %>%
    left_join(
      edu_spending,
      by = "PERIODO",
      suffix = c("", "_EDUCACION")
    )
  
  return(resultado)
}


# aplica funcion processing_file a todas las urls de gasto y une un solo df

education_spending <- map(urls_spending, processing_file) %>%
  bind_rows()


# --- procesamiento de datasets ---


# Extrae serie de gasto en educacion como % del PIB (nacional)

edu_pib_escale <- raw_edu_pib_escale %>%
  select(-1) %>%
  slice(1) %>%
  unlist()


# Extrae serie de gasto en educacion como % del presupuesto publico (nacional)

edu_share_escale <- raw_edu_share_escale %>%
  select(-1) %>%
  slice(1) %>%
  unlist()


# Crea variables calculadas y agrega indicadores de ESCALE

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


# Guarda el resultado

write_csv(education_spending, "data/peru_gasto_educacion.csv")


# --- Comparación de estimaciones ---


# Calcular RMSE y Correlación de Pearson

metrics <- education_spending %>%
  summarise(
    RMSE_SHARE = sqrt(mean((EDUCACION_PRESUPUESTO_ESCALE - EDUCACION_PRESUPUESTO)^2)),
    CORR_SHARE = cor(EDUCACION_PRESUPUESTO_ESCALE, EDUCACION_PRESUPUESTO, method = "pearson"),
    RMSE_PIB   = sqrt(mean((EDUCACION_PIB_ESCALE - EDUCACION_PIB)^2)),
    CORR_PIB   = cor(EDUCACION_PIB_ESCALE, EDUCACION_PIB, method = "pearson")
  )

message("Métricas de Comparación:")
print(metrics)


# Grafico de Dispersion para gasto en educacion como % del total

min_val <- min(
  c(
    education_spending$EDUCACION_PRESUPUESTO_ESCALE,
    education_spending$EDUCACION_PRESUPUESTO
    )
  ) - 0.5

max_val <- max(
  c(
    education_spending$EDUCACION_PRESUPUESTO_ESCALE,
    education_spending$EDUCACION_PRESUPUESTO
    )
  ) + 0.5

fig1_share <- ggplot(datos, aes(x = EDUCACION_PRESUPUESTO_ESCALE, y = EDUCACION_PRESUPUESTO)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#555555", linewidth = 0.8) +
  geom_point(color = "#002147", size = 3, alpha = 0.8) +
  coord_fixed(xlim = c(min_val, max_val), ylim = c(min_val, max_val)) +
  labs(
    title = "Comparación de Estimaciones de Gasto Público en Educación",
    subtitle = "Reporte ESCALE vs. Estimación Propia (% del Presupuesto)",
    x = "Estimación ESCALE (Minedu)",
    y = "Estimación Propia",
    caption = "Nota: La línea punteada representa la coincidencia perfecta (identidad)."
  ) +
  theme_bw() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 11, color = "#333333", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "grey30", hjust = 0.5),
    axis.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank()
  )

print(fig1_share)

ggsave(
  "figures/comparacion_presupuesto.png",
  plot = fig1_share,
  width = 6, 
  height = 6, 
  dpi = 300
  )


# Grafico de Dispersion para gasto en educacion como % del PIB

min_val <- min(
  c(
    education_spending$EDUCACION_PIB_ESCALE,
    education_spending$EDUCACION_PIB
  )
) - 0.5

max_val <- max(
  c(
    education_spending$EDUCACION_PIB_ESCALE,
    education_spending$EDUCACION_PIB
  )
) + 0.5

fig2_pib <- ggplot(education_spending, aes(x = EDUCACION_PIB_ESCALE, y = EDUCACION_PIB)) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#555555", linewidth = 0.8) +
  geom_point(color = "#002147", size = 3, alpha = 0.8) +
  coord_fixed(xlim = c(min_val, max_val), ylim = c(min_val, max_val)) +
  labs(
    title = "Comparación de Estimaciones de Gasto Público en Educación",
    subtitle = "Reporte ESCALE vs. Estimación Propia (% del PIB)",
    x = "Estimación ESCALE (Minedu)",
    y = "Estimación Propia",
    caption = "Nota: La línea punteada representa la coincidencia perfecta (identidad)."
  ) +
  theme_bw() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 11, color = "#333333", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "grey30", hjust = 0.5),
    axis.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank()
  )

print(fig2_pib)

ggsave(
  "figures/comparacion_pib.png",
  plot = fig2_pib,
  width = 6, 
  height = 6, 
  dpi = 300
)


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


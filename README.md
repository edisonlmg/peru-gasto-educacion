# peru-gasto-educacion

El Ministerio de Educación (Minedu) publica en el portal ESCALE la serie anual sobre la importancia del gasto en educación en Perú, medida tanto como proporción del presupuesto público total como del Producto Interno Bruto (PIB). Sin embargo, estos indicadores se difunden con varios meses de rezago respecto a la disponibilidad de la información base: el gasto público, publicado por el Ministerio de Economía y Finanzas (MEF), y el PIB, publicado por el Instituto Nacional de Estadística e Informática (INEI). En ese contexto, este repositorio documenta y automatiza la metodología necesaria para estimar y actualizar oportunamente dichos indicadores.

[![Project Status: Active – The project has reached a stable, usable actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

---

## Fuentes de información

**Ministerio de Educación - Minedu**:

- Gasto público en educación como porcentaje del gasto público total: [Repositorio](https://escale.minedu.gob.pe/ueetendencias2016?p_auth=J9cwlH4c&p_p_id=TendenciasActualPortlet2016_WAR_tendencias2016portlet_INSTANCE_t6xG&p_p_lifecycle=1&p_p_state=normal&p_p_mode=view&p_p_col_id=column-1&p_p_col_pos=1&p_p_col_count=3&_TendenciasActualPortlet2016_WAR_tendencias2016portlet_INSTANCE_t6xG_idCuadro=107) | [METADATA](https://escale.minedu.gob.pe/tendencias-2016-portlet/servlet/tendencias/archivo?idCuadro=107&tipo=meta).
- Gasto público en educación como porcentaje del PBI: [Repositorio](https://escale.minedu.gob.pe/ueetendencias2016?p_auth=J9cwlH4c&p_p_id=TendenciasActualPortlet2016_WAR_tendencias2016portlet_INSTANCE_t6xG&p_p_lifecycle=1&p_p_state=normal&p_p_mode=view&p_p_col_id=column-1&p_p_col_pos=1&p_p_col_count=3&_TendenciasActualPortlet2016_WAR_tendencias2016portlet_INSTANCE_t6xG_idCuadro=107) | [METADATA](https://escale.minedu.gob.pe/tendencias-2016-portlet/servlet/tendencias/archivo?idCuadro=105&tipo=meta).

**Ministerio de Economía y Finanzas - MEF**:

- Gasto público: [Repositorio](https://datosabiertos.mef.gob.pe/dataset/presupuesto-y-ejecucion-de-gasto-devengado-mensual).

**Banco Central de Reserva - BCR**

- Producto Interno Bruto (PIB): [Repositorio](https://estadisticas.bcrp.gob.pe/estadisticas/series/anuales/resultados/PM04946AA/html)

## Tecnología

*   **Language:** R 4.5.2

## Estructura del proyecto
```text
├── 📁 data/                       # Cached .json files downloaded from the SSI portal
├── 📁 src/
│   ├── 📄 main.R                  # extrae y procesa la información
├── 📄 README.md                   # Project documentation and usage instructions
├── 📄 LICENSE                     # License information for distribution and usage
├── 📄 .gitignore                  # Files and folders to be ignored by Git
```

## Instalar entorno virtual

Este proyecto utiliza `renv` para gestionar las versiones de los paquetes de **R** y asegurar la reproducibilidad.

1. Instalar `renv` (si no lo tienes)

```r
install.packages("renv")
```

2. Restaurar las librerías del proyecto

```r
renv::restore()
```

## Uso

Ejecuta el siguiente comando en la terminal:

```bash
Rscript src/main.R
```

## Contribuye

Se aceptan contribuciones mediante issues o pull requests para mejorar el programa.

## Licencia

Este proyecto está bajo la licencia Apache 2.0. Consulte el archivo LICENSE para obtener más detalles.

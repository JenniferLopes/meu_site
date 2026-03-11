# ============================================================
#  DATA QUALITY INSPECTOR — Producao de Graos
#  Como rodar:
#    1. Abra este arquivo no RStudio
#    2. Clique em "Run App" (ou: shiny::runApp("data_quality_app.R"))
#    3. Faca upload do arquivo producao_graos_baguncada.csv
#    4. Clique em "Analisar Base"
# ============================================================

# -- Instalar pacotes caso necessario ----------------------
pkgs <- c("shiny", "shinydashboard", "tidyverse", "janitor",
          "DT", "openxlsx", "scales", "shinyWidgets")

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install)) {
  install.packages(to_install, repos = "https://cran.r-project.org")
}

library(shiny)
library(shinydashboard)
library(tidyverse)
library(janitor)
library(DT)
library(openxlsx)
library(scales)
library(shinyWidgets)

# =============================================================
#  FUNCOES AUXILIARES
# =============================================================

# Score geral de qualidade (0 a 100)
calcular_score <- function(df) {
  n_total <- nrow(df) * ncol(df)
  n_na    <- sum(is.na(df))
  n_dup   <- sum(duplicated(df))
  pct_na  <- n_na / n_total
  pct_dup <- n_dup / nrow(df)
  score   <- round((1 - pct_na * 0.5 - pct_dup * 0.5) * 100)
  max(0, min(100, score))
}

# Detectar outliers por IQR em colunas numericas
detectar_outliers <- function(df) {
  nums <- df %>% select(where(is.numeric))
  if (ncol(nums) == 0) return(tibble(Aviso = "Sem colunas numericas."))
  purrr::map_dfr(names(nums), function(col) {
    x   <- nums[[col]]
    q1  <- quantile(x, .25, na.rm = TRUE)
    q3  <- quantile(x, .75, na.rm = TRUE)
    iqr <- q3 - q1
    out <- sum(x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr), na.rm = TRUE)
    tibble(
      Coluna          = col,
      Outliers        = out,
      Limite_Inferior = round(q1 - 1.5 * iqr, 2),
      Limite_Superior = round(q3 + 1.5 * iqr, 2)
    )
  })
}

# Detectar colunas com valores nao numericos em colunas mistas
detectar_tipos_inconsistentes <- function(df_raw) {
  purrr::map_dfr(names(df_raw), function(col) {
    vals      <- df_raw[[col]]
    tentativa <- suppressWarnings(as.numeric(vals))
    n_total   <- sum(!is.na(vals))
    n_ok      <- sum(!is.na(tentativa))
    n_ruim    <- n_total - n_ok
    if (n_ruim > 0 && n_ok > 0) {
      exemplos <- unique(vals[is.na(tentativa) & !is.na(vals)])
      tibble(
        Coluna            = col,
        Valores_Invalidos = n_ruim,
        Exemplos          = paste(exemplos[1:min(3, length(exemplos))], collapse = ", ")
      )
    } else NULL
  })
}

# Detectar inconsistencias de maiusculas/minusculas e espacos extras
detectar_padronizacao <- function(df) {
  chars <- df %>% select(where(is.character))
  if (ncol(chars) == 0) return(NULL)
  purrr::map_dfr(names(chars), function(col) {
    vals      <- unique(na.omit(chars[[col]]))
    grupos    <- str_trim(str_to_lower(vals))
    n_grupos  <- n_distinct(grupos)
    n_vals    <- n_distinct(vals)
    variacoes <- n_vals - n_grupos
    if (variacoes > 0) {
      dupl_idx <- which(duplicated(grupos))
      tibble(
        Coluna           = col,
        Variacoes_Grafia = variacoes,
        Exemplos         = paste(vals[dupl_idx][1:min(3, length(dupl_idx))], collapse = " | ")
      )
    } else NULL
  })
}

# =============================================================
#  UI
# =============================================================
ui <- dashboardPage(
  skin = "green",
  
  dashboardHeader(
    title = "Data Quality Inspector",
    titleWidth = 290
  ),
  
  dashboardSidebar(
    width = 265,
    br(),
    fileInput("arquivo", "Carregar CSV",
              accept = ".csv",
              buttonLabel = "Escolher arquivo",
              placeholder = "Nenhum arquivo selecionado"),
    tags$hr(),
    selectInput("separador", "Separador de coluna",
                choices = c("Virgula (,)" = ",",
                            "Ponto e virgula (;)" = ";",
                            "Tab (\\t)" = "\t"),
                selected = ","),
    selectInput("encoding", "Encoding do arquivo",
                choices = c("UTF-8" = "UTF-8", "Latin-1" = "latin1"),
                selected = "UTF-8"),
    tags$hr(),
    actionBttn("analisar", "Analisar Base",
               style = "fill", color = "success", size = "md", block = TRUE),
    tags$hr(),
    downloadButton("baixar_excel", "Exportar Relatorio Excel",
                   class = "btn-success btn-block"),
    br(),
    tags$p(
      style = "padding:10px 14px; color:#aaa; font-size:11px; line-height:1.5;",
      "1. Carregue o CSV acima", br(),
      "2. Clique em Analisar Base", br(),
      "3. Navegue pelas abas", br(),
      "4. Exporte o relatorio em Excel"
    )
  ),
  
  dashboardBody(
    tags$head(tags$style(HTML("
      .skin-green .main-header .logo { background:#1a6b2a !important; }
      .skin-green .main-header .navbar { background:#1a6b2a !important; }
      .skin-green .main-sidebar { background:#2c3e50 !important; }
      .skin-green .sidebar-menu > li.active > a { border-left-color:#27ae60 !important; }
      .nav-tabs-custom > .nav-tabs > li.active { border-top-color:#27ae60 !important; }
      .box.box-solid.box-success > .box-header { background:#27ae60 !important; }
    "))),
    
    # -- KPIs ---------------------------------------------------
    fluidRow(
      valueBoxOutput("box_score",  width = 3),
      valueBoxOutput("box_linhas", width = 3),
      valueBoxOutput("box_nulos",  width = 3),
      valueBoxOutput("box_dupl",   width = 3)
    ),
    
    # -- Abas ---------------------------------------------------
    tabBox(width = 12,
           
           # 1. Visao Geral
           tabPanel("Visao Geral",
                    fluidRow(
                      box(title = "Score de Preenchimento por Coluna",
                          width = 6, status = "success", solidHeader = TRUE,
                          plotOutput("plot_score_col", height = "380px")),
                      box(title = "Mapa de Valores Ausentes",
                          width = 6, status = "success", solidHeader = TRUE,
                          plotOutput("plot_missing_mapa", height = "380px"))
                    )
           ),
           
           # 2. Valores Ausentes
           tabPanel("Valores Ausentes",
                    fluidRow(
                      box(title = "Analise de Completude por Coluna",
                          width = 12, status = "warning", solidHeader = TRUE,
                          DTOutput("tabela_missing"))
                    )
           ),
           
           # 3. Duplicatas
           tabPanel("Duplicatas",
                    fluidRow(
                      box(title = "Linhas Duplicadas Encontradas",
                          width = 12, status = "danger", solidHeader = TRUE,
                          DTOutput("tabela_dupl"))
                    )
           ),
           
           # 4. Outliers
           tabPanel("Outliers",
                    fluidRow(
                      box(title = "Resumo de Outliers por Coluna",
                          width = 5, status = "warning", solidHeader = TRUE,
                          DTOutput("tabela_outliers")),
                      box(title = "Boxplot",
                          width = 7, status = "success", solidHeader = TRUE,
                          selectInput("col_boxplot", "Selecione a coluna:", choices = NULL),
                          plotOutput("plot_boxplot", height = "300px"))
                    )
           ),
           
           # 5. Padronizacao
           tabPanel("Padronizacao",
                    fluidRow(
                      box(title = "Inconsistencias de Grafia (maiusculas, minusculas, espacos)",
                          width = 12, status = "warning", solidHeader = TRUE,
                          DTOutput("tabela_padronizacao"))
                    )
           ),
           
           # 6. Tipos Inconsistentes
           tabPanel("Tipos Inconsistentes",
                    fluidRow(
                      box(title = "Colunas com Valores Invalidos para Tipo Numerico",
                          width = 12, status = "danger", solidHeader = TRUE,
                          DTOutput("tabela_tipos"))
                    )
           ),
           
           # 7. Dados Limpos
           tabPanel("Dados Limpos",
                    fluidRow(
                      box(title = "Preview apos limpeza automatica (janitor + tidyverse)",
                          width = 12, status = "success", solidHeader = TRUE,
                          p(style = "color:#555; font-size:12px;",
                            "Operacoes aplicadas: clean_names() | remove_empty() | distinct() | str_trim() | str_to_title()"),
                          DTOutput("tabela_limpa"),
                          br(),
                          downloadButton("baixar_csv_limpo", "Baixar CSV Limpo",
                                         class = "btn-success"))
                    )
           ),
           
           # 8. Dados Brutos
           tabPanel("Dados Brutos",
                    fluidRow(
                      box(title = "Dados Originais sem Alteracao",
                          width = 12, solidHeader = TRUE,
                          DTOutput("tabela_bruta"))
                    )
           )
    )
  )
)

# =============================================================
#  SERVER
# =============================================================
server <- function(input, output, session) {
  
  # -- Leitura do CSV ------------------------------------------
  dados_raw <- eventReactive(input$analisar, {
    req(input$arquivo)
    read.csv(
      input$arquivo$datapath,
      sep              = input$separador,
      encoding         = input$encoding,
      stringsAsFactors = FALSE,
      na.strings       = c("", "NA", "N/A", "n/a", "null", "NULL")
    )
  })
  
  # -- Limpeza automatica com janitor + tidyverse --------------
  dados_limpos <- reactive({
    req(dados_raw())
    dados_raw() %>%
      janitor::clean_names() %>%
      janitor::remove_empty(which = c("rows", "cols")) %>%
      dplyr::distinct() %>%
      dplyr::mutate(
        dplyr::across(where(is.character),
                      ~ stringr::str_trim(stringr::str_to_title(.)))
      )
  })
  
  # -- KPI: Score de qualidade ---------------------------------
  output$box_score <- renderValueBox({
    req(dados_raw())
    score <- calcular_score(dados_raw())
    cor   <- if (score >= 80) "green" else if (score >= 60) "yellow" else "red"
    valueBox(paste0(score, "%"), "Score de Qualidade",
             icon = icon("star"), color = cor)
  })
  
  output$box_linhas <- renderValueBox({
    req(dados_raw())
    valueBox(format(nrow(dados_raw()), big.mark = "."),
             "Linhas Carregadas", icon = icon("table"), color = "blue")
  })
  
  output$box_nulos <- renderValueBox({
    req(dados_raw())
    df  <- dados_raw()
    n   <- sum(is.na(df))
    pct <- round(n / (nrow(df) * ncol(df)) * 100, 1)
    valueBox(paste0(n, "  (", pct, "%)"),
             "Valores Ausentes", icon = icon("circle-xmark"), color = "orange")
  })
  
  output$box_dupl <- renderValueBox({
    req(dados_raw())
    valueBox(sum(duplicated(dados_raw())),
             "Linhas Duplicadas", icon = icon("copy"), color = "purple")
  })
  
  # -- Plot: score de preenchimento por coluna -----------------
  output$plot_score_col <- renderPlot({
    req(dados_raw())
    df <- dados_raw()
    tibble(
      coluna = names(df),
      pct_ok = purrr::map_dbl(names(df), ~ sum(!is.na(df[[.x]])) / nrow(df) * 100)
    ) %>%
      dplyr::mutate(
        coluna = forcats::fct_reorder(coluna, pct_ok),
        status = dplyr::case_when(
          pct_ok >= 95 ~ "Otimo (>=95%)",
          pct_ok >= 80 ~ "Bom (80-95%)",
          TRUE         ~ "Critico (<80%)"
        )
      ) %>%
      ggplot(aes(x = coluna, y = pct_ok, fill = status)) +
      geom_col(width = 0.7) +
      geom_text(aes(label = paste0(round(pct_ok), "%")),
                hjust = -0.15, size = 3.2, fontface = "bold") +
      coord_flip() +
      scale_fill_manual(values = c(
        "Otimo (>=95%)"  = "#27ae60",
        "Bom (80-95%)"   = "#f39c12",
        "Critico (<80%)" = "#e74c3c"
      )) +
      scale_y_continuous(limits = c(0, 115), labels = function(x) paste0(x, "%")) +
      labs(x = NULL, y = "% de Preenchimento", fill = "Status") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom",
            panel.grid.major.y = element_blank())
  })
  
  # -- Plot: mapa de valores ausentes --------------------------
  output$plot_missing_mapa <- renderPlot({
    req(dados_raw())
    df <- dados_raw()
    df %>%
      dplyr::mutate(linha = dplyr::row_number()) %>%
      tidyr::pivot_longer(-linha, names_to = "coluna", values_to = "valor") %>%
      dplyr::mutate(ausente = is.na(valor)) %>%
      ggplot(aes(x = coluna, y = linha, fill = ausente)) +
      geom_tile(color = "white", linewidth = 0.05) +
      scale_fill_manual(
        values = c("FALSE" = "#d4edda", "TRUE" = "#e74c3c"),
        labels = c("Presente", "Ausente")
      ) +
      labs(x = NULL, y = "Numero da Linha", fill = NULL,
           caption = "Vermelho = valor ausente | Verde = valor presente") +
      theme_minimal(base_size = 10) +
      theme(axis.text.x  = element_text(angle = 45, hjust = 1, size = 9),
            legend.position = "bottom",
            panel.grid   = element_blank())
  })
  
  # -- Tabela: ausentes ----------------------------------------
  output$tabela_missing <- renderDT({
    req(dados_raw())
    df <- dados_raw()
    tibble(
      Coluna        = names(df),
      Tipo          = purrr::map_chr(df, ~ class(.x)[1]),
      Ausentes_n    = purrr::map_int(df, ~ sum(is.na(.x))),
      Ausentes_pct  = purrr::map_chr(df, ~ paste0(round(mean(is.na(.x)) * 100, 1), "%")),
      Preenchidos_n = purrr::map_int(df, ~ sum(!is.na(.x)))
    ) %>%
      dplyr::arrange(dplyr::desc(Ausentes_n)) %>%
      datatable(rownames = FALSE,
                options  = list(pageLength = 15, dom = "frtip"),
                colnames = c("Coluna", "Tipo", "Ausentes (n)",
                             "Ausentes (%)", "Preenchidos (n)")) %>%
      formatStyle("Ausentes_n",
                  backgroundColor = styleInterval(c(0, 5),
                                                  c("#d4edda", "#fff3cd", "#f8d7da")))
  })
  
  # -- Tabela: duplicatas --------------------------------------
  output$tabela_dupl <- renderDT({
    req(dados_raw())
    df   <- dados_raw()
    dupl <- df[duplicated(df) | duplicated(df, fromLast = TRUE), ]
    if (nrow(dupl) == 0) {
      datatable(
        data.frame(Resultado = "Nenhuma linha duplicada encontrada."),
        rownames = FALSE
      )
    } else {
      datatable(dupl, rownames = TRUE,
                options = list(pageLength = 10, scrollX = TRUE)) %>%
        formatStyle(0, backgroundColor = "#fff3cd")
    }
  })
  
  # -- Tabela: outliers ----------------------------------------
  output$tabela_outliers <- renderDT({
    req(dados_raw())
    out_df <- detectar_outliers(dados_raw())
    datatable(out_df, rownames = FALSE,
              options = list(pageLength = 15, dom = "frtip")) %>%
      formatStyle("Outliers",
                  backgroundColor = styleInterval(c(0, 3),
                                                  c("#d4edda", "#fff3cd", "#f8d7da")))
  })
  
  # -- Atualizar choices do boxplot ----------------------------
  observe({
    req(dados_raw())
    nums <- names(dados_raw() %>% dplyr::select(where(is.numeric)))
    updateSelectInput(session, "col_boxplot", choices = nums)
  })
  
  # -- Plot: boxplot de outliers -------------------------------
  output$plot_boxplot <- renderPlot({
    req(dados_raw(), input$col_boxplot)
    df  <- dados_raw()
    col <- input$col_boxplot
    ggplot(df, aes(y = .data[[col]])) +
      geom_boxplot(fill = "#27ae60", alpha = 0.65, color = "#1a6b2a",
                   outlier.colour = "#e74c3c", outlier.size = 3,
                   outlier.shape = 16) +
      stat_summary(fun = mean, geom = "point", shape = 18,
                   size = 4, color = "#2980b9") +
      labs(title = paste("Distribuicao:", col),
           subtitle = "Vermelho = outlier  |  Azul = media",
           y = col, x = NULL) +
      theme_minimal(base_size = 13) +
      theme(axis.text.x = element_blank(),
            panel.grid.major.x = element_blank())
  })
  
  # -- Tabela: padronizacao ------------------------------------
  output$tabela_padronizacao <- renderDT({
    req(dados_raw())
    res <- detectar_padronizacao(dados_raw())
    if (is.null(res) || nrow(res) == 0) {
      datatable(
        data.frame(Resultado = "Nenhuma inconsistencia de padronizacao encontrada."),
        rownames = FALSE
      )
    } else {
      datatable(res, rownames = FALSE,
                options  = list(pageLength = 15, dom = "frtip"),
                colnames = c("Coluna", "Variacoes de Grafia", "Exemplos")) %>%
        formatStyle("Variacoes_Grafia",
                    backgroundColor = styleInterval(0, c("#d4edda", "#f8d7da")))
    }
  })
  
  # -- Tabela: tipos inconsistentes ----------------------------
  output$tabela_tipos <- renderDT({
    req(dados_raw())
    res <- detectar_tipos_inconsistentes(dados_raw())
    if (is.null(res) || nrow(res) == 0) {
      datatable(
        data.frame(Resultado = "Nenhum tipo inconsistente detectado."),
        rownames = FALSE
      )
    } else {
      datatable(res, rownames = FALSE,
                options  = list(pageLength = 15, dom = "frtip"),
                colnames = c("Coluna", "Valores Invalidos", "Exemplos")) %>%
        formatStyle("Valores_Invalidos", backgroundColor = "#f8d7da")
    }
  })
  
  # -- Tabela: dados limpos ------------------------------------
  output$tabela_limpa <- renderDT({
    req(dados_limpos())
    datatable(dados_limpos(), rownames = FALSE,
              options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # -- Tabela: dados brutos ------------------------------------
  output$tabela_bruta <- renderDT({
    req(dados_raw())
    datatable(dados_raw(), rownames = FALSE,
              options = list(pageLength = 10, scrollX = TRUE))
  })
  
  # -- Download: CSV limpo ------------------------------------
  output$baixar_csv_limpo <- downloadHandler(
    filename = function() paste0("dados_limpos_", Sys.Date(), ".csv"),
    content  = function(file) {
      write.csv(dados_limpos(), file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )
  
  # -- Download: relatorio Excel ------------------------------
  output$baixar_excel <- downloadHandler(
    filename = function() paste0("relatorio_qualidade_", Sys.Date(), ".xlsx"),
    content  = function(file) {
      req(dados_raw())
      df <- dados_raw()
      wb <- createWorkbook()
      
      h_style  <- createStyle(fgFill = "#1a6b2a", fontColour = "#FFFFFF",
                              textDecoration = "bold", halign = "center",
                              border = "Bottom", borderColour = "#145214")
      ok_style <- createStyle(fgFill = "#d4edda")
      w_style  <- createStyle(fgFill = "#fff3cd")
      e_style  <- createStyle(fgFill = "#f8d7da")
      
      # Aba 1: Resumo executivo
      addWorksheet(wb, "Resumo")
      resumo <- tibble(
        Metrica = c("Score de Qualidade (%)",
                    "Total de Linhas",
                    "Total de Colunas",
                    "Total Valores Ausentes",
                    "Percentual de Ausentes",
                    "Linhas Duplicadas Exatas",
                    "Data da Analise"),
        Valor = c(
          calcular_score(df),
          nrow(df),
          ncol(df),
          sum(is.na(df)),
          paste0(round(sum(is.na(df)) / (nrow(df) * ncol(df)) * 100, 1), "%"),
          sum(duplicated(df)),
          as.character(Sys.Date())
        )
      )
      writeDataTable(wb, "Resumo", resumo, headerStyle = h_style, tableStyle = "TableStyleLight9")
      setColWidths(wb, "Resumo", cols = 1:2, widths = c(38, 22))
      
      # Aba 2: Valores ausentes
      addWorksheet(wb, "Valores_Ausentes")
      miss_df <- tibble(
        Coluna        = names(df),
        Tipo          = purrr::map_chr(df, ~ class(.x)[1]),
        Ausentes_n    = purrr::map_int(df, ~ sum(is.na(.x))),
        Ausentes_pct  = purrr::map_dbl(df, ~ round(mean(is.na(.x)) * 100, 1)),
        Preenchidos_n = purrr::map_int(df, ~ sum(!is.na(.x)))
      ) %>% dplyr::arrange(dplyr::desc(Ausentes_n))
      writeDataTable(wb, "Valores_Ausentes", miss_df, headerStyle = h_style, tableStyle = "TableStyleLight9")
      setColWidths(wb, "Valores_Ausentes", cols = 1:5, widths = c(28, 12, 14, 14, 16))
      
      # Aba 3: Duplicatas
      addWorksheet(wb, "Duplicatas")
      dupl_df <- df[duplicated(df) | duplicated(df, fromLast = TRUE), ]
      if (nrow(dupl_df) > 0) {
        writeDataTable(wb, "Duplicatas", dupl_df, headerStyle = h_style, tableStyle = "TableStyleLight9")
      } else {
        writeData(wb, "Duplicatas", data.frame(Resultado = "Nenhuma duplicata encontrada."))
      }
      
      # Aba 4: Outliers
      addWorksheet(wb, "Outliers")
      writeDataTable(wb, "Outliers", detectar_outliers(df), headerStyle = h_style, tableStyle = "TableStyleLight9")
      setColWidths(wb, "Outliers", cols = 1:4, widths = c(28, 12, 18, 18))
      
      # Aba 5: Padronizacao
      addWorksheet(wb, "Padronizacao")
      pad_df <- detectar_padronizacao(df)
      if (!is.null(pad_df) && nrow(pad_df) > 0) {
        writeDataTable(wb, "Padronizacao", pad_df, headerStyle = h_style, tableStyle = "TableStyleLight9")
        setColWidths(wb, "Padronizacao", cols = 1:3, widths = c(28, 22, 55))
      } else {
        writeData(wb, "Padronizacao", data.frame(Resultado = "Nenhuma inconsistencia encontrada."))
      }
      
      # Aba 6: Tipos inconsistentes
      addWorksheet(wb, "Tipos_Inconsistentes")
      tipos_df <- detectar_tipos_inconsistentes(df)
      if (!is.null(tipos_df) && nrow(tipos_df) > 0) {
        writeDataTable(wb, "Tipos_Inconsistentes", tipos_df, headerStyle = h_style, tableStyle = "TableStyleLight9")
        setColWidths(wb, "Tipos_Inconsistentes", cols = 1:3, widths = c(28, 20, 45))
      } else {
        writeData(wb, "Tipos_Inconsistentes", data.frame(Resultado = "Nenhum tipo inconsistente detectado."))
      }
      
      # Aba 7: Dados limpos
      addWorksheet(wb, "Dados_Limpos")
      df_clean <- df %>%
        janitor::clean_names() %>%
        janitor::remove_empty(which = c("rows", "cols")) %>%
        dplyr::distinct() %>%
        dplyr::mutate(dplyr::across(where(is.character),
                                    ~ stringr::str_trim(stringr::str_to_title(.))))
      writeDataTable(wb, "Dados_Limpos", df_clean, headerStyle = h_style, tableStyle = "TableStyleLight9")
      
      saveWorkbook(wb, file, overwrite = TRUE)
    }
  )
}

# =============================================================
#  INICIAR APP
# =============================================================
shinyApp(ui = ui, server = server)
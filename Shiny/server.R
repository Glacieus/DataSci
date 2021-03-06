library(shiny)
library(tm)
library(wordcloud)
library(memoise)
library(tidyverse)
library(tidytext)
library(shinythemes)
library(readr)
library(igraph)
library(ggraph)
library(ggthemes)
library(shinydashboard)
library(kableExtra)
library(lubridate)


function(input, output, session) {
  
  
  # Define a reactive expression for the document term matrix
  terms <- reactive({
    minyear <- input$yrs[1]
    maxyear <- input$yrs[2]
    req(input$selection)
    req(input$yrs[1])
    req(input$yrs[2])
    input$update
    isolate({
      withProgress({
        setProgress(message = "Processing corpus...")
        getTermMatrix(input$selection, minyear, maxyear)
      })
    })
  })
  
  terms2 <- reactive({
    req(input$selection3)
    req(input$selection4)
    minyear <- input$yrs2[1]
    maxyear <- input$yrs2[2]
    req(input$yrs2[1])
    req(input$yrs2[2])
    input$update
    isolate({
      withProgress({
        setProgress(message = "Processing corpus...")
        get_comp_comm(input$selection3, input$selection4, minyear, maxyear)
      })
    })
  })
  
  
  # Make the wordcloud drawing predictable during a session
  wordcloud_rep <- repeatable(wordcloud)
  wordcloud_comp_rep <- repeatable(comparison.cloud)
  
  color_palette <- colorRampPalette(brewer.pal(15, "Paired"))(25)
  
  output$plot <- renderPlot({
    v <- terms()
    wordcloud_rep(
      names(v),
      v,
      scale = c(6.5, 1.5),
      min.freq = input$freq,
      max.words = input$max,
      colors = color_palette
    )
  }, height = 700)
  
  
  output$plot2 <- renderPlot({
    v2 <- terms2()
    wordcloud_comp_rep(
      v2,
      scale = c(4.5, 1),
      min.freq = input$freq2,
      max.words = input$max2,
      #title.size = 1.5,
      colors = c("#ef8a62", "#67a9cf")
    )
  }, height = 525)
  
  ev <- eventReactive(input$click, {
    req(input$selection5)
    req(input$number)
    # minyear <- input$yrs3[1]
    #  maxyear <- input$yrs3[2]
    #  req(input$yrs3[1])
    #  req(input$yrs3[2])
    input$update2
    isolate({
      withProgress({
        setProgress(message = "Making the plot... wait one second...")
        filtering(input$selection5, input$number)
      })
    })
  })
  
  ev_2 <- eventReactive(input$click, {
    input$update
    graph_from_data_frame(ev())
  })
  
  output$ggraph <- renderPlot(
    ggraph(ev_2(), layout = "fr") +
      geom_edge_link(arrow = a, alpha = .5) +
      geom_node_point() +
      geom_node_text(aes(label = name),
                     vjust = 1,
                     hjust = 1,
                     repel = T) +
      theme_economist() +
      theme(
        legend.position = "none",
        panel.grid = element_blank(),
        axis.title = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank(),
        axis.line.x = element_line(color = "black", size = 0)
      )
  )
  
  
  output$stats <- function() {
    ev() %>% 
      head() %>% 
      kable() %>% 
      kable_styling()
  }
  
  output$sentiment_time <- renderPlotly({
    test <- tidytexts %>% 
      filter(!is.na(sent_score)) %>% 
      group_by(month = floor_date(date, "month"), source) %>% 
      summarize(mean_score = mean(sent_score)) %>% 
      ggplot(., aes(month, mean_score)) +
      geom_line(aes(group = source, color = source), alpha = .5) +
      geom_smooth(aes(group = source, color = source, weight = 2), se = F) +
      theme_minimal() +
      ggtitle("Mean Sentiment Score Over Time") +
      ylab("Sentiment Score") +
      xlab("Time")
    
    ggplotly(test)
  })
  
  output$percentile_time <- renderPlotly({
    p <- full_texts %>% 
      filter(!is.na(score)) %>% 
      group_by(month = floor_date(date, "month"),  source, year = floor_date(date, "year")) %>% 
      summarize(med_score = median(score),
                avg_pct = mean(context.all.pct)
      ) %>% 
      ggplot(., aes(month, avg_pct)) +
      geom_line(aes(color = source), alpha = .5) +
      geom_smooth(aes(color = source, weight = 2), se = F) +
      theme_minimal() +
      ggtitle("Average Percentile Over Time") +
      ylab("Percentile") +
      xlab("Time")
    
    ggplotly(p)
  })
  
  output$altmetric_score <- renderPlotly({
    p2 <- full_texts %>% 
      filter(!is.na(score)) %>% 
      group_by(month = floor_date(date, "month"),  source, year = floor_date(date, "year")) %>% 
      summarize(med_score = median(score),
                total_tweets = sum(cited_by_tweeters_count)) %>% 
      ggplot(., aes(month, med_score)) +
      geom_line(aes(color = source), alpha = .5) + theme_minimal() +
      geom_smooth(aes(color = source), se = F) +
      ggtitle("Median Altmetric Score Over Time") +
      xlab("Time") +
      ylab("Median Score")
    
    ggplotly(p2)
  })
  
  output$tweets <- renderPlotly({
    pt <- full_texts %>% 
      filter(!is.na(score)) %>% 
      group_by(month = floor_date(date, "month"),  source, year = floor_date(date, "year")) %>% 
      summarize(med_score = median(score),
                total_tweets = sum(cited_by_tweeters_count)) %>% 
      ggplot(., aes(month, total_tweets)) +
      geom_line(aes(color = source), alpha = .5) + theme_minimal() +
      geom_smooth(aes(color = source), se = F) +
      ggtitle("Tweets Over Time") +
      xlab("Time") +
      ylab("Tweets")
    
    ggplotly(pt)
  })
  
  
}







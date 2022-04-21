
# Load packages. 
library(shiny)
library(leaflet)
library(RColorBrewer)
library(htmlwidgets)

# Create website with three sub pages. 
# UI = user interface, "scaffolding", positions the app's output and makes it look good. 
jsfile <- "https://rawgit.com/rowanwins/leaflet-easyPrint/gh-pages/dist/bundle.js" 
ui <- bootstrapPage(
  tags$head(tags$script(src = jsfile)),
    # Title of website. 
    navbarPage(
        title = "Map Visualizer", 
        
        # Subpage 1: Mapper. 
        tabPanel(
            title = "Mapper",
            div(class="outer",
                tags$style(type = "text/css", "html, body {width:20%;height:20%}"), # Can adjust dimensions of map here.
                leafletOutput("basic_map"),
                absolutePanel(top = 10, right = 10, # Location of slider. 
                              # Sliding bar for magntiude. 
                              sliderInput("range", "Magnitudes", min(quakes$mag), max(quakes$mag),
                                          value = range(quakes$mag), step = 0.1
                              ),
                              # Dropdown menu for color palettes. 
                              selectInput("colors", "Color Scheme",
                                          rownames(subset(brewer.pal.info, category %in% c("seq", "div")))
                              ),
                              # Show/hide button for legend. 
                              checkboxInput("legend", "Show legend", TRUE),
                              
                              actionButton("saveMap", "Screenshot Map")
                )
            )
            
        ), 
        # Subpage 2: Mapper 2
        tabPanel(
            
            title = "Mapper 2",
            div(class="outer",
                tags$style(type = "text/css", "html, body {width:100%;height:100%}"), # Can adjust dimensions of map here.
                leafletOutput("cluster_map"),
                absolutePanel(top = 10, right = 10, 
                )
            )
            
        ), 
        
        # Subpage 3: About
        tabPanel(
            title = 'About',
            titlePanel('About'),
            'Created with R Shiny',
            br(),
            '2022 April'
        )
    )
)

# Run R code here. (When user interacts with the app). 
# Store reactive values and modify them within observers. 
server <- function(input, output, session) {
    
    # Reactive expression for the data subsetted to what the user selected.
    filteredData <- reactive({
        quakes[quakes$mag >= input$range[1] & quakes$mag <= input$range[2],]
    })
    
    # This reactive expression represents the palette function,
    # which changes as the user makes selections in UI.
    colorpal <- reactive({
        colorNumeric(input$colors, quakes$mag)
    })
    
    # Outputs the map. 
    output$basic_map <- renderLeaflet({
        # Use leaflet() here, and only include aspects of the map that
        # won't need to change dynamically (at least, not unless the
        # entire map is being torn down and recreated).
        leaflet(quakes) %>% 
            addTiles() %>%
            fitBounds(~min(long), ~min(lat), ~max(long), ~max(lat)) %>% 
        onRender(
          "function(el, x) {
            L.easyPrint({
              sizeModes: ['Current', 'A4Landscape', 'A4Portrait'],
              filename: 'mymap',
              exportOnly: true,
              hideControlContainer: true
            }).addTo(this);
            }"
        ) %>% 
            addTiles(group = "Default Map") %>%
            # Various base maps. 
            addProviderTiles(providers$Stamen.Toner, group = "Black/White Map") %>% 
            addProviderTiles(providers$CartoDB.Positron, group = "Greyscale Map") %>%
            addProviderTiles(providers$Esri.NatGeoWorldMap, group = "Nat. Geo. Map") %>% 
            addProviderTiles(providers$Esri.WorldStreetMap, group = "Street Map") %>% 
            # Creates the small map in bottomr right corner, with toggle to collapse it. 
            addMiniMap(
                tiles = providers$Esri.WorldStreetMap,
                toggleDisplay = TRUE) %>% 
            # Panel with different basemaps.  
            addLayersControl(
                baseGroups = c("Default Map", "Black/White Map", 
                               "Greyscale Map", "Nat. Geo. Map", "Street Map"),
                options = layersControlOptions(collapsed = FALSE),
                position = c("topleft")
            )
    })
    
    # Incremental changes to the map (in this case, replacing the
    # circles when a new color is chosen) should be performed in
    # an observer. Each independent set of things that can change
    # should be managed in its own observer.
    observe({
        # Gets the color palettes.
        pal <- colorpal()
        
        # Creates the circles.
        leafletProxy("basic_map", data = filteredData()) %>%
            clearShapes() %>%
            addCircles(radius = ~10^mag/10, weight = 1, color = "#777777",
                       fillColor = ~pal(mag), fillOpacity = 0.7, popup = ~paste(mag),
            )
        
    })
    
    # Use a separate observer to recreate the legend as needed.
    observe({
        proxy <- leafletProxy("basic_map", data = quakes)
        
        # Remove any existing legend, and only if the legend is
        # enabled, create a new one.
        proxy %>% clearControls()
        if (input$legend) {
            pal <- colorpal()
            proxy %>% addLegend(position = "bottomright",
                                pal = pal, values = ~mag
            )
        }
    })
    
    # Custom markers based on earthquake magnitude. 
    earthquakeIcons <- icons(
        iconUrl = ifelse(quakes$mag <= 4.6,
                         "https://th.bing.com/th/id/R.206e4bb3740541e9d4fab93fdd782bc6?rik=oRKo%2fYMuke4NAg&riu=http%3a%2f%2fshelterinplace.com%2fwp-content%2fuploads%2f2018%2f02%2fearthquake-icon.png&ehk=9QlqPRTsObjces2%2fwXYe8ECCb8vow%2bKM0m8Php%2fkfj8%3d&risl=&pid=ImgRaw&r=0",
                         ifelse(4.6 < quakes$mag & quakes$mag <= 5.2,
                                "https://th.bing.com/th/id/R.62ec1891456342f70996cacf6b42a016?rik=DkcuHsgBe7AQLQ&pid=ImgRaw&r=0",
                                ifelse( 5.2 < quakes$mag & quakes$mag <= 5.8,
                                        "https://www.pngarts.com/files/3/Volcano-Transparent-Image.png",
                                        ifelse(5.8 < quakes$mag & quakes$mag <= 6.4,
                                               "https://th.bing.com/th/id/R.5b8a7eb65055f4a08cd964fbab726399?rik=Hqb%2fhR4e2GtJvw&pid=ImgRaw&r=0",
                                               "https://clipartcraft.com/images/quake-logo-earthquake-2.png")
                                )
                                
                         )
                         
        ),
        # Set size and anchor of each marker. 
        iconWidth = 25, iconHeight = 25,
        iconAnchorX = 22, iconAnchorY = 94
    )
    
    # Outputs the map. 
    output$cluster_map <- renderLeaflet({
        leaflet(quakes) %>% 
            addTiles() %>% 
            # Custom marker is created on map here. 
            addMarkers(
                clusterOptions = markerClusterOptions(), 
                icon = ~ earthquakeIcons,
            ) %>% 
            addTiles(group = "Default Map") %>%
            # Basemaps here. 
            addProviderTiles(providers$Stamen.Toner, group = "Black/White Map") %>% 
            addProviderTiles(providers$CartoDB.Positron, group = "Greyscale Map") %>%
            addProviderTiles(providers$Esri.NatGeoWorldMap, group = "Nat. Geo. Map") %>% 
            addProviderTiles(providers$Esri.WorldStreetMap, group = "Street Map") %>% 
            # Creates the small map in bottom right corner, with toggle to collapse it. 
            addMiniMap(
                tiles = providers$Esri.WorldStreetMap,
                toggleDisplay = TRUE) %>% 
            # Panel with basemaps. 
            addLayersControl(
                baseGroups = c("Default Map", "Black/White Map", "Greyscale Map", "Nat. Geo. Map", "Street Map"),
                options = layersControlOptions(collapsed = FALSE),
                position = c("topleft")
    ) %>% 
        # NEED JSFILE LIBRARY.
        onRender(
          "function(el, x) {
            L.easyPrint({
              sizeModes: ['Current', 'A4Landscape', 'A4Portrait'],
              filename: 'mymap',
              exportOnly: true,
              hideControlContainer: true
            }).addTo(this);
            }"
        )
            
        
    })
    
}

# Run the app in the R Shiny server. 
shinyApp(ui = ui, server = server)

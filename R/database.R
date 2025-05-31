#' Connect to a HUD database
#'
#' Handles all the Active Directory authentication and connects to database.
#' @name db_connect
#' @param database Database name (optional)
#' @param server Server name (optional)
#' @param driver Driver string (optional)
#' @export
db_connect <- function(database = "property",
                       server = "property.database.windows.net",
                       driver = "{ODBC Driver 18 for SQL Server}") {

    # Use "device_code" on the cloud because we can't hook up to a browser
    if (grepl("azure", Sys.info()["release"])) {
        auth_type <- "device_code"
    } else {
        auth_type <- NULL
    }

    token <-
        AzureAuth::get_azure_token(
            resource = "https://database.windows.net",
            tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # "hud.govt.nz" tenancy
            app = "04b07795-8ddb-461a-bbee-02f9e1bf7b46", # "Offline Access" app
            auth_type = auth_type)

    message("Connecting to '", database, "' on '", server ,"'...")
    conn <-
        DBI::dbConnect(
            odbc::odbc(),
            Database = database,
            Server = server,
            Driver = driver,
            attributes = list("azure_token" = token$credentials$access_token))
    return(conn)
}

#' Run query
#'
#' Shortcut for running a SQL query
#' @name get_query
#' @param query SQL query
#' @param database Database name (optional)
#' @param server Server name (optional)
#' @param driver Driver string (optional)
#' @export
get_query <- function(query, ...) {
    conn <- db_connect(...)
    out <- DBI::dbGetQuery(conn, query) %>% as_tibble()
    return(out)
}

#' Run spatial query
#'
#' Shortcut for running a SQL query and cleaning spatial data
#' @name get_query
#' @param query SQL query
#' @param geometry_column Specific the column for sf to treat as geometry
#' @param database Database name (optional)
#' @param server Server name (optional)
#' @param driver Driver string (optional)
#' @export
get_spatial_query <- function(query, geometry_column = "geom", ...) {
    conn <- hud.keep::db_connect(...)
    out <-
        sf::st_read(conn, crs = 4167, geometry_column = geometry_column, query = query) %>%
        sf::st_make_valid() %>%
        sf::st_as_sf()
    return(out)
}

#' Write to table in batches
#'
#' For dealing with very large tables that will fail if we try to write all at
#' once.
#' @name batch_write_table
#' @param targ_df Data to write to table
#' @param table_name Table to write to
#' @param database Database name (optional)
#' @param server Server name (optional)
#' @param driver Driver string (optional)
#' @param batch_size Number of rows to load in each batch
#' @export
batch_write_table <- function(targ_df,
                              table_name,
                              database = "property",
                              server = "property.database.windows.net",
                              driver = "{ODBC Driver 18 for SQL Server}",
                              batch_size = 100000) {
    message(stringr::str_glue("Writing {nrow(targ_df)} rows to {table_name}..."))
    conn <- db_connect(database, server, driver)

    # Structure name as Id object
    table_id <-
        table_name %>%
        str_replace_all("[\\[\\]]", "") %>%
        DBI::dbUnquoteIdentifier(conn, .) %>%
        .[[1]]

    # Load data in batches
    for (i in seq(1, nrow(targ_df), batch_size)) {
        j <- min(i - 1 + batch_size, nrow(targ_df)) %>% as.integer()
        message(stringr::str_glue("Writing rows {i} to {j}..."))
        if (i == 1) {
            DBI::dbWriteTable(conn, table_id, targ_df[i:j,], overwrite = TRUE)
        } else {
            DBI::dbWriteTable(conn, table_id, targ_df[i:j,], append = TRUE)
        }
    }

    # Check that the whole table is loaded
    db_count <- DBI::dbGetQuery(conn, stringr::str_glue("SELECT COUNT(*) FROM {table_name}"))
    if (db_count == nrow(targ_df)) {
        message(stringr::str_glue("{db_count} rows written to {table_name}."))
        return(db_count)
    } else {
        stop(stringr::str_glue("{nrow(targ_df)} rows expected, but there are {db_count} rows in {table_name}!"))
    }
}

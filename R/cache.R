make_db_path <- function(path, format_version, extras = NULL) {
  path |>
    c(extras, "classification_cache", format_version, "sqlite") |>
    str_c(collapse = ".")
}

connect <- function(db_path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
}

disconnect <- function(con) {
  DBI::dbDisconnect(con)
}

tidy_cache <- function(x) {
  x |>
    dplyr::arrange(sequence) |>
    dplyr::distinct(sequence, .keep_all = TRUE)
}

get_cache <- function(db_path, sequences) {
  con <- connect(db_path)

  if (DBI::dbExistsTable(con, "cache")) {
    results <-
      dplyr::tbl(con, "cache") |>
      dplyr::collect() |>
      dplyr::filter(sequence %in% sequences) |>
      tidy_cache()
  } else {
    results <- tibble(sequence = character())
  }

  disconnect(con)

  results
}

update_cache <- function(db_path, cached, fresh) {
  con <- connect(db_path)

  if (DBI::dbExistsTable(con, "cache")) {
    DBI::dbAppendTable(con, "cache", fresh)
    cli::cli_alert("cache appended ({.val {nrow(cached)}}+{.val {nrow(fresh)}} row{?s} from/to {.path {db_path}})")
  } else {
    DBI::dbWriteTable(con, "cache", fresh)
    cli::cli_alert("cache created ({.val {nrow(fresh)}} row{?s} added to {.path {db_path}})")
  }

  disconnect(con)

  cached |>
    dplyr::bind_rows(fresh) |>
    tidy_cache()
}

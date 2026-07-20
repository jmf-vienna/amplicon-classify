as_tibble <- function(x) {
  x |>
    as.data.frame() |>
    rownames_to_column("sequence") |>
    tibble::as_tibble()
}

full_path <- function(x) {
  fs::path(
    Sys.getenv("PATH_RESOURCES", "resources"),
    chuck(x, "path")
  )
}

dada2_classify <- function(
  sequences,
  reference,
  bootstrap_threshold = 50L,
  chunk_size = as.integer(Sys.getenv("CHUNK_SIZE", "1000"))
) {
  if (is.null(reference)) {
    return()
  }

  reference_path <- full_path(reference)
  db_path <- make_db_path(reference_path, 1L, str_c("bootstrap_", bootstrap_threshold))

  cached <- get_cache(db_path, sequences)
  missing_sequences <- setdiff(sequences, pull(cached, sequence))

  if (vec_is_empty(missing_sequences)) {
    cli::cli_alert("cache was up-to-date ({.val {nrow(cached)}} row{?s} read from {.path {db_path}})")
    return(cached)
  }

  ranks <- pluck(reference, "ranks", .default = c("Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species"))

  while (!vec_is_empty(missing_sequences)) {
    fresh <-
      dada2::assignTaxonomy(
        head(missing_sequences, chunk_size),
        reference_path,
        bootstrap_threshold,
        outputBootstraps = TRUE,
        taxLevels = ranks,
        multithread = Sys.getenv("THREADS", "1") |> as.integer()
      )

    fresh <- fresh |> map(as_tibble)

    fresh <- inner_join(
      fresh |> chuck("tax"),
      fresh |> chuck("boot") |> dplyr::rename_with(\(x) str_c("bootstrap_", x)),
      by = join_by(sequence == bootstrap_sequence)
    ) |>
      select(
        sequence,
        all_of(str_c(
          rep(c("", "bootstrap_"), length(ranks)),
          rep(ranks, each = 2L)
        ))
      )

    cached <- update_cache(db_path, cached, fresh)
    missing_sequences <- tail(missing_sequences, -chunk_size)
  }

  cached
}

dada2_classify_species <- function(
  sequences,
  reference,
  allow_multiple = TRUE,
  chunk_size = as.integer(Sys.getenv("CHUNK_SIZE", "10000"))
) {
  if (is.null(reference)) {
    return()
  }

  reference_path <- full_path(reference)
  db_path <- make_db_path(reference_path, 1L, ifelse(allow_multiple, "allow_multiple", "disallow_multiple"))

  cached <- get_cache(db_path, sequences)
  missing_sequences <- setdiff(sequences, pull(cached, sequence))

  if (vec_is_empty(missing_sequences)) {
    cli::cli_alert("cache was up-to-date ({.val {nrow(cached)}} row{?s} read from {.path {db_path}})")
    return(cached)
  }

  while (!vec_is_empty(missing_sequences)) {
    fresh <-
      dada2::assignSpecies(
        head(missing_sequences, chunk_size),
        reference_path,
        allowMultiple = allow_multiple
      ) |>
      as_tibble()

    cached <- update_cache(db_path, cached, fresh)
    missing_sequences <- tail(missing_sequences, -chunk_size)
  }

  cached
}

tidy_classification <- function(classification, classification_species, features) {
  if (is.null(classification)) {
    return()
  }

  species <-
    if (is.null(classification_species)) {
      features |> select(sequence)
    } else {
      classification_species |>
        mutate(Species_exact_match = str_c(Genus, " ", Species), .keep = "unused")
    }

  classification |>
    left_join(species, by = "sequence") |>
    left_join(features, by = "sequence") |>
    select(2L:ends_with("ID")) |>
    arrange(across(last_col()))
}

classification_output_name <- function(input_name, reference) {
  if (is.null(reference)) {
    return()
  }

  glue::glue(
    "{base_name}.{name}_reference.DADA2_classified",
    base_name = input_name |> path_file() |> path_ext_remove(),
    name = reference |> chuck("id")
  )
}

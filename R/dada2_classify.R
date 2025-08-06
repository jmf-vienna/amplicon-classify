as_tibble <- function(x) {
  x |>
    as.data.frame() |>
    rownames_to_column("sequence") |>
    tibble::as_tibble()
}

dada2_classify <- function(
    sequences,
    reference,
    bootstrap_threshold = 50L,
    ranks = c("Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species")) {
  db_path <- make_db_path(reference, 1L, str_c("bootstrap_", bootstrap_threshold))

  cached <- get_cache(db_path, sequences)
  missing_sequences <- setdiff(sequences, pull(cached, sequence))

  if (vec_is_empty(missing_sequences)) {
    cli::cli_alert("cache was up-to-date ({.val {nrow(cached)}} row{?s} read from {.path {db_path}})")
    return(cached)
  }

  fresh <- dada2::assignTaxonomy(
    missing_sequences,
    reference,
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
    select(sequence, all_of(str_c(
      rep(c("", "bootstrap_"), length(ranks)),
      rep(ranks, each = 2L)
    )))

  update_cache(db_path, cached, fresh)
}

dada2_classify_species <- function(sequences, reference, allow_multiple = TRUE) {
  db_path <- make_db_path(reference, 1L, ifelse(allow_multiple, "allow_multiple", "disallow_multiple"))

  cached <- get_cache(db_path, sequences)
  missing_sequences <- setdiff(sequences, pull(cached, sequence))

  if (vec_is_empty(missing_sequences)) {
    cli::cli_alert("cache was up-to-date ({.val {nrow(cached)}} row{?s} read from {.path {db_path}})")
    return(cached)
  }

  fresh <-
    dada2::assignSpecies(
      missing_sequences,
      reference,
      allowMultiple = allow_multiple
    ) |>
    as_tibble()

  update_cache(db_path, cached, fresh)
}

tidy_classification <- function(classification, classification_species, features) {
  species <-
    classification_species |>
    mutate(Species_exact_match = str_c(Genus, " ", Species), .keep = "unused")

  classification |>
    left_join(species, by = "sequence") |>
    left_join(features, by = "sequence") |>
    select(2L:ends_with("ID")) |>
    arrange(across(last_col()))
}

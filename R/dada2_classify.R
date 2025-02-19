dada2_classify <- function(sequences, reference) {
  dada2::assignTaxonomy(
    sequences,
    reference,
    multithread = Sys.getenv("THREADS", "1") |> as.integer()
  )
}

dada2_classify_species <- function(sequences, reference) {
  dada2::assignSpecies(
    sequences,
    reference,
    allowMultiple = TRUE
  )
}

tidy_classification <- function(classification, classification_species, features) {
  species <-
    classification_species |>
    as.data.frame() |>
    rownames_to_column("Sequence") |>
    as_tibble() |>
    mutate(exact_match = str_c(Genus, " ", Species), .keep = "unused")

  classification |>
    as.data.frame() |>
    rownames_to_column("Sequence") |>
    as_tibble() |>
    left_join(species, by = "Sequence") |>
    left_join(features, by = "Sequence") |>
    select(2L:ends_with("ID"))
}

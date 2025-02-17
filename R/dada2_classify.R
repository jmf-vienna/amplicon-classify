dada2_classify <- function(sequences, reference) {
  dada2::assignTaxonomy(
    sequences,
    reference
  )
}

tidy_classification <- function(classification, features) {
  classification |>
    as.data.frame() |>
    rownames_to_column("Sequence") |>
    as_tibble() |>
    left_join(features, by = "Sequence") |>
    select(2L:ends_with("ID"))
}

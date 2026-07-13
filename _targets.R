library(targets)

jmf::quiet()
options(warn = 2L)
tar_option_set(
  packages = c("cli", "dplyr", "fs", "purrr", "readr", "rlang", "stringr", "tibble", "tidyr", "vctrs"),
  format = "qs",
  iteration = "list"
)

tar_config_get("script") |>
  fs::path_dir() |>
  fs::path("R") |>
  tar_source()

if (fs::dir_exists("R")) {
  tar_source()
}

if (fs::file_exists("customize.R")) {
  tar_source("customize.R")
}

list(
  # config ----
  tar_target(config_file, Sys.getenv("R_CONFIG_FILE", "config.yaml"), format = "file"),
  tar_target(config, config::get(config = Sys.getenv("DATASET", Sys.getenv("TAR_PROJECT", "default")), file = config_file)),

  # paths ----
  tar_target(input_path, config |> pluck("path", "data", .default = "data")),
  tar_target(output_path, config |> pluck("path", "data", .default = "data")),
  tar_target(references, config |> pluck("taxonomy", "references", .default = list(NULL))),

  # features ----
  tar_target(features_file, find_features_info_file(input_path), format = "file"),
  tar_target(features, features_file |> read_tsv() |> tidy_features_info()),

  ## classify ----
  tar_target(
    classification_raw,
    features |> pull(sequence) |> dada2_classify(pluck(references, "base")),
    pattern = map(references)
  ),
  tar_target(
    classification_species_raw,
    features |> pull(sequence) |> dada2_classify_species(pluck(references, "perfect")),
    pattern = map(references)
  ),
  tar_target(
    classification,
    tidy_classification(classification_raw, classification_species_raw, features),
    pattern = map(classification_raw, classification_species_raw)
  ),

  # export ----
  tar_target(
    classification_file_name,
    glue::glue(
      "{base_name}.{reference}_reference.DADA2_classified",
      base_name = features_file |> path_file() |> path_ext_remove(),
      reference = references |> chuck("id")
    ),
    pattern = map(references)
  ),
  tar_target(
    classification_file,
    write_tsv(classification, path(output_path, classification_file_name, ext = "tsv")),
    format = "file",
    pattern = map(classification, classification_file_name)
  )
)

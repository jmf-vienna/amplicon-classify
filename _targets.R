library(targets)

jmf::quiet()
options(warn = 2L)
tar_option_set(
  packages = c("cli", "dplyr", "fs", "purrr", "readr", "rlang", "stringr", "tibble", "tidyr", "vctrs"),
  format = "qs"
)

tar_config_get("script") |>
  fs::path_dir() |>
  fs::path("R") |>
  tar_source()

list(
  # config ----
  tar_target(config_file, Sys.getenv("R_CONFIG_FILE", "config.yaml"), format = "file"),
  tar_target(config, config::get(config = Sys.getenv("TAR_PROJECT", "default"), file = config_file)),

  # paths ----
  tar_target(input_path, config |> pluck("path", "data", .default = "data")),
  tar_target(reference_file, config |> chuck("path", "taxonomy reference"), format = "file"),
  tar_target(species_reference_file, config |> pluck("path", "species reference"), format = "file"),
  tar_target(output_path, config |> pluck("path", "data", .default = "data")),

  # features ----
  tar_target(features_file, find_one_file(input_path, regexp = "(features|ASVs|OTUs)[.]tsv$"), format = "file"),
  tar_target(features, read_tsv(features_file)),

  ## classify ----
  tar_target(classification_raw, features |> pull(Sequence) |> dada2_classify(reference_file)),
  tar_target(classification_species_raw, features |> pull(Sequence) |> dada2_classify_species(species_reference_file)),
  tar_target(classification, tidy_classification(classification_raw, classification_species_raw, features)),

  # export ----
  tar_target(classification_file_name, glue::glue(
    "{base_name}.{reference}_reference.DADA2_classified",
    base_name = features_file |> path_file() |> path_ext_remove(),
    reference = reference_file |> path_file() |> str_extract("^[A-Za-z]+") |> str_to_upper()
  )),
  tar_target(classification_file, classification |> write_tsv(path(output_path, classification_file_name, ext = "tsv")), format = "file")
)

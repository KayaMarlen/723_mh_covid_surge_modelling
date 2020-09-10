#' Run Model
#'
#' Performs the Systems Dynamics modelling on the given parameter values.
#'
#' @param params the value returned from \code{get_model_params()} from the current `params`
#' @param new_potential the value returned from \code{get_model_potential_functions()} from the current `params`
#' @param simtime the points at which we should try to solve the function at. Defaults to 0 to 18 (months), solving at
#'   intervals of 1 / 30 (e.g. each day in the month)
#'
#' @return a tibble of the results of running the model
#'
#' @importFrom purrr set_names map_chr map_dbl map
#' @importFrom deSolve ode
#' @importFrom dplyr %>% rename_with all_of tibble as_tibble
#' @importFrom tidyr pivot_longer separate
run_model <- function(params, new_potential, simtime = seq(0, 18, by = 1 / 30)) {
  # ensure params are ordered
  params <- params[, sort(colnames(params))]

  # get the names of the treatments from the params matrix column names
  treatments <- colnames(params)

  # get the names of the initial groups from the start of the treatment names
  all_initials <- treatments %>%
    strsplit("\\|") %>%
    map_chr(1)
  initials <- unique(all_initials)

  # reorders the new_potential object to be same order as the initials
  new_potential <- new_potential[initials]

  # set up the stocks for the no mh needs group, each of the initial groups, and each of the stocks
  stocks <- c("no-mh-needs", initials, treatments) %>%
    set_names() %>%
    map_dbl(~0)

  # create a matrix that can take the initial group stocks and create a matrix that matches the treatment stocks.
  # each initial group is a column in the matrix
  initial_treatment_map <- all_initials %>%
    map(~as.numeric(.x == initials)) %>%
    flatten_dbl() %>%
    matrix(ncol = length(initials), byrow = TRUE)

  # verify that there is a new_potential function for each of the initial groups
  stopifnot("new_potential length does not match initials length" =
              length(new_potential) == length(initials))

  stopifnot("new_potential does not match initials" =
              all(names(new_potential) == initials))

  model <- function(time, stocks, params) {
    # get each of the new potentials for each of the initial groups
    f_new_potential <- map_dbl(new_potential, ~.x(time))

    # expand the initials stocks for each of the treatments
    initials_matrix <- initial_treatment_map %*% matrix(stocks[initials], ncol = 1)


    # flow from initial groups to treatments
    f_referrals <- initials_matrix[, 1] * params["pcnt", ]
    f_pot_treat <- f_referrals * params["treat", ]
    # flow from initial groups to no needs
    f_no_needs  <- stocks[initials] * (1 - matrix(params["pcnt", ], nrow = 1) %*% initial_treatment_map)[1, ]

    # flow from treatment groups back to initials
    f_treat_pot      <- stocks[treatments] * (1 - params["success", ]) * exp(params["decay", ])
    # flow from treatment groups to no further mh needs
    f_treat_no_needs <- stocks[treatments] * (0 + params["success", ]) * exp(params["decay", ])

    # convert the flows from treatment groups to be based on initial stocks, not treatment stocks
    f_pot_treat_initials <- (matrix(f_pot_treat, nrow = 1) %*% initial_treatment_map)[1, ]
    f_treat_pot_initials <- (matrix(f_treat_pot, nrow = 1) %*% initial_treatment_map)[1, ]

    # add the flow of new-at-risk to the output
    names(f_new_potential) <- paste0("new-at-risk|", names(f_new_potential))
    # add the flow of new-referral to the output
    names(f_referrals) <- paste0("new-referral|", names(f_referrals))
    # add the flow of new-treatments to the output
    names(f_pot_treat) <- paste0("new-treatment|", names(f_pot_treat))

    # calculate the changes to each of the stocks
    c(list(c(sum(f_no_needs) + sum(f_treat_no_needs),
             f_new_potential + f_treat_pot_initials - f_pot_treat_initials - f_no_needs,
             f_pot_treat - f_treat_pot - f_treat_no_needs)),
      f_new_potential,
      f_referrals,
      f_pot_treat)
  }

  # run the model and return the results in a long tidy format
  ode(stocks, simtime, model, params, "euler") %>%
    as.data.frame() %>%
    as_tibble() %>%
    rename_with(~paste0("at-risk|", .x), .cols = all_of(initials)) %>%
    rename_with(~paste0("treatment|", .x), .cols = all_of(treatments)) %>%
    pivot_longer(-.data$time) %>%
    separate(.data$name, c("type", "group", "condition", "treatment"), "\\|", fill = "right")
}
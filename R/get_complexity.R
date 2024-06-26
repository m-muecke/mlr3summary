## inspired by mlr3:::score_measures and mlr3:::score_single_measure
get_complexity = function(obj, complexity_measures) {

  tab = get_private(obj)$.data$as_data_table(
    view = NULL, reassemble_learners = TRUE, convert_predictions = FALSE
  )
  tmp = unique(tab, by = c("task_hash", "learner_hash"))[,
    c("task", "learner"), with = FALSE]

  # step through complexity measures
  comps_list = map(complexity_measures, function(comp_msr) {
    # step through resample folds

    comps = future_mapply(function(task,
      learner, resampling, iteration, prediction, ...) {
      get_single_complexity(comp_msr, task, learner, train_set = resampling$train_set(iteration),
        prediction)
    },  tab$task, tab$learner, tab$resampling, tab$iteration, tab$prediction,
      future.seed = NULL)

    comps
  })
  set_names(comps_list, complexity_measures)
}

get_single_complexity = function(complexity_measure, task, learner, train_set, prediction) {
  test_ids = prediction$test$row_ids
  test_tsk = task$clone()$filter(test_ids)
  learner$state$train_task = task
  em = switch(complexity_measure,
    sparsity = get_sparsity_or_interaction_strength(learner, test_tsk, method = "sparsity"),
    interaction_strength = get_sparsity_or_interaction_strength(learner, test_tsk, method = "interaction_strength")
  )
}

get_sparsity_or_interaction_strength = function(learner, test_tsk, method) {
  if (!requireNamespace("iml", quietly = TRUE)) {
    stopf("Package 'iml' needed for this function to work. Please install it.")
  }
  class = if (learner$state$train_task$task_type == "classif" && learner$state$train_task$properties == "twoclass") {
    learner$state$train_task$positive
  }
  pred = iml::Predictor$new(model = learner, data = test_tsk$data(),
    y = test_tsk$target_names, class = class)

  gride_size = switch(method, sparsity = 20L, interaction_strength = 100L)
  ales = iml::FeatureEffects$new(pred, method = "ale", grid.size = gride_size)
  if (method == "sparsity") {
    get_sparsity(ales)
  } else if (method == "interaction_strength") {
    compute_interaction_strength(pred, ales)
  }
}

get_sparsity = function(effects) {
  id_used = map_lgl(effects$results, function(ef) {
    if (var(ef$.value) != 0) {
      return(TRUE)
    } else {
      return(FALSE)
    }
  })
  sum(id_used)
}

compute_interaction_strength = function(predictor, effects) {

  # compute ALE
  dt = predictor$data$get.x()
  pred = predictor$predict(dt)
  if (ncol(pred) > 1L) {
    stopf("Complexity measure 'interaction_strength' does not work for multiClass")
  } else {
    pred = pred[[1L]]
  }
  mean_pred = mean(pred)
  res = map_dtc(effects$effects, function(eff) {
    if (eff$feature.type == "categorical") {
      merge(dt[,eff$feature.name,with = FALSE], eff$results, by = eff$feature.name)$.value
    } else {
      eff$predict(data.frame(dt))
    }
  })
  ale_predictions = rowSums(res) + mean_pred
  ssq_bb = ssq(pred - mean_pred)

  if (!ssq_bb) {
    is = 0
  } else {
    ssq_1st_order_e = ssq(ale_predictions - pred)
    is = ssq_1st_order_e / ssq_bb
  }
}

ssq = function(x) {
  assert_numeric(x, any.missing = FALSE, min.len = 1L)
  sum(x^2)
}

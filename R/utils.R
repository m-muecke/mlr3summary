

get_default_measures = function(task_type, properties = NULL, predict_type = NULL) {
  keys = if (task_type == "classif") {
    if (predict_type == "response") {
      if (properties == "twoclass") {
        mlr_measures$mget(c("classif.acc", "classif.bacc", "classif.fbeta", "classif.mcc"))
      } else if (properties == "multiclass") {
        mlr_measures$mget(c("classif.acc", "classif.bacc"))
      }
    } else if (predict_type == "prob") {
      if (properties == "twoclass") {
        mlr_measures$mget(c("classif.auc", "classif.fbeta", "classif.bbrier", "classif.mcc"))
      } else if (properties == "multiclass") {
        mlr_measures$mget(c("classif.mauc_aunp", "classif.mbrier"))
      }

    }
  } else if (task_type == "regr") {
    mlr_measures$mget(c("regr.rmse", "regr.rsq", "regr.mae", "regr.medae"))
  } else {
    NA_character_
  }
}


get_default_fairness_measures = function(task_type, properties = NULL, predict_type = NULL) {
  keys = if (task_type == "classif" && properties == "twoclass") {
    list(
      msr("fairness.cv", id = "fairness.dp"),
      msr("fairness.pp", id = "fairness.cuae"),
      msr("fairness.eod", id = "fairness.eod")
    )
  } else if (task_type == "regr") {
    list(
      msr("fairness", operation = groupdiff_absdiff, base_measure = msr("regr.rmse")),
      msr("fairness", operation = groupdiff_absdiff, base_measure = msr("regr.mae"))
    )
  } else if (task_type == "classif" && properties == "multiclass") {
    list(msr("fairness", operation = groupdiff_absdiff, base_measure = msr("classif.acc")))
  } else {
    NA_character_
  }
}

get_default_importances = function(task_type, ...) {
  imp = "pdp"
  keys = if (task_type == "classif") {
    c(imp, "pfi.ce")
  } else if (task_type == "regr") {
    c(imp, "pfi.mse")
  } else {
    NULL
  }
}


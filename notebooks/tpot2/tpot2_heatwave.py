import os
from pathlib import Path

import joblib
import pandas as pd

from tpot2 import TPOTClassifier

from sklearn.model_selection import StratifiedGroupKFold
from sklearn.metrics import (
    balanced_accuracy_score,
    matthews_corrcoef,
    classification_report,
    confusion_matrix
)


def main():
    # ---------------------------------------------------------------------
    # Paths
    # ---------------------------------------------------------------------

    input_tsv = Path("data/ml_tpot2_subject_daily_only_physiological.tsv")

    output_dir = Path("outputs/results")
    checkpoint_folder = Path("outputs/checkpoints/tpot2_heatwave")

    output_pipeline = output_dir / "tpot2_heatwave_fitted_pipeline.joblib"
    output_predictions = output_dir / "tpot2_heatwave_predictions.tsv"
    output_confusion_matrix = output_dir / "tpot2_heatwave_confusion_matrix.tsv"
    output_metrics = output_dir / "tpot2_heatwave_metrics.tsv"
    output_classification_report = output_dir / "tpot2_heatwave_classification_report.tsv"

    output_dir.mkdir(parents=True, exist_ok=True)
    checkpoint_folder.mkdir(parents=True, exist_ok=True)

    # ---------------------------------------------------------------------
    # Settings
    # ---------------------------------------------------------------------

    random_state = 42
    n_jobs = int(os.environ.get("SLURM_CPUS_PER_TASK", 1))

    print("Using n_jobs:", n_jobs, flush=True)

    # ---------------------------------------------------------------------
    # Read data
    # ---------------------------------------------------------------------

    df = pd.read_csv(input_tsv, sep="\t")

    print("Input shape:", df.shape, flush=True)
    print("Columns:", list(df.columns), flush=True)

    # ---------------------------------------------------------------------
    # Target and groups
    # ---------------------------------------------------------------------

    y = df["heatwave"].astype(int)
    groups = df["userId"]

    print("\nTarget distribution:", flush=True)
    print(y.value_counts(), flush=True)

    print("\nNumber of subjects:", flush=True)
    print(df["userId"].nunique(), flush=True)

    # ---------------------------------------------------------------------
    # Predictors
    # ---------------------------------------------------------------------

    X = df.drop(columns=["heatwave", "userId"])

    print("\nPredictor shape:", X.shape, flush=True)
    print("Predictors:", list(X.columns), flush=True)

    # ---------------------------------------------------------------------
    # Train/test split grouped by subject
    # ---------------------------------------------------------------------

    sgkf = StratifiedGroupKFold(
        n_splits=5,
        shuffle=True,
        random_state=random_state
    )

    train_idx, test_idx = next(sgkf.split(X, y, groups=groups))

    X_train = X.iloc[train_idx]
    X_test = X.iloc[test_idx]

    y_train = y.iloc[train_idx]
    y_test = y.iloc[test_idx]

    print("\nTrain samples:", X_train.shape[0], flush=True)
    print("Test samples:", X_test.shape[0], flush=True)

    print("\nTrain subjects:", df.iloc[train_idx]["userId"].nunique(), flush=True)
    print("Test subjects:", df.iloc[test_idx]["userId"].nunique(), flush=True)

    print("\nTrain label distribution:", flush=True)
    print(y_train.value_counts(), flush=True)

    print("\nTest label distribution:", flush=True)
    print(y_test.value_counts(), flush=True)

    # ---------------------------------------------------------------------
    # TPOT2 model
    # ---------------------------------------------------------------------

    model = TPOTClassifier(
        search_space="linear-light",
        scorers=["balanced_accuracy", "matthews_corrcoef"],
        scorers_weights=[1, 1],
        cv=5,
        preprocessing=True,
        max_time_mins=60,
        max_eval_time_mins=10,
        n_jobs=n_jobs,
        random_state=random_state,
        verbose=2,
        warm_start=True,
        periodic_checkpoint_folder=str(checkpoint_folder)
    )

    # ---------------------------------------------------------------------
    # Fit
    # ---------------------------------------------------------------------

    model.fit(X_train, y_train)

    # ---------------------------------------------------------------------
    # Evaluation
    # ---------------------------------------------------------------------

    y_pred = model.predict(X_test)

    balanced_accuracy = balanced_accuracy_score(y_test, y_pred)
    mcc = matthews_corrcoef(y_test, y_pred)

    print("\nBalanced accuracy:", balanced_accuracy, flush=True)
    print("Matthews correlation coefficient:", mcc, flush=True)

    report_text = classification_report(y_test, y_pred)

    print("\nClassification report:", flush=True)
    print(report_text, flush=True)

    # ---------------------------------------------------------------------
    # Save fitted pipeline
    # ---------------------------------------------------------------------

    try:
        joblib.dump(model.fitted_pipeline_, output_pipeline)
        print("\nSaved fitted pipeline:", output_pipeline, flush=True)
    except Exception as error:
        print("\nCould not save fitted pipeline:", error, flush=True)

    # ---------------------------------------------------------------------
    # Save predictions
    # ---------------------------------------------------------------------

    predictions = df.iloc[test_idx].copy()
    predictions["predicted_heatwave"] = y_pred

    try:
        predictions["probability_heatwave"] = model.predict_proba(X_test)[:, 1]
    except Exception as error:
        print("Could not save predicted probabilities:", error, flush=True)

    predictions.to_csv(output_predictions, sep="\t", index=False)

    # ---------------------------------------------------------------------
    # Save confusion matrix
    # ---------------------------------------------------------------------

    conf_mat = pd.DataFrame(
        confusion_matrix(y_test, y_pred),
        index=["true_0", "true_1"],
        columns=["pred_0", "pred_1"]
    )

    conf_mat.to_csv(output_confusion_matrix, sep="\t")

    # ---------------------------------------------------------------------
    # Save metrics
    # ---------------------------------------------------------------------

    metrics = pd.DataFrame(
        {
            "metric": [
                "balanced_accuracy",
                "matthews_correlation_coefficient",
                "n_train_samples",
                "n_test_samples",
                "n_train_subjects",
                "n_test_subjects"
            ],
            "value": [
                balanced_accuracy,
                mcc,
                X_train.shape[0],
                X_test.shape[0],
                df.iloc[train_idx]["userId"].nunique(),
                df.iloc[test_idx]["userId"].nunique()
            ]
        }
    )

    metrics.to_csv(output_metrics, sep="\t", index=False)

    # ---------------------------------------------------------------------
    # Save classification report
    # ---------------------------------------------------------------------

    report = classification_report(y_test, y_pred, output_dict=True)
    report_df = pd.DataFrame(report).transpose()
    report_df.to_csv(output_classification_report, sep="\t")

    print("\nSaved predictions:", output_predictions, flush=True)
    print("Saved confusion matrix:", output_confusion_matrix, flush=True)
    print("Saved metrics:", output_metrics, flush=True)
    print("Saved classification report:", output_classification_report, flush=True)


if __name__ == "__main__":
    main()

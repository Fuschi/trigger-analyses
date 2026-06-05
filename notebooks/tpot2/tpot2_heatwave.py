import os

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

# ---------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------

input_tsv = "data/ml_tpot2_subject_daily_only_physiological.tsv"

output_model = "outputs/results/tpot2_heatwave_model.joblib"
output_predictions = "outputs/results/tpot2_heatwave_predictions.tsv"
output_confusion_matrix = "outputs/results/tpot2_heatwave_confusion_matrix.tsv"

checkpoint_folder = "outputs/checkpoints/tpot2_heatwave"

# ---------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------

random_state = 42
n_jobs = int(os.environ.get("SLURM_CPUS_PER_TASK", 1))

print("Using n_jobs:", n_jobs)

# ---------------------------------------------------------------------
# Read data
# ---------------------------------------------------------------------

df = pd.read_csv(input_tsv, sep="\t")

print("Input shape:", df.shape)
print("Columns:", list(df.columns))

# ---------------------------------------------------------------------
# Target and groups
# ---------------------------------------------------------------------

y = df["heatwave"].astype(int)
groups = df["userId"]

print("\nTarget distribution:")
print(y.value_counts())

print("\nNumber of subjects:")
print(df["userId"].nunique())

# ---------------------------------------------------------------------
# Predictors
# ---------------------------------------------------------------------

X = df.drop(columns=["heatwave", "userId"])

print("\nPredictor shape:", X.shape)
print("Predictors:", list(X.columns))

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

print("\nTrain samples:", X_train.shape[0])
print("Test samples:", X_test.shape[0])

print("\nTrain subjects:", df.iloc[train_idx]["userId"].nunique())
print("Test subjects:", df.iloc[test_idx]["userId"].nunique())

print("\nTrain label distribution:")
print(y_train.value_counts())

print("\nTest label distribution:")
print(y_test.value_counts())

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
    periodic_checkpoint_folder=checkpoint_folder
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

print("\nBalanced accuracy:", balanced_accuracy)
print("Matthews correlation coefficient:", mcc)

print("\nClassification report:")
print(classification_report(y_test, y_pred))

# ---------------------------------------------------------------------
# Save outputs
# ---------------------------------------------------------------------

joblib.dump(model, output_model)

predictions = df.iloc[test_idx].copy()
predictions["predicted_heatwave"] = y_pred

try:
    predictions["probability_heatwave"] = model.predict_proba(X_test)[:, 1]
except Exception as error:
    print("Could not save predicted probabilities:", error)

predictions.to_csv(output_predictions, sep="\t", index=False)

conf_mat = pd.DataFrame(
    confusion_matrix(y_test, y_pred),
    index=["true_0", "true_1"],
    columns=["pred_0", "pred_1"]
)

conf_mat.to_csv(output_confusion_matrix, sep="\t")

print("\nSaved model:", output_model)
print("Saved predictions:", output_predictions)
print("Saved confusion matrix:", output_confusion_matrix)
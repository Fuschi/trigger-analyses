# Future-dated observations

Initial inspection on 2026-10-19 identified **40,823 participant-minute rows** dated after that day in UTC, including records dated 2026-12-31. This count refers to the combined wide tidy table and the local snapshot inspected.

[The diagnostic notebook](../analyses/future_observations.qmd):

- Flags records where the UTC measurement date is later than the execution date.
- Summarises non-missing observations, participants, date ranges and value ranges by variable.
- Exports all flagged rows and columns to `data/future_observations.csv.gz`, retaining missing values.

The cause of these timestamps has not been established. The diagnostic preserves the observations for investigation and does not remove or correct source data. Counts depend on the data snapshot and execution date.

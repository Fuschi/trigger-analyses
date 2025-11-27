# trigger-analyses

Analysis workflows for Trigger data using **Python** and **R (Quarto)**.  
This project integrates Trigger’s Python client through a lightweight **virtualenv**  
and uses `reticulate` to access Python directly inside Quarto notebooks.  
It also supports direct access to Trigger’s **MariaDB/MySQL** database using **R + SSH**.

---

## 📦 Python Environment (virtualenv + Trigger from Git)

This project uses a Python **virtualenv** to ensure compatibility with RStudio and reticulate.

### Create and configure the environment

```bash
# Create a virtualenv using system Python
python3 -m venv ~/.venv/pytrigger
source ~/.venv/pytrigger/bin/activate

# Clone the Trigger client
git clone git@github.com:Nico-Curti/pytrigger.git
cd pytrigger

# Install Trigger and dependencies
python -m pip install -r requirements.txt
python -m pip install .
pip install pandas requests

# Quick tests
python -c "import ssl; print(ssl.OPENSSL_VERSION)"
python -c "from trigger import TriggerDB; print(TriggerDB)"

deactivate
```

---

## 📘 Using Python inside Quarto

Set the Python interpreter in the **first R chunk** of your `.qmd` file:

```r
library(reticulate)
use_python("~/.venv/pytrigger/bin/python", required = TRUE)
py_config()
```

Then execute Python code as usual:

```python
from trigger import TriggerDB

with TriggerDB() as db:
    print("Connection OK:", db)
```

---

## 🐬 Using MariaDB/MySQL from R via SSH

The connection to the **MariaDB Trigger** server on **bio4** is established through an SSH tunnel.  
I prefer this approach over Unix socket authentication because it allows me to work locally in RStudio while accessing the remote database with MySQL queries, speeding up data aggregation.

---

### Using MariaDB inside a Quarto notebook

```r
# Connect to MariaDB/MySQL
source("R/trigger_utils.R")
con <- connect_trigger_db()
on.exit(DBI::dbDisconnect(con), add = TRUE)

# Minimal example query
query <- "SELECT * FROM myair LIMIT 10;"
df <- DBI::dbGetQuery(con, query)
df

---

## 📁 Project Structure

```
trigger-analyses/
├─ notebooks/           # Quarto notebooks (R + Python)
├─ R/                   # R helper functions (MariaDB utilities)
├─ python/              # Standalone Python scripts
└─ docs/                # Rendered reports
```

---

## ✔️ Notes

- Python workflows use Trigger’s API client (`pytrigger`).
- R workflows connect directly to the **triggerIO MariaDB/MySQL** database.
- SSH tunneling is required for R database access.
- Both Python and R are supported in the same Quarto notebooks.

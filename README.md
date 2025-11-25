# trigger-analyses

Analysis workflows for Trigger data using **Python** and **R (Quarto)**.  
This project integrates Trigger’s Python client through a lightweight **virtualenv**  
and uses `reticulate` to access Python directly inside Quarto notebooks.

---

## 📦 Python Environment (virtualenv + Trigger from Git)

This project uses a Python **virtualenv** to ensure compatibility with RStudio and reticulate.

### Create and configure the environment

```bash
# Create a virtualenv using system Python
python3 -m venv ~/.venv/pytrigger
source ~/.venv/pytrigger/bin/activate

# Clone the Trigger client (replace with your organization if needed)
git clone git@github.com:Nico-Curti/pytrigger.git
cd trigger

# Install Trigger and additional dependencies
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

Then you can execute Python code:

```python
from trigger import TriggerDB

with TriggerDB() as db:
    print("Connection OK:", db)
```

---

## 📁 Project Structure

```
trigger-analyses/
├─ notebooks/           # Quarto notebooks (R + Python)
├─ R/                   # R helper functions
├─ python/              # Standalone Python scripts
└─ docs/                # Rendered reports
```


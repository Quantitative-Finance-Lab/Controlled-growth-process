# Controlled growth process

This repository provides the public implementation of the controlled growth process (CGP) analysis used in the study “Facial Sentiment and Verbal Content in Harmony: Theory and Evidence.” The study examines manually verified transcripts from official South Korean housing-policy announcement videos and compares policy periods characterized by relatively stable and unstable policy stances.

The CGP component is used to quantify two lexical properties:
1. the scaling exponent of the word-frequency distribution; and  
2. the interaction effect implied by the CGP model, interpreted in the study as text cohesion.

The transcripts belonging to the same policy period are combined into a group-level corpus. Accordingly, the CGP parameters are estimated at the policy-period level rather than separately for each policy announcement.

Study-specific numerical settings and local directory paths are not included in the publicly available code.

---

## 2. Controlled Growth Process

The controlled growth process is a framework for describing the evolution of elements that collectively form a probability distribution.

When the model is applied to textual data, each word is treated as an evolving element. As a transcript progresses, previously observed words may reappear and increase in frequency, while new words may enter the vocabulary.

The evolution of the word-frequency distribution is characterized by three principal parameters:

- $b$: the growth factor, representing the increase in the frequencies of existing words;
- $\lambda$: the occurrence rate, representing the rate at which existing word frequencies are updated; and
- $r$: the production rate, representing the increase in the number of distinct words.

Using these parameters, the CGP model produces a model-implied scaling exponent:

$$ \alpha_{\mathrm{mod}}=\frac{\ln\left(1+\frac{r}{\lambda}\right)}{\ln(1+b)}.$$

An empirical scaling exponent is estimated separately from the observed word-frequency distribution using a power-law fitting procedure.

The interaction effect is subsequently derived by comparing the empirical scaling exponent with the distribution implied by the CGP parameters:

$$c= \sqrt{2\left[1-\frac{(1+b)^{\alpha_{\mathrm{emp}}}}{1+r/\lambda}\right]}.$$

In this study, \(c\) is interpreted as a measure of text cohesion. A larger value of \(c\) indicates a stronger interaction among the words constituting the policy transcript under the assumptions of the CGP framework.

<p align="center">
  <img src="figures/Figure_1.png" width="750">
</p>

<p align="center">
  <b>Figure 1.</b> Schematic representation of the controlled growth process applied to policy transcripts.
</p>

---

## 3. Data Description

### 3.1 Policy transcript data

The `data` directory contains the manually verified transcripts of official South Korean housing policy announcements.

```text
data/
└── Policy_Statements.xlsx
```

The Excel file contains two worksheets corresponding to the two policy periods examined in the study:

| Worksheet | Description |
|---|---|
| `Stable_Policy_Period` | Housing policy announcement records corresponding to the relatively stable policy period |
| `Unstable_Policy_Period` | Housing policy announcement records corresponding to the relatively unstable policy period |

After observations without available transcript text are excluded, the CGP analysis uses:

| Policy period | Number of transcripts |
|---|---:|
| Stable policy period | 11 |
| Unstable policy period | 25 |

Each row represents one official housing policy announcement.

### 3.2 Variables

The public CGP dataset contains the following variables:

| Variable | Description |
|---|---|
| `date` | Date on which the housing policy was announced |
| `keyword` | Short label identifying the policy announcement |
| `topic` | Main policy content or principal measures included in the announcement |
| `speaker` | Name and institutional position of the policy announcer |
| `link` | URL of the original policy announcement video |
| `text` | Manually verified full transcript used in the CGP analysis |

Among these variables, only the `text` column is directly used to calculate the word-frequency distribution and CGP parameters. The remaining variables provide descriptive and source information for each policy announcement.

The original working dataset also contains the following supplementary variables:

| Variable | Description |
|---|---|
| `summary` | Extended summary of the corresponding policy announcement |
| `sentimentscore` | Stored sentiment score associated with the summarized policy content |
| `threelines` | Condensed three-sentence summary of the policy announcement |
| `logit` | Stored model logit associated with the summarized content |

These supplementary variables are not used in the CGP calculation. They may therefore be excluded from the CGP-specific public dataset to avoid confusion regarding the analytical inputs.

---

## 4. Core Code for the CGP Analysis

The complete analytical notebook is provided in:

```text
code/parkmoon_cgp.ipynb
```

Only the central computational procedures are presented below. Study-specific numerical settings, estimated cutoff values, empirical results, and local file paths have been omitted.

### 4.1 Loading and organizing the transcripts

The policy transcripts are loaded separately for each policy period. Missing transcript values are replaced with empty strings, and the remaining transcripts are concatenated into a single group-level corpus.

The corpus is then divided into consecutive units containing a fixed number of words.

```python
import pandas as pd

# Select one policy-period worksheet
df = pd.read_excel(
    "data/Policy_Statements.xlsx",
    sheet_name="<POLICY_PERIOD>"
)

df.reset_index(drop=True, inplace=True)

# Remove line breaks and surrounding whitespace
df["text"] = (
    df["text"]
    .str.replace("\n", "", regex=False)
    .str.strip()
)

# Replace missing transcripts with empty strings
df["text"] = df["text"].fillna("")

# Combine all transcripts within the selected policy period
text = ""

for i in range(len(df)):
    t = str(df["text"][i])
    text += t

# Study-specific progression size
page_len = <PRIVATE_PARAMETER>

words_list = []
t = text.split()
m = len(t) // page_len

for i in range(1, m + 1):
    words_list.append(
        t[page_len * (i - 1):page_len * i]
    )

paper = pd.DataFrame(
    data=None,
    index=range(0, len(words_list))
)

paper["text"] = ""

for i in range(0, len(words_list)):
    t = ""

    for j in range(0, len(words_list[i])):
        t += words_list[i][j]
        t += " "

    paper["text"][i] = t
```

Only complete progression units are retained. The same progression size is applied consistently across the policy-period corpora.

---

### 4.2 Calculating cumulative word frequencies

Korean morphological information is obtained using the Kkma analyzer implemented in KoNLPy.

For each word, trailing Korean particles identified by Kkma are separated from the corresponding surface word and treated as individual elements. The word list is accumulated as the corpus progresses.

Consequently, `freq[i]` represents the cumulative word-frequency distribution from the beginning of the corpus through progression \(i\).

```python
from collections import Counter
from konlpy.tag import Kkma
import re

kkma = Kkma()

# Cumulative list of words
nouns_list = []

# Cumulative frequency distribution for each progression
freq = []

for i in range(0, len(paper["text"])):

    try:
        print((i + 1), "/", len(paper["text"]))

        x = str(paper["text"][i])

        # Retain Korean characters, English letters, and numbers
        x = re.sub(
            r"[^\uAC00-\uD7A30-9a-zA-Z\s]",
            " ",
            x
        )

        one_page = x.split()

        for word in one_page:
            pos_list = kkma.pos(word)

            try:
                # Separate trailing Korean particles
                while pos_list[-1][1][0] == "J":
                    junc_word = pos_list.pop(-1)
                    word = word[:-len(junc_word[0])]
                    nouns_list.append(junc_word[0])

            except IndexError:
                pass

            if word:
                nouns_list.append(word)

    except KeyError:
        pass

    # Cumulative frequency distribution at progression i
    cnt = Counter(nouns_list)
    res = cnt.most_common()
    freq.append(res)

# Final word-frequency distribution
count = Counter(nouns_list)
frequency = count.most_common()
```

The final frequency distribution is exported as a CSV file for the subsequent power-law fitting procedure.

```python
import csv

with open(
    "<FREQUENCY_FILE>.csv",
    "w",
    encoding="utf-8-sig"
) as file:

    writer = csv.writer(
        file,
        lineterminator="\n"
    )

    writer.writerow([
        "word",
        "frequency"
    ])

    writer.writerows(frequency)
```

Words below the empirically estimated lower bound of the power-law region are excluded before the CGP parameters are calibrated. The estimated lower bound and study-specific numerical values are not hard-coded in the public notebook.

---

### 4.3 Estimating the empirical scaling exponent

The empirical scaling exponent is estimated from the final word-frequency distribution using the MATLAB implementation of the power-law fitting procedure.

The frequency values exported from Python are loaded into MATLAB as a numerical vector:

```matlab
x = xlsread( ...
    '<FREQUENCY_FILE>.csv', ...
    '<SHEET_NAME>', ...
    '<PRIVATE_CELL_RANGE>' ...
);
```

The empirical scaling exponent and lower bound of the power-law region are estimated using `plfit`:

```matlab
[alpha_emp, xmin, L] = plfit(x, 'finite');
```

Here:

- `alpha_emp` is the maximum-likelihood estimate of the empirical scaling exponent;
- `xmin` is the estimated lower bound of the power-law region; and
- `L` is the log-likelihood of the observations satisfying \(x \geq x_{\min}\).

The `finite` option applies the finite-sample correction implemented in `plfit`.

The optional fitted distribution can be plotted using:

```matlab
h = plplot(x, xmin, alpha_emp);
```

The corresponding MATLAB files are provided in:

```text
code/
├── pl.m
└── plfit.m
```

The `plfit.m` implementation estimates the scaling exponent for each candidate lower bound and selects the lower bound that minimizes the Kolmogorov–Smirnov distance between the empirical and fitted distributions.

---

### 4.4 Calculating the model-implied scaling exponent

After the CGP parameters \(b\), \(\lambda\), and \(r\) have been calibrated, the scaling exponent implied by the model is calculated as follows:

```python
upper = np.log(
    1 + (r / l)
)

lower = np.log(
    1 + b
)

alpha_mod = upper / lower
```

In the code:

- `b` denotes the calibrated growth factor;
- `l` denotes the calibrated occurrence rate \(\lambda\);
- `r` denotes the calibrated production rate; and
- `alpha_mod` denotes the model-implied scaling exponent.

The numerical values of the calibrated parameters are not embedded in the publicly presented code.

---

### 4.5 Calculating text cohesion

The empirical scaling exponent estimated using `plfit` is entered into the CGP calculation as `alpha_emp`.

The interaction effect is then calculated using the same expression employed in the analytical notebook:

```python
alpha_emp = <EMPIRICAL_SCALING_EXPONENT>

upper = (
    (1 + b) ** alpha_emp
)

lower = (
    1 + (r / l)
)

c = np.sqrt(
    2 * (
        1 - (upper / lower)
    )
)
```

The resulting value `c` represents the interaction effect implied by the CGP model and is interpreted in the study as text cohesion.

The final analytical outputs are displayed as follows:

```python
print("b:", np.round(b, 3))
print("l:", np.round(l, 3))
print("r:", np.round(r, 3))
print("alpha_mod:", np.round(alpha_mod, 3))
print("alpha_emp:", np.round(alpha_emp, 3))
print("c:", np.round(c, 3))
```

The public code presents the computational structure of the analysis, while study-specific parameter values and empirical outputs are omitted.

---

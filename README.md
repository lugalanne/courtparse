# courtparser.pl — Court Search Scraper

A small Perl CLI script for parsing cases info and fulltext court documents from https://судебныерешения.рф

> **Status:** alpha.

## Requirements
- Perl 5.26+
- Modules:
  - `LWP::UserAgent`
  - `HTTP::Request::Common`
  - `HTTP::Cookies`
  - `Getopt::Long`
  - `Pod::Usage`
  - `HTML::TreeBuilder`
  - `Text::CSV_XS`

Install via cpanminus:
```bash
cpanm --notest LWP::UserAgent HTTP::Request::Common HTTP::Cookies Getopt::Long Pod::Usage Encode HTML::TreeBuilder Text::CSV_XS
```

## Installation
Clone your repo and keep the script executable:
```bash
git clone <your-repo-url>
cd <repo>
chmod +x holden.pl
```

## Usage
```bash
./holden.pl   --text "query words"   --person "Sample Name"   --type gr   --stage first   --output out.csv
```

### Options
- `--text` — free‑text query (optional).
- `--person` — person/party string (optional).
- `--type` — case type: `ug` (criminal) | `gr` (civil) | `adm` (administrative). 
- `--stage` — case stage: `first` | `appeal` | `cass` | `nadzor`.
- `--output` — output CSV path (default: `out.csv`).
- `--fulltext` — also save fulltext court documents to .txt (Will be named same as --output).
- `--help` — show usage.
- `--silent` — silent mode.
- `--n` — collect only n of cases.


## Examples
Search civil cases containing phrase “компенсация морального вреда”:
```bash
./courtparse.pl --text "компенсация морального вреда" --type gr --stage first --output kmv.csv
```

```bash
./courtparse.pl --text "Алексей Навальный" --type ug --fulltext  --output kmv.csv --silent
```




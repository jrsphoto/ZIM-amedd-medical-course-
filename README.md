# US Army Medical Course - Offline Archive

A self-hosted offline reference collection of US Army Medical Department Center and School correspondence course materials (MD-series), built for use with [Kiwix](https://kiwix.org). Part of Project Nomad.

## What This Is

This project packages public domain Army medical correspondence courses into a ZIM file that can be served locally via Kiwix. The source documents come from the [Internet Archive folkscanomy military collection](https://archive.org/search?query=US+Army+Medical+Course&and[]=collection%3A%22folkscanomy%22).

The web interface has search and discipline filtering, with a VIEW button for each document.

## Directory Structure

```
US_Army_Medical_Course/
  install.sh              # downloads PDFs, builds the ZIM, and optionally deploys
  html/
    index.html            # the web interface
    favicon.png           # 48x48 icon required by zimwriterfs
    pdfs/                 # PDFs are downloaded here (not tracked by git)
```

## Included Documents

30 courses across seven discipline areas:

- **Anatomy & Physiology** -- MD0006, MD0007, MD0577
- **Pharmacology** -- MD0801, MD0802, MD0804, MD0805, MD0806
- **Clinical / Patient Care** -- MD0010, MD0531, MD0532, MD0540, MD0547, MD0548, MD0549, MD0556
- **Nursing & Surgical** -- MD0905, MD0906, MD0928, MD0933
- **Field Medicine** -- MD0533, MD0554
- **Laboratory & Pathology** -- MD0511, MD0853, MD0859, MD0903
- **Environmental & Preventive Medicine** -- MD0161, MD0171, MD0708, MD0711

## Missing Documents

The MD-series courses were designed for specific Military Occupational Specialties (MOS) and were distributed in job-specific bundles rather than as a single complete series. This is almost certainly why the Internet Archive upload is incomplete -- whoever scanned and uploaded that batch likely had access to one or two MOS bundles, not the full catalog. The general MOS groupings are:

- **68W (Combat Medic)** -- primarily the MD0531-MD0556 range
- **68Q (Pharmacy Specialist)** -- primarily the MD0801-MD0808 range
- **68S (Preventive Medicine Specialist)** -- primarily the MD0150-MD0172 range

The Internet Archive folkscanomy upload (by "Sketch the Cow", February 2016) is a fixed batch and does not include the full MD-series. The following courses are known to exist but were not uploaded to IA and cannot be downloaded by this installer:

**General Medical & Preventive Medicine**
- MD0001 -- Evacuation in the Field
- MD0004 -- Organization and Functions of the Army Medical Department
- MD0151 -- Principles of Epidemiology and Microbiology
- MD0153 -- Water Supply in the Field
- MD0154 -- Control of Communicable Diseases
- MD0170 -- Arthropod Identification and Surveys
- MD0172 -- Rodent Biology, Survey, and Control

**Clinical & Specialty Medicine**
- MD0501 -- Dental Anatomy and Physiology
- MD0543 -- Physical Clinical Procedures
- MD0703 -- Food Service Sanitation
- MD0722 -- Veterinary Parasitology
- MD0752 -- Patient Accountability

**Pharmacy & Nursing**
- MD0807 -- Pharmacy Administration and Supply
- MD0808 -- Pharmacology V
- MD0851 -- Anatomy and Physiology Related to Clinical Pathology
- MD0910 -- Introduction to Medical X-Ray
- MD0911 -- Radiographic Procedures I
- MD0915 -- Nursing Care of the Surgical Patient
- MD0916-MD0919 -- Specialized Nursing Care modules
- MD0950 -- Chemistry I

HTML versions of all courses in the full MD-series are available at [armymedical.tpub.com](https://armymedical.tpub.com). Several are also available as PDFs at [nursing411.org](https://nursing411.org). If you obtain PDFs of any missing courses, place them in `html/pdfs/` using the naming convention `US_Army_Medical_Course_<Title>_<MDXXXX>.pdf`, add the corresponding entry to the `manuals` array in `html/index.html`, and rebuild with `--skip-download`.

## Setup

This should be run directly on the machine hosting the Kiwix/Nomad server.

### 1. Install Dependencies

```bash
sudo apt install wget unzip python3 zim-tools
```

### 2. Clone the Repo

```bash
git clone https://github.com/jrsphoto/ZIM-army-medical-course.git
cd ZIM-army-medical-course
chmod +x install.sh
```

### 3. Run the Installer

```bash
./install.sh \
  --deploy \
  --zim-dest=/your/kiwix/library \
  --container=your_kiwix_container
```

This will:
- Download each PDF individually from archive.org (~30 files, modest total size)
- Extract PDFs into `html/pdfs/`
- Build `army_medical_course.zim` in the current directory
- Copy the ZIM to your Kiwix library directory with correct ownership
- Register it with the Kiwix library XML
- Restart the Kiwix container

Failed downloads are skipped with a warning and listed at the end of the download step. Re-run without `--skip-download` to retry any that failed -- files already present are skipped automatically.

## Script Options

| Option | Description |
|--------|-------------|
| `--skip-download` | Skip the PDF download, use existing files in `html/pdfs/` |
| `--skip-zim` | Skip the ZIM build, just download the PDFs |
| `--deploy` | Automatically deploy to Kiwix after building (requires `--zim-dest` and `--container`) |
| `--zim-dest=PATH` | Path to your Kiwix library directory on the host |
| `--container=NAME` | Name of your Kiwix Docker container |

## Rebuilding

If you update `index.html` or add more PDFs, re-run with `--skip-download` and `--deploy`:

```bash
./install.sh --skip-download \
  --deploy \
  --zim-dest=/your/kiwix/library \
  --container=your_kiwix_container
```

The script removes any existing entries for this ZIM from the Kiwix library before re-adding, so no duplicates accumulate over time.

## Dependencies

- `wget` -- downloads the PDF files
- `unzip` -- extracts the downloaded zips
- `python3` -- checked as a dependency (used for potential scripting extensions)
- `zimwriterfs` -- part of the `zim-tools` package
- Docker with a running Kiwix container

## Source

All documents are public domain US government publications sourced from:
https://archive.org/search?query=US+Army+Medical+Course&and[]=collection%3A%22folkscanomy%22
# ZIM-amedd-medical-course-

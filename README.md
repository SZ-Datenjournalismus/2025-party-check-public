# SZ-DDJ Template for Data Analysis in R

*Based on rddj-template by [Timo Grossenbacher](https://github.com/grssnbchr/rddj-template)*

## Features

* Comes with cutting-edge, tried-and-tested packages for efficient data journalism with R, such as the `tidyverse`
* Runs out of the box and in one go, user doesn't have to have anything pre-installed (except R and maybe RStudio)
* Code **linting** according to the `tidyverse` style guide
* Preconfigured `.gitignore` which ignores shadow files, access tokens and the like per default

## Differences to rddj-template

Does not come with:

* *Full* **reproducibility** with package snapshots (--> `checkpoint` package)
* Automatic deployment of knitted RMarkdown files (and zipped source code) to **GitHub pages**, see [this example](https://grssnbchr.github.io/rddj-template)

*For more information on the original rddj-template please see the [accompanying blog post](https://timogrossenbacher.ch/2017/07/a-truly-reproducible-r-workflow/)*.

## Setup

If you'd like to start a new project, navigate to this project's Github Repository Page and use the "Use this template" feature. *See Github's [Creating a repository from a template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template) Docs for more info*

### Project & Repository Names

Repository names are descriptive, but only use lowercase characters, numbers and no special characters. The only space-like character we use is `-`. They usually have a 3-fold structure:

```text
year-title-type
```

* They start with the **Year the Project/Repository was started in**. If it's clear, that most work will only happen next year (example: starting a project late December), you may start it with the appropriate next-year. Projects do not usually get renamed when they are continued in the next year.
* The title is a short, descriptive project name.
* The type indicates the character of the project, like `analyse`, `scraper`, or `automation`.
* A Project Name might look like `2022-midterms-analyse`.

### Folder & File Names

* Folder and file names should be written in lowercase characters, numbers and no special characters. The only space-like character we use is `_`.
* There are execeptions like `README.md` or `License`.
* An example is `scripts/my_script.R`.


### Other Git/Versioning topics

* The default Git-Branch name is `main`. Git users may have gotten used to `master`, but `main` is where it's at in 2022(f).

## How to run

0. Always open the project in RStudio using the R-Project, this ensures that the correct paths are always set.

1. The main document `main.Rmd` lies in the root folder. This is where you'll do your main analysis.

2. Set your RStudio to run Rmd code in the project directory. This default can be set in your RStudio options: "R Markdown" - "Evaluate chunks in directory" - "Project". Or you can set it manually in the Rmd file's toolbar: "Knit" - "Knit Directory" - "Project Directory".

3. **Run the script**: The individual R chunks should be run in the interpreter (`Code > Run Region > Run All`) on Linux/Windows: <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd>, on Mac: <kbd>Cmd</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd>). Be advised that some packages, like `rgdal`, need additional third party libraries installed. Watch out for compiler/installation messages in the R console. Also, you need to have the `knitr` and `rstudioapi` packages globally installed, e.g. installed via the RStudio package manager. On a Mac, occasional `y/n:` prompts may show up in the R console during package installation (section "install packages") – just confirm them by pressing `y` and <kbd>Enter</kbd>. 

**WARNING**: It is recommended to restart R (`Session > Restart R`) when starting from scratch, i.e. use `Session > Restart R and Run All Chunks` instead of `Run All Chunks`.


## Linting / styleguide

Code is automatically *linted* with `lintr`, i.e. checked for good style and syntax errors according to the [tidyverse style guide](http://style.tidyverse.org/). When being knitted, the `lintr` output is at the very end of the document. When being interpreted, the `lintr` output appears in a new `Markers` pane at the bottom of RStudio. If you want to disable linting, just comment that last line in `main.Rmd` out.

## Other stuff / more features

### Versioning of input and output

`input` and `output` files are not ignored by default. This has the advantage that output can be monitored for change when (subtle) details of the R code are changed. 

If you want to ignore (big) input or output files, put them into the respective `ignore` folders. GitHub only allows a maximum file size of 100MB as of summer 2017.

### Ability to outsource code to script files

If you want to keep your `main.Rmd` as tidy and brief as possible, you have the possibility to put separate functions and other code into script files that reside in the `scripts` folder. An example of this is provided in `main.Rmd`.

### Multiple CPU cores for faster package installation

By default, more than one core is used for package installation, which significantly speeds up the process.

### Optimal RStudio settings

It is recommended to disable workspace saving in RStudio, see  https://mran.microsoft.com/documents/rro/reproducibility/doc-research/ 


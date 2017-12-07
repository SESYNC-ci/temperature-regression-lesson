# look up slides and lesson number in Jekyll _config.yml
SLIDES := $(shell ruby -e "require 'yaml';puts YAML.load_file('docs/_config.yml')['slide_sorter']")
LESSON := $(shell ruby -e "require 'yaml';puts YAML.load_file('docs/_config.yml')['lesson']")

# list available Markdown, RMarkdown and Pweave slides
SLIDES_MD := $(shell find . -path "./docs/_slides_md/*.md")
SLIDES_RMD := $(shell find . -path "./docs/_slides_Rmd/*.Rmd")
SLIDES_PMD := $(shell find . -path "./docs/_slides_pmd/*.pmd")

# look up auxillary files trainees will require in Jekyll _config.yml
HANDOUTS := $(shell ruby -e "require 'yaml';puts YAML.load_file('docs/_config.yml')['handouts']")
WORKSHEETS := $(addprefix ../../, $(patsubst worksheet%,worksheet-$(LESSON)%,$(filter worksheet%, $(HANDOUTS))))
DATA := $(addprefix ../, $(filter-out worksheet%, $(HANDOUTS)))

# do not run rules in parallel; because
# - bin/build_slides.R runs over all .Rmd slides
# - rsync -r only needs to run once
.NOTPARALLEL:
.DEFAULT_GOAL: slides
.PHONY: course lesson slides archive

# target to build .md slides
slides: $(SLIDES:%=docs/_slides/%.md) | .git/refs/remotes/upstream

# target to ensure upstream remote is lesson-style
.git/refs/remotes/upstream:
	git remote add upstream "git@github.com:sesync-ci/lesson-style.git"
	git fetch upstream
	git branch --track upstream upstream/master

# cannot use a pattern as the next three targets, because
# the targets are only a subset of docs/_slides/%.md

$(subst _md,,$(SLIDES_MD)): docs/_slides/%: docs/_slides_md/%
	cp $< $@

$(subst _Rmd,,$(SLIDES_RMD:.Rmd=.md)): $(SLIDES_RMD)
	@bin/build_slides.R

$(subst _pmd,,$(SLIDES_PMD:.pmd=.md)): $(SLIDES_PMD)
	@bin/build_slides.py

# target to update lesson repo on GitHub
lesson: slides
	git pull
	if [ -n "$$(git status -s)" ]; then git commit -am 'commit by make'; fi
	git fetch upstream master:upstream
	git merge --no-edit upstream
	git push
# FIXME should create handouts.zip (with worksheets, Rproj, and data) for binary but not upload to github

# make target "course" and dependencies copy handouts to ../../
# adding a lesson number to any "worksheet"
# course is called from the handouts Makefile
# with root assumed to be at ../
course: lesson $(WORKSHEETS) $(DATA)
# FIXME add DATA files to handouts/build/data ?
# FIXME use http://sesync.us/lq4iu for link sharing, zip ?

$(WORKSHEETS): ../../worksheet-$(LESSON)%: worksheet%
	cp $< $@

$(DATA): ../%: %
	cp --recursive $< $@

# must call the archive target with a
# command line parameter for DATE
archive:
	@curl "https://sesync-ci.github.io/$${PWD##*/}/course/archive.html" -o docs/_posts/$(DATE)-index.html

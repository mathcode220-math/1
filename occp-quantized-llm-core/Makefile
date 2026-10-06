PYTHON ?= python3
export PYTHONPATH := $(CURDIR)

.PHONY: all setup generate reference compress export test rtl-sim compare report verify golden two-layer clean help

all: setup generate reference compress export test rtl-sim compare report

setup:
	$(PYTHON) -c "import numpy, pytest; print('python deps ok')"

generate:
	$(PYTHON) software/pipeline.py generate

reference:
	$(PYTHON) software/pipeline.py reference

compress:
	$(PYTHON) software/pipeline.py compress

export:
	$(PYTHON) software/pipeline.py export

test:
	$(PYTHON) -m pytest tests/unit tests/regression -q

rtl-sim:
	$(PYTHON) -m software.run_sim

compare:
	$(PYTHON) -m software.compare

report:
	@test -f results/report.md

two-layer:
	$(PYTHON) -m pytest tests/integration/test_two_layers.py -q

verify:
	$(PYTHON) tools/verify.py --check-claims

golden:
	$(PYTHON) -m pytest tests/unit tests/integration -q

clean:
	rm -f results/weights.npz results/weights_compressed.npz results/reference.npy
	rm -f results/weights.hex results/input.hex results/bias.hex results/rtl_output.hex
	rm -f results/rtl_cycles.txt results/sim_seconds.txt results/compare.json results/compress_stats.json
	rm -f results/rtl_output_2layer.hex results/rtl_cycles_2layer.txt
	rm -rf build

help:
	@echo "make all  - INT8 Linear+ReLU proof in this standalone tree"

SIM-MOCK = simv-mock
SIM = simv
FILELIST = filelist
MODEL = "VGG16_project_part1"

.PHONY = sim clean run download_weights

download_weights:
	mkdir -p result/$(MODEL)
	wget -O result/$(MODEL)/model_best.pth.tar https://storage.googleapis.com/ece284-project/part1_model_best.pth.tar

sim:
	for i in 0 1 2 3 4 5 6 7; do \
		iverilog -g2012 -o $(SIM) -f $(FILELIST) -D ACT=$$i; \
		vvp $(SIM); \
	done

clean:
	rm -f $(SIM) *.vcd

run: clean sim

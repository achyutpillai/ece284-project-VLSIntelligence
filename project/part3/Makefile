SIM-MOCK = simv-mock
SIM = simv
FILELIST = filelist
MODEL = "VGG16_project_part1"

.PHONY = sim clean run download_weights

download_weights:
	mkdir -p result/$(MODEL)
	wget -O result/$(MODEL)/model_best.pth.tar https://storage.googleapis.com/ece284-project/part1_model_best.pth.tar

sim:
	iverilog -o $(SIM) -f $(FILELIST)
	vvp $(SIM)

clean:
	rm -f $(SIM) *.vcd

run: clean sim

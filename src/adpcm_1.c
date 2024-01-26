#include <stdio.h>

char index_table[16] = {
	-1, -1, -1, -1, 2, 4, 6, 8, 
	-1, -1, -1, -1, 2, 4, 6, 8
};

short step_table[89] = {
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 
	19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 
	130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 
	337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 
	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 
	5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

#define PCM_MAX 32767
#define PCM_MIN -32768

short sigma, step;
short diff, predict;
unsigned char idx;
unsigned char delta, sign;

#define nst_predict			(sign ? (predict - sigma) : (predict + sigma))
#define clamp_nst_predict	((nst_predict > PCM_MAX) ? PCM_MAX : (nst_predict < PCM_MIN) ? PCM_MIN : nst_predict)
#define index_sigma			index_table[delta]
#define clamp_idx			((idx < 0) ? 0 : (idx > 88) ? 88 : idx)
#define nst_step			step_table[clamp_idx]
#define nst_sigma			(sigma + step)

void adpcm_init() {
	predict = 0;
	idx = 0;
	step = 0;
}

void adpcm_tx(short* pcm, char* adpcm) {
	// idle 
	diff = *pcm - predict;
	// load 
	delta = 0;
	sigma = step >> 3;
	sign = (diff < 0) ? 8 : 0;
	// b3 
	diff = sign ? ~diff + 1 : diff;
	// b2 
	if(diff >= step) {
		delta = 4;
		diff = diff - step;
		sigma = nst_sigma;
	}
	step = step >> 1;
	// b1 
	if(diff >= step) {
		delta = delta | 2;
		diff = diff - step;
		sigma = nst_sigma;
	}
	step = step >> 1;
	// b0 
	if(diff >= step) {
		delta = delta | 1;
		sigma = nst_sigma;
	}
	// update 
	predict = clamp_nst_predict;
	delta = 0xf & (delta | sign);
	idx = idx + index_sigma;
	step = nst_step;
	// idle 
	*adpcm = delta;
}

void adpcm_rx(char* adpcm, short* pcm) {
	// idle 
	delta = *adpcm;
	// load 
	idx = idx + index_sigma;
	sigma = step >> 3;
	sign = delta & 8;
	// b3 
	delta = delta & 7;
	// b2 
	if(delta & 4) sigma = nst_sigma;
	step = step >> 1;
	// b1 
	if(delta & 2) sigma = nst_sigma;
	step = step >> 1;
	// b0 
	if(delta & 1) sigma = nst_sigma;
	// update 
	predict = clamp_nst_predict;
	step = nst_step;
	// idle 
	*pcm = predict;
}

void pcm2adpcm(short* pcm, char* adpcm, int len) {
	int i;
	adpcm_init();
	for(i = 0; i < len; i++) adpcm_tx(pcm+i, adpcm+i);
}

void adpcm2pcm(char* adpcm, short* pcm, int len) {
	int i;
	adpcm_init();
	for(i = 0; i < len; i++) adpcm_rx(adpcm+i, pcm+i);
}

/******************************************************************************************************************/

void print_verilog_index_table(FILE* fp) {
	int i;
	fprintf(fp, "\nmodule index_table(\n	output [6:0] index_sigma, \n	input [3:0] delta\n);\n");
	fprintf(fp, "\nassign index_sigma = ");
	for(i = 0; i < 16; i++) {
		if(i % 4 == 0) fprintf(fp, "\n	");
		fprintf(fp, "(delta == 4'h%1x) ? 7'h%02x : ", i, (index_table[i] & 0x7f));
	}
	fprintf(fp, "\n	0;\n");
	fprintf(fp, "\nendmodule\n");
}

void print_verilog_step_table(FILE* fp) {
	int i;
	fprintf(fp, "\nmodule step_table(\n	output [14:0] nst_step, \n	input [6:0] idx\n);\n");
	fprintf(fp, "\nassign nst_step = ");
	for(i = 0; i < 89; i++) {
		if(i % 4 == 0) fprintf(fp, "\n	");
		fprintf(fp, "(idx == 7'h%02x) ? 15'h%04x : ", (i & 0x7f), (step_table[i] & 0x7fff));
	}
	fprintf(fp, "\n	0;\n");
	fprintf(fp, "\nendmodule\n");
}

#define adpcm_tables "../rtl/adpcm_tables.v"

void print_verilog_adpcm_tables() {
	FILE* fp;
	printf("print_verilog_adpcm_tables to %s\n", adpcm_tables);
	fp = fopen(adpcm_tables, "w");
	print_verilog_index_table(fp);
	fprintf(fp, "\n");
	print_verilog_step_table(fp);
	fclose(fp);
}

/******************************************************************************************************************/

#include <math.h>
#define len	10000
#define test1_dat "../data/test1.dat"
#define test1_plt "../work/test1.plt"
#define adpcm2int(d) ((d&8) ? (0 - (d&7)) : (d&7))

void test1() {
	FILE* fp;
	short pcm0[len] = {0};
	char adpcm[len];
	short pcm1[len];
	int i;
	
	printf("test1 start\n");

	for (i = 0; i < len; i++) {
		pcm0[i] = (short)(
			(PCM_MAX*0.5) * sin(i*0.001*2*3.1415926) + 
			(PCM_MAX*0.05) * sin(i*0.01*2*3.1415926) +
			(PCM_MAX*0.005) * sin(i*0.1*2*3.1415926)
		);
	}

	pcm2adpcm(pcm0, adpcm, len);
	adpcm2pcm(adpcm, pcm1, len);

	fp = fopen(test1_dat, "w");
	//fprintf(fp, "pcm0	adpcm	pcm1\n");
	for (i = 0; i < len; i++) fprintf(fp, "%d	%d	%d	%d	\n", i, pcm0[i], adpcm2int(adpcm[i]), pcm1[i]);
	fclose(fp);
	
	fp = fopen(test1_plt, "w");
	fprintf(fp, "plot '%s' using 1:2 with lines, '%s' using 1:3 with lines, '%s' using 1:4 with line", 
		test1_dat, test1_dat, test1_dat);
	fclose(fp);
	printf("gnuplot cmd: load '%s'\n", test1_plt);
	
	printf("test1 end\n");
}

/******************************************************************************************************************/

int main(){
	print_verilog_adpcm_tables();
	test1();
	return 0;
}

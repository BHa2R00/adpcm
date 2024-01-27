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
#define nst_idx				(idx + index_table[delta])
#define clamp_idx			((idx & 0x40) ? 0 : (88 < idx) ? 88 : idx)
#define nst_step			step_table[clamp_idx]
#define nst_sigma			(sigma + step)
#define lt_diff_step		(diff < step)

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
	diff = sign ? (-diff) : diff;
	delta = sign;
	// b2 
	if(!lt_diff_step) {
		delta = delta | 4;
		diff = diff - step;
		sigma = nst_sigma;
	}
	step = step >> 1;
	// b1 
	if(!lt_diff_step) {
		delta = delta | 2;
		diff = diff - step;
		sigma = nst_sigma;
	}
	step = step >> 1;
	// b0 
	if(!lt_diff_step) {
		delta = delta | 1;
		sigma = nst_sigma;
	}
	// update 
	predict = clamp_nst_predict;
	idx = nst_idx;
	// step
	step = nst_step;
	*adpcm = delta;
}

void adpcm_rx(char* adpcm, short* pcm) {
	// idle 
	delta = *adpcm;
	// load 
	idx = nst_idx;
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
	// step
	step = nst_step;
	*pcm = predict;
}

/******************************************************************************************************************/

#define adpcm_tx_trace "../data/adpcm_tx_trace_c.data"

void pcm2adpcm(short* pcm, char* adpcm, int len) {
	int i;
#ifdef adpcm_tx_trace
	FILE* fp = fopen(adpcm_tx_trace, "w");
#endif
	adpcm_init();
	for(i = 0; i < len; i++) {
		adpcm_tx(pcm+i, adpcm+i);
#ifdef adpcm_tx_trace
		fprintf(fp, "%6d	", sigma);
		fprintf(fp, "%6d	", step);
		fprintf(fp, "%6d	", diff);
		fprintf(fp, "%6d	", predict);
		fprintf(fp, "%6d	", idx);
		fprintf(fp, "%6d	", delta);
		fprintf(fp, "%6d	", clamp_idx);
		fprintf(fp, "%6d\n", nst_step);
#endif
	}
	fclose(fp);
}

#define adpcm_rx_trace "../data/adpcm_rx_trace_c.data"

void adpcm2pcm(char* adpcm, short* pcm, int len) {
	int i;
#ifdef adpcm_rx_trace
	FILE* fp = fopen(adpcm_rx_trace, "w");
#endif
	adpcm_init();
	for(i = 0; i < len; i++) {
		adpcm_rx(adpcm+i, pcm+i);
#ifdef adpcm_rx_trace
		fprintf(fp, "%6d	", sigma);
		fprintf(fp, "%6d	", step);
		fprintf(fp, "%6d	", diff);
		fprintf(fp, "%6d	", predict);
		fprintf(fp, "%6d	", idx);
		fprintf(fp, "%6d	", delta);
		fprintf(fp, "%6d	", clamp_idx);
		fprintf(fp, "%6d\n", nst_step);
#endif
	}
	fclose(fp);
}

/******************************************************************************************************************/

#define adpcm_nst_idx "../rtl/adpcm_nst_idx.v"

void print_verilog_nst_idx() {
	FILE* fp;
	int i;
	printf("print_verilog_nst_idx to %s\n", adpcm_nst_idx);
	fp = fopen(adpcm_nst_idx, "w");
	fprintf(fp, "wire [6:0] nst_idx = ");
	for(i = 0; i < 16; i++) {
		if(i % 4 == 0) fprintf(fp, "\n	");
		if(index_table[i] < 0) {
			fprintf(fp, "(delta == 4'h%1x) ? idx - %d : ", i, ~index_table[i] + 1);
		} else {
			fprintf(fp, "(delta == 4'h%1x) ? idx + %d : ", i, index_table[i]);
		}
	}
	fprintf(fp, "\n	0;\n");
	fclose(fp);
}

#define adpcm_nst_step "../rtl/adpcm_nst_step.v"

void print_verilog_nst_step() {
	FILE* fp;
	int i;
	printf("print_verilog_nst_step to %s\n", adpcm_nst_step);
	fp = fopen(adpcm_nst_step, "w");
	fprintf(fp, "wire signed [15:0] nst_step = ");
	for(i = 0; i < 89; i++) {
		if(i % 4 == 0) fprintf(fp, "\n	");
		fprintf(fp, "(clamp_idx == %2d) ? %5d : ", i, step_table[i]);
	}
	fprintf(fp, "\n	0;\n");
	fclose(fp);
}

/******************************************************************************************************************/

#include <math.h>
#define len	50000
#define test1_dat "../data/test1.dat"
#define test1_plt "../work/test1.plt"

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
	for (i = 0; i < len; i++) fprintf(fp, "%d	%d	%d	%d	\n", i, pcm0[i], adpcm[i], pcm1[i]);
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
	print_verilog_nst_idx();
	print_verilog_nst_step();
	test1();
	return 0;
}

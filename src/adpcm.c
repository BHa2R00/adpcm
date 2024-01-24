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

short diff, sigma, step;
short predict;
char delta, idx, sign;

void adpcm_init() {
	predict = 0;
	idx = 0;
	step = 0;
}

void adpcm_tx(short* pcm, char* adpcm) {
	diff = *pcm - predict;
	sign = (diff < 0) ? 8 : 0;
	delta = 0;
	sigma = step >> 3;
	diff = sign ? ~diff + 1 : diff;
	if(diff >= step) {
		delta = 4;
		diff = diff - step;
		sigma = sigma + step;
	}
	step = step >> 1;
	if(diff >= step) {
		delta = delta | 2;
		diff = diff - step;
		sigma = sigma + step;
	}
	step = step >> 1;
	if(diff >= step) {
		delta = delta | 1;
		sigma = sigma + step;
	}
	predict = sign ? (predict - sigma) : (predict + sigma);
	predict = (predict > PCM_MAX) ? PCM_MAX : (predict < PCM_MIN) ? PCM_MIN : predict;
	delta = 0xf & (delta | sign);
	idx = idx + index_table[delta];
	step = step_table[((idx < 0) ? 0 : (idx > 88) ? 88 : idx)];
	*adpcm = delta;
}

void adpcm_rx(char* adpcm, short* pcm) {
	delta = *adpcm;
	idx = idx + index_table[delta];
	sign = delta & 8;
	delta = delta & 7;
	sigma = step >> 3;
	if(delta & 4) sigma = sigma + step;
	if(delta & 2) sigma = sigma + (step >> 1);
	if(delta & 1) sigma = sigma + (step >> 2);
	predict = sign ? (predict - sigma) : (predict + sigma);
	predict = (predict > PCM_MAX) ? PCM_MAX : (predict < PCM_MIN) ? PCM_MIN : predict;
	step = step_table[((idx < 0) ? 0 : (idx > 88) ? 88 : idx)];
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

#include <math.h>

int main() {
	#define len	10000
	short pcm0[len] = {0};
	char adpcm[len];
	short pcm1[len];
	int i;

	for (i = 0; i < len; i++) {
		pcm0[i] = (short)(
			(PCM_MAX*0.5) * sin(i*0.001*2*3.1415926) + 
			(PCM_MAX*0.05) * sin(i*0.01*2*3.1415926) +
			(PCM_MAX*0.005) * sin(i*0.1*2*3.1415926)
		);
	}

	pcm2adpcm(pcm0, adpcm, len);
	adpcm2pcm(adpcm, pcm1, len);

	printf("pcm0	adpcm	pcm1\n");
	for (i = 0; i < len; i++) printf("%d	%d	%d	%d	\n", i, pcm0[i], adpcm[i], pcm1[i]);

	return 0;
}

/*
  cc ../src/adpcm.c -lm
  ./a.out > 1.data
  gnuplot
  plot '1.data' using 1:2 with lines, '1.data' using 1:3 with lines, '1.data' using 1:4 with line
*/

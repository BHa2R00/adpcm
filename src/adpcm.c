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

#define PCM_MAX 32768
#define PCM_MIN -32768

void pcm2adpcm(short* pcm, char* adpcm, int len) {
	int i;
	short sigma, step;
	short diff, predict;
	char idx;
	unsigned char delta, sign;

	predict = 0;
	idx = 0;
	step = step_table[0];

	for(i = 0; i < len; i++) {
		diff = pcm[i] - predict;
		sign = (diff < 0) ? 8 : 0;
		if(sign) diff = ~diff + 1;
		delta = 0;
		sigma = step >> 3;
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
		if(sign) predict = predict - sigma;
		else predict = predict + sigma;
		if(predict > PCM_MAX) predict = PCM_MAX;
		else if(predict < PCM_MIN) predict = PCM_MIN;
		delta = delta | sign;
		idx = idx + index_table[delta];
		if(idx < 0) idx = 0;
		else if(idx > 88) idx = 88;
		step = step_table[idx];
        adpcm[i] = delta & 0xf;
	}
}

void adpcm2pcm(char* adpcm, short* pcm, int len) {
	int i;
	short sigma, step;
	short diff, predict;
	char idx;
	unsigned char delta, sign;

	predict = 0;
	idx = 0;
	step = step_table[0];

	for(i = 0; i < len; i++) {
		delta = adpcm[i];
		idx = idx + index_table[delta];
		if(idx < 0) idx = 0;
		else if(idx > 88) idx = 88;
		sign = delta & 8;
		delta = delta & 7;
		sigma = step >> 3;
		if(delta & 4) sigma = sigma + step;
		if(delta & 2) sigma = sigma + (step >> 1);
		if(delta & 1) sigma = sigma + (step >> 2);
		if(sign) predict = predict - sigma;
		else predict = predict + sigma;
		if(predict > PCM_MAX) predict = PCM_MAX;
		else if(predict < PCM_MIN) predict = PCM_MIN;
		step = step_table[idx];
        pcm[i] = predict;
	}
}

#include <math.h>
#define adpcm2int(d) ((d&8) ? (0 - (d&7)) : (d&7))

int main() {
	#define len	10000
    short pcm0[len] = {0};
    char adpcm[len];
    short pcm1[len];
    
	for (int i = 0; i < len; i++) {
		pcm0[i] = (short)(
			(PCM_MAX*0.5) * sin(i*0.001) + 
			(PCM_MAX*0.05) * sin(i*0.01) +
			(PCM_MAX*0.005) * sin(i*0.01)
		);
	}

    pcm2adpcm(pcm0, adpcm, len);
    adpcm2pcm(adpcm, pcm1, len);

    printf("pcm0	adpcm	pcm1\n");
    for (int i = 0; i < len; i++) {
        printf("%d	%d	%d	%d	\n", i, pcm0[i], adpcm2int(adpcm[i]), pcm1[i]);
    }

    return 0;
}

/*
  cc ../src/adpcm.c -lm
  ./a.out > 1.data
  gnuplot
  plot '1.data' using 1:2 with lines, '1.data' using 1:3 with lines, '1.data' using 1:4 with line
*/

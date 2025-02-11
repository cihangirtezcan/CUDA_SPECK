#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <stdint.h>
#define ROR(x, r) ((x >> r) | (x << (64 - r))) 
#define ROL(x, r) ((x << r) | (x >> (64 - r)))
#define R(x, y, k) (x = ROR(x, 8), x += y, x ^= k, y = ROL(y, 3), y ^= x)
// SPECK64
#define ER32(x,y,k) (x=ROTR32(x,8), x+=y, x^=k, y=ROTL32(y,3), y^=x)
#define ER24(x,y,k) (x=ROTR24(x,8)& 0xffffff, x+=y, x&=0xffffff, x^=k, y=ROTL24(y,3)& 0xffffff, y^=x)
#define ER16(x,y,k) (x=ROTR16(x,7), x+=y, x^=k, y=ROTL16(y,2), y^=x)
#define ER16b(x,y,k) (x=ROTR16b(x,7), x+=y, x^=k, y=ROTL16b(y,2), y^=x)
#define DR32(x,y,k) (y^=x, y=ROTR32(y,3), x^=k, x-=y, x=ROTL32(x,8))
#define ROTL32(x,r) (((x)<<(r)) | (x>>(32-(r))))
#define ROTL24(x,r) (((x)<<(r)) | (x>>(24-(r))))
#define ROTL16(x,r) (((x)<<(r)) | (x>>(16-(r))))
#define ROTL16b(x,r) ((((x)<<(r)) | (x>>(16-(r))))&0xFFFF)
#define ROTR32(x,r) (((x)>>(r)) | ((x)<<(32-(r))))
#define ROTR24(x,r) (((x)>>(r)) | ((x)<<(24-(r))))
#define ROTR16(x,r) (((x)>>(r)) | ((x)<<(16-(r))))
#define ROTR16b(x,r) ((((x)>>(r)) | ((x)<<(16-(r))))&0xFFFF)
#define ROTL64(x,r) (((x)<<(r)) | (x>>(64-(r))))
#define ROTR64(x,r) (((x)>>(r)) | ((x)<<(64-(r))))


#define ROUNDS 32
#define BLOCKS				1024
#define THREADS				1024  // Cannot be less than 256

void Speck6496KeySchedule(uint32_t K[], uint32_t rk[]) {
    uint32_t i, C = K[2], B = K[1], A = K[0];
    for (i = 0; i < 26;) {
        rk[i] = A; ER32(B, A, i++);
        rk[i] = A; ER32(C, A, i++);
    }
}
void Speck6496Encrypt(uint32_t Pt[], uint32_t Ct[], uint32_t rk[]) {
    uint32_t i;
    Ct[0] = Pt[0]; Ct[1] = Pt[1];
    for (i = 0; i < 26;) {
        ER32(Ct[1], Ct[0], rk[i++]);
        printf("plaintext: %08x 0%08x\n", Ct[0], Ct[1]);
    }
}
void Speck6496Encrypt2(uint32_t Pt[], uint32_t Ct[], uint32_t K[]) {
    uint32_t i=0, C = K[2], B = K[1], A = K[0];
    Ct[0] = Pt[0]; Ct[1] = Pt[1];
    
    for (int j = 0; j < 12;j++) {
        ER32(Ct[1], Ct[0], A);
        ER32(B, A, i++);
        ER32(Ct[1], Ct[0], A); 
        ER32(C, A, i++);
    }
    ER32(Ct[1], Ct[0], A);
    ER32(B, A, i++);
    ER32(Ct[1], Ct[0], A);
}
void Speck6472Encrypt2(uint32_t Pt[], uint32_t Ct[], uint32_t K[]) {
    uint32_t i = 0, C = K[2], B = K[1], A = K[0];
    Ct[0] = Pt[0]; Ct[1] = Pt[1];

    for (int j = 0; j < 10; j++) {
        ER24(Ct[1], Ct[0], A);
        ER24(B, A, i++);
        ER24(Ct[1], Ct[0], A);
        ER24(C, A, i++);
    }
    ER24(Ct[1], Ct[0], A);
    ER24(B, A, i++);
    ER24(Ct[1], Ct[0], A);
}
void Speck6464Encrypt(uint16_t Pt[], uint16_t Ct[], uint16_t K[]) {
    uint16_t i = 0, D = K[3], C = K[2], B = K[1], A = K[0];
    Ct[0] = Pt[0]; Ct[1] = Pt[1];
    for (int j = 0; j < 7; j++) {
        ER16(Ct[1], Ct[0], A);
        ER16(B, A, i++);
        ER16(Ct[1], Ct[0], A);
        ER16(C, A, i++);
        ER16(Ct[1], Ct[0], A);
        ER16(D, A, i++);
    }
    ER16(Ct[1], Ct[0], A);

}
void encrypt(uint64_t ct[2], uint64_t const pt[2], uint64_t const K[2]) {
    uint64_t y = pt[0], x = pt[1], b = K[0], a = K[1];
    R(x, y, b);
    for (int i = 0; i < ROUNDS - 1; i++) {
        R(a, b, i);
        R(x, y, b);
    }
    ct[0] = y;
    ct[1] = x;
}
__global__ void speck_exhaustive(uint64_t *ct, uint64_t* pt, uint64_t* K, uint64_t trials ) {    
    uint64_t threadIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    uint64_t b, a, x, y;
//    uint64_t pt0 = pt[0], pt1 = pt[1];
//    uint64_t ct0 = ct[0], ct1 = ct[1];
    uint64_t pt0 = pt[0], pt1 = pt[1];
    uint64_t ct0 = ct[0], ct1 = ct[1];
    for (uint64_t trial = 0; trial < trials; trial++) {        
        b = threadIndex;
        a = trial;
        y = pt0; x = pt1;        
        R(x, y, b);
        for (int i = 0; i < ROUNDS - 1; i++) {
            R(a, b, i);
            R(x, y, b);
        }
        if ((y == ct0) && (x == ct1)) {            K[0] = threadIndex; K[1] = trial;    }
    } 
}
__global__ void speck96_exhaustive(uint32_t* ct, uint32_t* pt, uint32_t* K, uint64_t trials) {
    uint32_t threadIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    uint32_t pt0 = pt[0], pt1 = pt[1], ct0, ct1;
    uint32_t c0 = ct[0], c1 = ct[1];
    uint32_t A, B, C;
    for (uint32_t trial = 0; trial < trials; trial++) {
        uint32_t i = 0;
        ct0 = pt0; ct1 = pt1;
        A = threadIndex;
        B = trial;
        C = 0x13121110l;
#pragma unroll
        for (int j = 0; j < 12; j++) {
            ER32(ct1, ct0, A);
            ER32(B, A, i++);
            ER32(ct1, ct0, A);
            ER32(C, A, i++);
        }
        ER32(ct1, ct0, A);
        ER32(B, A, i++);
        ER32(ct1, ct0, A);
        if ((ct0 == c0) && (ct1 == c1)) { K[0] = threadIndex; K[1] = trial; K[2] = 0x13121110; }
    }
}
__global__ void speck72_exhaustive(uint32_t* ct, uint32_t* pt, uint32_t* K, uint64_t trials) {
    uint32_t threadIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    uint32_t pt0 = pt[0], pt1 = pt[1], ct0, ct1;
    uint32_t c0 = ct[0], c1 = ct[1];
    uint32_t A, B, C;
    for (uint32_t trial = 0; trial < trials; trial++) {
        uint32_t i = 0;
        ct0 = pt0; ct1 = pt1;
        A = threadIndex;
        B = trial;
        C = 0x121110;
#pragma unroll
        for (int j = 0; j < 10; j++) {
            ER24(ct1, ct0, A);
            ER24(B, A, i++);
            ER24(ct1, ct0, A);
            ER24(C, A, i++);
        }
        ER24(ct1, ct0, A);
        ER24(B, A, i++);
        ER24(ct1, ct0, A);
        if ((ct0 == c0) && (ct1 == c1)) { K[0] = threadIndex; K[1] = trial; K[2] = 0x121110; }
    }
}
__global__ void speck64_exhaustive(uint16_t* ct, uint16_t* pt, uint16_t* K, uint32_t trials) {
    uint32_t threadIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    uint16_t pt0 = pt[0], pt1 = pt[1], ct0, ct1;
    uint16_t c0 = ct[0], c1 = ct[1];
    uint16_t A, B, C, D;
    for (uint32_t trial = 0; trial < trials; trial++) {
        uint16_t i = 0;
        ct0 = pt0; ct1 = pt1;
        A = threadIndex>>16;
        B = threadIndex & 0xFFFF;
 //       C = 0x1110;
        C = 0x00ab;
        D = trial;
        for (int j = 0; j < 7; j++) {
            ER16(ct1, ct0, A);
            ER16(B, A, i++);
            ER16(ct1, ct0, A);
            ER16(C, A, i++);
            ER16(ct1, ct0, A);
            ER16(D, A, i++);
        }
        ER16(ct1, ct0, A);
        if ((ct0 == c0) && (ct1 == c1)) { K[0] = threadIndex >> 16; K[1] = threadIndex & 0xffff; K[2] = 0x1110; K[3] = trial;  }
    }
}
__global__ void speck64_exhaustive32bit(uint32_t* ct, uint32_t* pt, uint32_t* K, uint32_t trials) {
    uint32_t threadIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    uint32_t pt0 = pt[0], pt1 = pt[1], ct0, ct1;
    uint32_t c0 = ct[0], c1 = ct[1];
    uint32_t A, B, C, D;
    for (uint32_t trial = 0; trial < trials; trial++) {
        uint32_t i = 0;
        ct0 = pt0; ct1 = pt1;
        A = threadIndex >> 16;
        B = threadIndex & 0xFFFF;
        //       C = 0x1110;
        C = 0x00ab;
        D = trial;
        for (int j = 0; j < 7; j++) {
            ER16b(ct1, ct0, A);
            ER16b(B, A, i++);
            ER16b(ct1, ct0, A);
            ER16b(C, A, i++);
            ER16b(ct1, ct0, A);
            ER16b(D, A, i++);
        }
        ER16b(ct1, ct0, A);
        if ((ct0 == c0) && (ct1 == c1)) { K[0] = threadIndex >> 16; K[1] = threadIndex & 0xffff; K[2] = 0x1110; K[3] = trial; }
    }
}

int main_C() {
    uint32_t pt[2] = { 0x736e6165, 0x74614620  };
    uint32_t ct[2] = { 0 }; // Ciphertext: 4175946c 09f7952ec
//    uint32_t K[3] = {   0x03020100, 0x0b0a0908, 0x13121110 };
    uint32_t K[3] = { 0x000015f6, 0x000001ab, 0x13121110 }; 
    //Ciphertext: 0c85aae1 0438f26e5
    uint32_t rk[26] = { 0 };
    Speck6496Encrypt2(pt, ct, K);
    printf("Ciphertext: %08x 0%08x\n", ct[0], ct[1]);
    Speck6496KeySchedule(K, rk);
    for (int i = 0; i < 26; i++) printf("%08x\n",rk[i]);
    Speck6496Encrypt(pt,ct,rk);
    printf("Ciphertext: %08x 0%08x\n", ct[0], ct[1]);
    return 0;
}
//SPECK 96/64
int main96() {
    cudaSetDevice(0);
    uint32_t ct[2] = { 0x0c85aae1, 0x0438f26e5 }, pt[2] = { 0x736e6165, 0x74614620 }, K[3] = { 0xffffffff, 0xffffffff, 0xffffffff };
    // corrrect key K[2] = { 0x3, 0x5 };
    uint32_t* ct_d; uint32_t* pt_d; uint32_t* K_d;
    uint32_t trial = 1;
    printf("Trials 2^20 + ");
    scanf_s("%d", &trial);
    trial = (uint32_t)1 << trial;
    // Ciphertext: 9c3df6b05f625cb2 5da73f447979dccd
    // encrypt(ct, pt, K);
    // printf("Ciphertext: %llx %llx\n", ct[0], ct[1]);
    cudaMalloc((void**)&ct_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&pt_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&K_d, 3 * sizeof(uint32_t));
    cudaMemcpy(pt_d, pt, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(ct_d, ct, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(K_d, K, 3 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    float time = 0;
    cudaEvent_t startx, stopx;
    cudaEventCreate(&startx);    cudaEventCreate(&stopx);    cudaEventRecord(startx);
    speck96_exhaustive << <BLOCKS, THREADS >> > (ct_d, pt_d, K_d, trial);
    cudaMemcpy(K, K_d, 3 * sizeof(uint32_t), cudaMemcpyDeviceToHost);
    cudaEventRecord(stopx);    cudaEventSynchronize(stopx);    cudaEventElapsedTime(&time, startx, stopx);
    printf("Captured key: %08x %08x %08x\n", K[0], K[1], K[2]);
    printf("Elapsed time: %f\n", time);
    printf("%s\n", cudaGetErrorString(cudaGetLastError()));
    return 0;
}
//SPECK 128/128
int main128() { 
    cudaSetDevice(0);
    uint64_t ct[2] = { 0x9c3df6b05f625cb2, 0x5da73f447979dccd }, pt[2] = { 0x01234567, 0x89abcdef }, K[2] = { 0xffffffffffffffff, 0xffffffffffffffff };
    // corrrect key K[2] = { 0x3, 0x5 };
    uint64_t *ct_d; uint64_t* pt_d; uint64_t* K_d;
    uint64_t trial = 1;
    printf("Trials 2^20 + ");
    scanf_s("%lld", &trial);
    trial = (uint64_t)1 << trial;
    // Ciphertext: 9c3df6b05f625cb2 5da73f447979dccd
    // encrypt(ct, pt, K);
    // printf("Ciphertext: %llx %llx\n", ct[0], ct[1]);

    cudaMalloc((void**)&ct_d, 2 * sizeof(uint64_t));
    cudaMalloc((void**)&pt_d, 2 * sizeof(uint64_t));
    cudaMalloc((void**)&K_d, 2 * sizeof(uint64_t));
    cudaMemcpy(pt_d, pt, 2 * sizeof(uint64_t), cudaMemcpyHostToDevice);
    cudaMemcpy(ct_d, ct, 2 * sizeof(uint64_t), cudaMemcpyHostToDevice);
    cudaMemcpy(K_d, K, 2 * sizeof(uint64_t), cudaMemcpyHostToDevice);
    float time = 0;
    cudaEvent_t startx, stopx;
    cudaEventCreate(&startx);    cudaEventCreate(&stopx);    cudaEventRecord(startx);
    speck_exhaustive << <BLOCKS, THREADS >> > (ct_d, pt_d, K_d, trial);

    cudaMemcpy(K, K_d, 2 * sizeof(uint64_t), cudaMemcpyDeviceToHost);
    cudaEventRecord(stopx);    cudaEventSynchronize(stopx);    cudaEventElapsedTime(&time, startx, stopx);
    printf("Captured key: %llx %llx\n", K[0], K[1]);

    printf("Elapsed time: %f\n", time);
    printf("%s\n", cudaGetErrorString(cudaGetLastError()));
    return 0;
}
//SPECK 64
int main64b() {
// Key: 1918 1110 0908 0100
// Plaintext: 6574 694c
// Ciphertext : a868 42f2
//    uint16_t ct[2] = { 0x42f2, 0xa868 }, pt[2] = {  0x694c, 0x6574 }, K[4] = { 0xffff, 0xffff, 0xffff, 0xffff };
//    uint16_t ct[2] = { 0, 0 }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0x0100, 0x0908, 0x1110, 0x1918 };
//    uint16_t ct[2] = { 0x4ca5, 0xa08c }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0x0001, 0x0098, 0x00ab, 0x00f7 };
    uint16_t ct[2] = { 0x4ca5, 0xa08c }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0xffff, 0xffff, 0xffff, 0xffff };
    uint16_t* ct_d; uint16_t* pt_d; uint16_t* K_d;
    uint32_t trial = 1;
//    Speck6464Encrypt(pt, ct, K);
//    printf("Ciphertext: %04x %04x\n", ct[0], ct[1]);
    printf("Trials 2^20 + ");
    scanf_s("%d", &trial);
    trial = (uint32_t)1 << trial;

    cudaMalloc((void**)&ct_d, 2 * sizeof(uint16_t));
    cudaMalloc((void**)&pt_d, 2 * sizeof(uint16_t));
    cudaMalloc((void**)&K_d, 4 * sizeof(uint16_t));
    cudaMemcpy(pt_d, pt, 2 * sizeof(uint16_t), cudaMemcpyHostToDevice);
    cudaMemcpy(ct_d, ct, 2 * sizeof(uint16_t), cudaMemcpyHostToDevice);
    cudaMemcpy(K_d, K, 4 * sizeof(uint16_t), cudaMemcpyHostToDevice);
    float time = 0;
    cudaEvent_t startx, stopx;
    cudaEventCreate(&startx);    cudaEventCreate(&stopx);    cudaEventRecord(startx);
    speck64_exhaustive << <BLOCKS, THREADS >> > (ct_d, pt_d, K_d, trial);
    cudaMemcpy(K, K_d, 4 * sizeof(uint16_t), cudaMemcpyDeviceToHost);
    cudaEventRecord(stopx);    cudaEventSynchronize(stopx);    cudaEventElapsedTime(&time, startx, stopx);
    printf("Captured key: %04x %04x %04x %04x\n", K[0], K[1], K[2], K[3]);
    printf("Elapsed time: %f\n", time);
    printf("%s\n", cudaGetErrorString(cudaGetLastError()));
    return 0;
}
int main64() {
    cudaSetDevice(0);
    // Key: 1918 1110 0908 0100
    // Plaintext: 6574 694c
    // Ciphertext : a868 42f2
    //    uint16_t ct[2] = { 0x42f2, 0xa868 }, pt[2] = {  0x694c, 0x6574 }, K[4] = { 0xffff, 0xffff, 0xffff, 0xffff };
    //    uint16_t ct[2] = { 0, 0 }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0x0100, 0x0908, 0x1110, 0x1918 };
    //    uint16_t ct[2] = { 0x4ca5, 0xa08c }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0x0001, 0x0098, 0x00ab, 0x00f7 };
    uint32_t ct[2] = { 0x4ca5, 0xa08c }, pt[2] = { 0x694c, 0x6574 }, K[4] = { 0xffff, 0xffff, 0xffff, 0xffff };
    uint32_t* ct_d; uint32_t* pt_d; uint32_t* K_d;
    uint32_t trial = 1;
    //    Speck6464Encrypt(pt, ct, K);
    //    printf("Ciphertext: %04x %04x\n", ct[0], ct[1]);
    printf("Trials 2^20 + ");
    scanf_s("%d", &trial);
    trial = (uint32_t)1 << trial;

    cudaMalloc((void**)&ct_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&pt_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&K_d, 4 * sizeof(uint32_t));
    cudaMemcpy(pt_d, pt, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(ct_d, ct, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(K_d, K, 4 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    float time = 0;
    cudaEvent_t startx, stopx;
    cudaEventCreate(&startx);    cudaEventCreate(&stopx);    cudaEventRecord(startx);
    speck64_exhaustive32bit << <BLOCKS, THREADS >> > (ct_d, pt_d, K_d, trial);
    cudaMemcpy(K, K_d, 4 * sizeof(uint32_t), cudaMemcpyDeviceToHost);
    cudaEventRecord(stopx);    cudaEventSynchronize(stopx);    cudaEventElapsedTime(&time, startx, stopx);
    printf("Captured key: %04x %04x %04x %04x\n", K[0], K[1], K[2], K[3]);
    printf("Elapsed time: %f\n", time);
    printf("%s\n", cudaGetErrorString(cudaGetLastError()));
    return 0;
}
int main72C() {
//Key: 121110 0a0908 020100
//Plaintext : 20796c 6c6172
// Ciphertext : c049a5 385adc
    uint32_t pt[2] = { 0x6c6172, 0x20796c };
    uint32_t ct[2] = { 0 }; // 0x0080d1a9 0x000535548
    uint32_t K[3] = { 0x000100, 0x000908, 0x121110 };   
    Speck6472Encrypt2(pt, ct, K);
    printf("Ciphertext: %08x 0%08x\n", ct[0], ct[1]);
    return 0;
}
int main72() {
    cudaSetDevice(0);
    uint32_t ct[2] = { 0x0080d1a9, 0x000535548 }, pt[2] = { 0x6c6172, 0x20796c }, K[3] = { 0xffffffff, 0xffffffff, 0xffffffff };
    // corrrect key K[2] = { 0x3, 0x5 };
    uint32_t* ct_d; uint32_t* pt_d; uint32_t* K_d;
    uint32_t trial = 1;
    printf("Trials 2^20 + ");
    scanf_s("%d", &trial);
    trial = (uint32_t)1 << trial;
    // Ciphertext: 9c3df6b05f625cb2 5da73f447979dccd
    // encrypt(ct, pt, K);
    // printf("Ciphertext: %llx %llx\n", ct[0], ct[1]);
    cudaMalloc((void**)&ct_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&pt_d, 2 * sizeof(uint32_t));
    cudaMalloc((void**)&K_d, 3 * sizeof(uint32_t));
    cudaMemcpy(pt_d, pt, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(ct_d, ct, 2 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    cudaMemcpy(K_d, K, 3 * sizeof(uint32_t), cudaMemcpyHostToDevice);
    float time = 0;
    cudaEvent_t startx, stopx;
    cudaEventCreate(&startx);    cudaEventCreate(&stopx);    cudaEventRecord(startx);
    speck96_exhaustive << <BLOCKS, THREADS >> > (ct_d, pt_d, K_d, trial);
    cudaMemcpy(K, K_d, 3 * sizeof(uint32_t), cudaMemcpyDeviceToHost);
    cudaEventRecord(stopx);    cudaEventSynchronize(stopx);    cudaEventElapsedTime(&time, startx, stopx);
    printf("Captured key: %08x %08x %08x\n", K[0], K[1], K[2]);
    printf("Elapsed time: %f\n", time);
    printf("%s\n", cudaGetErrorString(cudaGetLastError()));
    return 0;
}
int main() {
    int choice = 0;
    printf("(1) SPECK-64\n"
        "(2) SPECK-72\n"
        "(3) SPECK-96\n"
        "(4) SPECK-128\n"
        "Choice: "
    );
    scanf_s("%d", &choice);
    if (choice == 1) main64();
    if (choice == 2) main72();
    if (choice == 3) main96();
    if (choice == 4) main128();
}
# CUDA_SPECK

These CUDA Optimizations are used in the ToSC publication **GPU Assisted Brute Force Cryptanalysis of GPRS, GSM, RFID, and TETRA - Brute Force Cryptanalysis of KASUMI, SPECK, and TEA3** by Cihangir Tezcan and Gregor Leander.

It measures how many seconds it takes for your GPU to perform **2^{20 + n}** key trials where **n** is a user input requested at runtime.

We represent k-bit keyed SPECK with r rounds as SPECK-k-r. On an RTX 4090, we can perform 2^{36.41}, 2^{36.71}, 2^{36.72}, and 2^{35.30} keys/s for SPECK-64-22 SPECK-72-22 SPECK-96-26 SPECK-128-32, respectively.

Since a year has around 2^{24.91} seconds, one needs around 8 RTX 4090 GPUs to break SPECK-64-22 in a year. In order to break SPECK-72-22 in a year, one needs around 2000 RTX 4090 GPUs. And to break SPECK-96-26 in a year, one needs around 22 billion RTX 4090 GPUs. Note that SPECK-96-26 is included in the ISO/IEC 29167-22 RFID air interface standard. Although 22 billion GPUs are a lot, this number is going to reduce when new generation of GPUs like NVIDIA’s 5000 series are announced and produced in 2025. According to our estimates, we expect one would need around 17.5 billion RTX 5090 GPUs to break SPECK-96-26 in a year. Those numbers are by far exceeding today’s practical capabilities. However, they show that devices built today with SPECK-96-26 may not be secure around 2050. Moreover, GPUs are general purpose computing devices and our results also show that if built, dedicated devices can break SPECK-96-26 faster than GPUs and would consume significantly less energy compared to GPUs.

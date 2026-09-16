# MobileNetV1 Workload and Design Challenges

[← MobileNetV1 overview](../README.md)

## Workload characteristic

MobileNetV1은 depthwise-separable convolution(DSC)을 사용해 계산량을 줄이지만, FPGA에서는 FLOPs 감소가 곧바로 높은 utilization이나 낮은 energy로 이어지지 않습니다.

Source portfolio에서 정리한 주요 challenge는 다음과 같습니다.

### 1. Resource utilization

layer마다 feature-map과 weight의 상대 비중이 달라 고정 parallelism만으로는 compute와 memory bandwidth를 동시에 맞추기 어렵습니다.

설계 방향:

- layer 특성에 따른 parallelism 조정
- banked local memory
- bandwidth/resource trade-off를 layer granularity에서 관리

기록된 결과:

- PE utilization **98.64%**
- LUT 기반 bank structure를 활용한 bandwidth 확보

### 2. Memory energy

large memory를 반복 활성화하면 dynamic power와 local heating 부담이 커질 수 있습니다.

설계 방향:

- small local/LUTRAM cache
- image-plane reuse
- BRAM activation 최소화
- compute와 data supply를 분리해 reuse 가능성을 높임

### 3. Inter-layer pipeline

PWC와 DWC를 완전히 순차 처리하면 producer-consumer 사이 tail latency가 남습니다.

설계 방향:

- sliding-window 기반 data handoff
- 다음 stage가 full feature-map completion을 기다리지 않도록 window-level overlap
- idle interval 감소

Source portfolio에 기록된 throughput result는 250 FPS class이며, 비교 baseline 대비 energy efficiency 1.35×, DSP efficiency 1.57× 향상을 보고합니다.

## Public claim boundary

본 문서는 설계 문제와 상위 원칙을 설명합니다.  
논문 novelty에 해당하는 PE topology, line-buffer organization, memory-hierarchy diagram과 detailed timing diagram은 공개하지 않습니다.

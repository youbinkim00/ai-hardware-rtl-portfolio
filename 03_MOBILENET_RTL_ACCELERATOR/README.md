# INT8 MobileNetV1 RTL FPGA Accelerator

> **경량 CNN의 연산·메모리 병목을 RTL로 해결하고 ZCU102 PYNQ 분류 데모까지 구현한 FPGA 가속기**

[← Portfolio home](../README.md) · [YOLOv5s project](../02_YOLOV5S_RTL_ACCELERATOR/README.md)

## 30초 요약

| 항목 | 내용 |
|---|---|
| 무엇을 만들었나? | MobileNetV1 INT8 RTL accelerator |
| 왜 어려운가? | DWC와 PWC의 연산 특성이 달라 고정 병렬 구조에서 PE 활용률과 memory efficiency가 떨어짐 |
| 어떻게 해결했나? | layer별 parallelism 조정, local memory reuse, sliding-window pipeline |
| 어디까지 했나? | Vivado implementation + ZCU102 AXI/DMA integration + PYNQ classification demo |
| 대표 결과 | 252.7 FPS · 66.9 GOPS/W · 3.34 GOPS/DSP |

## 문제 정의

MobileNetV1은 계산량이 작은 모델이지만 FPGA에서 자동으로 효율적인 것은 아닙니다.

- **Depthwise Convolution(DWC)**: channel별 독립 연산이라 범용 PE array의 활용률이 낮아질 수 있음
- **Pointwise Convolution(PWC)**: 연산량이 크고 memory bandwidth 요구가 다름
- layer마다 feature map과 weight 비중이 달라 하나의 고정 parallelism으로 전체 network를 효율적으로 처리하기 어려움

그래서 연산기 하나보다 **병렬도, memory access, layer 사이 data handoff**를 함께 설계했습니다.

## 설계 접근

### 1. Layer-adaptive parallelism

layer 특성에 따라 필요한 병렬도를 조정하고 banked local memory로 bandwidth를 확보했습니다.

- PE utilization **98.64%**
- low-cost LUT-based banking 활용

### 2. Local memory reuse

큰 memory를 반복 접근하는 대신 작은 local/LUTRAM buffer에서 데이터를 재사용해 unnecessary memory activation을 줄였습니다.

### 3. Sliding-window pipeline

앞 layer의 전체 feature map이 끝날 때까지 기다리지 않고 준비된 window부터 다음 layer가 처리하도록 producer-consumer 실행을 겹쳤습니다.

Project evidence:

- 250+ FPS class throughput
- comparison baseline 대비 energy efficiency **1.35×**
- DSP efficiency **1.57×**

세부 PE topology, line-buffer organization과 detailed timing diagram은 논문용 핵심 구조라 공개하지 않습니다.

## FPGA implementation result

| Metric | Result |
|---|---:|
| FPGA | XCZU9EG / ZCU102 |
| Clock | 150 MHz |
| Precision | INT8 / Fixed-8 |
| Input | 224×224 |
| Frame rate | **252.7 FPS** |
| Throughput | **287.6 GOPS** |
| Power | **4.296 W** |
| Power efficiency | **66.9 GOPS/W** |
| Hardware efficiency | **3.34 GOPS/DSP** |
| DSP | 86 |
| BRAM | 489.5 |
| LUT | 171.3K |
| FF | 100K |

위 FPS는 accelerator implementation 기준이며 PYNQ의 image I/O와 UI까지 포함한 end-to-end FPS와 구분합니다.

## ZCU102 AXI / DMA integration

<p align="center">
  <img src="../assets/evidence/mobilenet_zcu102_block_design.png" alt="MobileNetV1 ZCU102 Vivado block design" width="1080">
</p>
<p align="center"><sub>실제 ZCU102 Vivado Block Design. PS, AXI interface, DMA, FIFO와 custom MobileNetV1 IP의 system boundary를 보여줍니다.</sub></p>

```text
PYNQ / PS
   ↓  control + DDR buffer
AXI DMA
   ↓
AXI4-Stream / FIFO
   ↓
MobileNetV1 RTL Accelerator
```

## PYNQ classification demo

<p align="center">
  <img src="../assets/evidence/mobilenet_pynq_sw_hw_system.png" alt="MobileNetV1 PYNQ software hardware integration" width="650">
</p>

검증 범위:

- PYNQ overlay load
- accelerator control
- image payload transfer
- FPGA inference
- accelerator output과 reference result 비교
- classification result까지 application flow 연결

→ [ZCU102 PYNQ Demo 상세](docs/03_ZCU102_PYNQ_DEMO.md)

## 이 프로젝트에서 보여주는 역량

- 경량 CNN workload 분석
- INT8 QAT와 RTL 연산 규칙 연결
- SystemVerilog accelerator 설계
- memory bandwidth / reuse 최적화
- pipeline scheduling
- Vivado implementation 및 PPA 분석
- AXI DMA 기반 PS–PL 통합
- PYNQ application integration

## Research output

- **A Pipelined MobileNet Accelerator With Fine-Grained Coupling for Power and Resource Efficiency**  
  IEEE TVLSI — submitted 2026-06-12, revision in progress
- **FPGA 기반 Lightweight CNN Depthwise Convolution 가속기 설계**  
  2025 반도체공학회 하계학술대회
- **Layer-Adaptive Line Buffer Architecture for Pipelined MobileNetV1 Acceleration**  
  ICOS 2026

## Disclosure

Public repository에는 workload, implementation result, AXI/PYNQ system evidence만 공개합니다.  
full RTL, trained checkpoint, detailed compute architecture, line-buffer/memory-hierarchy figure와 detailed timing diagram은 논문 공개 전까지 포함하지 않습니다.

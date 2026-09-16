# AI/NPU RTL·FPGA 설계 포트폴리오

> **AI 모델 학습·양자화부터 SystemVerilog RTL, FPGA 구현, AXI/DMA SoC 통합, Zynq/PYNQ 데모까지 직접 연결한 HW–SW Co-design 포트폴리오**

이 저장소는 단순히 **“AI 모델을 FPGA에서 실행했다”**는 결과보다, 모델의 연산·데이터 이동 특성을 분석해 **저정밀 수치체계 → 연산기·메모리·제어 구조 → RTL 검증 → 실제 FPGA 시스템**으로 완성한 과정을 보여줍니다.

제가 직접 수행한 범위는 다음과 같습니다.

**PyTorch 모델 학습 · QAT · 지식 증류 · HW-aware Mixed Precision → SystemVerilog RTL → Integer Reference 기반 검증 → Vivado 합성·배치배선/PPA 분석 → AXI/DMA 통합 → ZCU102·ZCU104 PYNQ Demo**

---

## 30초 요약

| 구분 | 02 · MobileNetV1 | 03 · YOLOv5s |
|---|---|---|
| 응용 | 영상 분류 | 객체 검출 |
| Software / Precision | INT8 QAT · W8/A8 | QAT · Knowledge Distillation · W4/A4·A8 Mixed Precision |
| 주요 HW 문제 | DWC/PWC의 서로 다른 연산 특성, 메모리 접근 비용 | Branch/Concat/Multi-scale 경로의 계층 의존성, 연산 대기, 데이터 이동 |
| RTL 설계 | 가변 병렬도 · Sliding-window Pipeline · Local Memory Reuse | 공유 PE · 계층 의존성 기반 Dataflow · On-chip Feature Lifetime 관리 |
| Board / Device | ZCU102 / XCZU9EG | ZCU104 / XCZU7EV |
| System | AXI4-Lite/Stream · DMA · FIFO · PYNQ | AXI4-Lite/Stream · DMA · SmartConnect · FIFO · PYNQ |
| Demo | **PYNQ 영상 분류 구현** | **PYNQ 객체 검출 구현** |

---

## 핵심 구현 결과

두 프로젝트 모두 **RTL 설계 → FPGA implementation → Zynq/PYNQ application**까지 연결했습니다.  
메인 결과는 검증 로그보다 **자원·처리성능·전력효율·시스템 구현 여부** 중심으로 정리했습니다.

| Metric | MobileNetV1 | YOLOv5s |
|---|---:|---:|
| Board | ZCU102 | ZCU104 |
| FPGA Device | **XCZU9EG** | **XCZU7EV** |
| Clock | **150 MHz** | **200 MHz** |
| Weight / Activation Precision | **W8 / A8 (INT8)** | **W4 / A4·A8 (Mixed Precision)** |
| LUT | 171.3K | 157.3K |
| FF | 100K | 170.3K |
| BRAM | 489.5 | 244 |
| URAM | - | 64 |
| DSP | 86 | 1,152 |
| Frame rate | **252.7 FPS** | **76.92 FPS** |
| Throughput | **287.6 GOPS** | **1,224.4 GOPS** |
| Power report | 4.296 W | 4.59 W |
| Power efficiency | **66.9 GOPS/W** | **266.8 GOPS/W** |
| PYNQ Demo | **Image Classification 구현** | **Object Detection 구현** |

> **수치 해석 기준**  
> MobileNetV1은 **150 MHz**, YOLOv5s는 **200 MHz** 기준입니다. Power 값은 implementation power report 기준이며 board 전체 실측 전력과 구분합니다.

- [MobileNetV1 RTL Accelerator 자세히 보기](03_MOBILENET_RTL_ACCELERATOR/README.md)
- [YOLOv5s RTL Accelerator 자세히 보기](02_YOLOV5S_RTL_ACCELERATOR/README.md)

---

## Software · Quantization · HW–SW Co-design 역량

RTL을 먼저 만들고 모델을 끼워 맞춘 것이 아니라, **학습 단계부터 실제 정수 하드웨어에서 사용할 수치체계와 정확도 손실을 함께 설계**했습니다.

### MobileNetV1

- PyTorch 기반 MobileNetV1 학습 및 **INT8 QAT**
- DWC/PWC workload 특성을 RTL 병렬도와 메모리 구조에 반영
- Software 결과와 FPGA/RTL 출력의 정합성 검증

### YOLOv5s — 실제 학습 Notebook 기반

**1. FP32 Teacher + ReLU Recovery**
- PASCAL VOC20, 640×640 입력 기준 teacher 학습
- SiLU를 RTL 친화적인 ReLU로 전환
- checkpoint mapping과 남은 SiLU 여부를 검사한 뒤 accuracy recovery training

**2. Brevitas 기반 INT8 QAT**
- `Conv2d → QuantConv2d`, `ReLU → QuantReLU`
- QuantConv2d 60개 / QuantReLU 57개로 변환 후 float Conv·SiLU 잔존 여부 audit
- activation scale calibration, BN statistics freeze, EMA를 포함한 QAT flow 구성

**3. Hardware-aware W4 + A4/A8 Mixed Precision**
- 모든 convolution weight를 **W4**
- 입력과 오차에 민감한 공유 feature 경계는 **A8**
- 대부분의 내부 activation은 **A4**
- 최종 checkpoint에서 bit-width map을 다시 검사해 실제 graph의 정밀도 구성을 검증

**4. Teacher–Student Knowledge Distillation**
- Detection box
- Objectness / class
- 선택한 backbone·neck feature 표현
을 student에 전달하도록 KD loss를 구성했습니다.

> KD를 사용했다는 사실 자체를 정확도 향상으로 과장하지 않고, **저비트 학습에서 정보 손실을 완화하기 위한 학습 구성 요소**로 사용했습니다.

**5. RTL Parameter Export + Integer Reference**
- Quantized weight
- Activation scale / bit-width map
- Integer bias
- Requantization parameter
- Residual / concat 등 multi-source scale 관계
를 추출·검증한 뒤 RTL parameter로 연결했습니다.
- 원본 YOLO/Brevitas model object 없이 실행되는 **독립 Integer / RTL-C style Reference Model**을 구성해 정수 하드웨어 동작을 software에서 재검증했습니다.

| Software 검증 단계 | VOC2007 test 결과 |
|---|---:|
| 최종 W4 + selective A4/A8 Quantized Model | mAP@0.5 **80.48%** · mAP@0.5:0.95 **55.94%** |
| RTL/C-style Integer Reference | mAP@0.5 **79.79%** · mAP@0.5:0.95 **55.40%** |

즉, Software 역량은 단순한 “양자화 적용”이 아니라 **정확도 요구를 Bit-width · Requantization · RTL 연산 규칙 · Memory Cost와 연결해 판단하는 HW–SW 공동 최적화**에 있습니다.

→ [YOLOv5s Software-to-RTL Pipeline](02_YOLOV5S_RTL_ACCELERATOR/software/README.md)

---

## 실제 시스템 구현 — Zynq + PYNQ

두 프로젝트 모두 **AMD-Xilinx Zynq UltraScale+ 보드**를 사용해 실제 PS–PL 시스템까지 구현했습니다.

- **MobileNetV1**: ZCU102 + AXI DMA + FIFO + PYNQ 기반 영상 분류
- **YOLOv5s**: ZCU104 + AXI DMA + SmartConnect + FIFO + PYNQ 기반 객체 검출

PYNQ 환경에서는 Python application이 PS에서 overlay와 DMA를 제어하고, PL의 custom RTL accelerator가 inference를 수행하도록 구성했습니다.

아래 사진은 **ZCU104 + PYNQ 기반 YOLOv5s 객체 검출 시스템을 대표 예시로 보여주는 실제 Demo**입니다.

<p align="center">
  <img src="assets/evidence/yolov5s_zcu104_pynq_demo.png" alt="ZCU104 PYNQ YOLOv5s 객체 검출 데모" width="850">
</p>
<p align="center"><sub>실제 ZCU104 FPGA Board + PYNQ Runtime + YOLOv5s Object Detection Demo</sub></p>

Software와 PL을 분리하지 않고 **입력 → DMA → RTL Accelerator → 후처리 → 결과 표시**까지 application flow를 연결했습니다.

실제 Vivado system integration:

- [MobileNetV1 ZCU102 AXI/DMA System](03_MOBILENET_RTL_ACCELERATOR/README.md#zcu102-axi--dma-integration)
- [YOLOv5s ZCU104 AXI/DMA System](02_YOLOV5S_RTL_ACCELERATOR/docs/05_ZCU104_DMA_INTEGRATION.md)

---

## 이 포트폴리오에서 확인할 수 있는 역량

### 1. AI 모델 학습 · 양자화 · 저정밀 최적화
PyTorch 기반 model training, ReLU recovery, QAT, Knowledge Distillation, hardware-aware mixed precision을 직접 구성했습니다.  
정확도만 보는 것이 아니라 **실제 RTL bit-width와 연산 비용까지 함께 판단**했습니다.

### 2. Software–RTL Numeric Contract 설계
Scale, signedness, rounding, saturation, bias, requantization을 software reference와 RTL에서 동일하게 정의하고 parameter export와 bit-width map을 검증했습니다.

### 3. SystemVerilog 기반 RTL Architecture 설계
연산 블록만 구현하지 않고 **PE, Pipeline, Memory Controller, Buffer, Address Generation, Requantization, Layer Control**을 함께 설계했습니다.

### 4. 데이터 이동 · 메모리 · Scheduling 최적화
MobileNetV1에서는 DWC/PWC local reuse와 Sliding-window Pipeline을, YOLOv5s에서는 장거리 branch feature map의 on-chip 유지와 dependency-aware scheduling을 적용했습니다.

### 5. 검증 가능한 RTL 개발
Integer Reference와 Golden Data를 기반으로 RTL 출력을 자동 비교하고, AXI에서는 입력 gap과 output backpressure 조건까지 별도 검증했습니다.

### 6. FPGA Physical Implementation
Vivado에서 synthesis 숫자만 확인하지 않고 **Timing, Fanout, Placement, Routing Congestion, Resource, Power**를 분석해 RTL과 implementation 전략을 조정했습니다.

### 7. AXI / Zynq / PYNQ System Integration
AXI4-Lite control, AXI4-Stream data, DMA, FIFO, SmartConnect를 이용해 PS–PL system을 구성하고 두 가속기를 실제 application demo까지 연결했습니다.

---

## 설계 방법론

AI로 생성한 영어 infographic 대신, 실제 프로젝트에서 사용한 개발 절차를 **한글 중심으로** 정리했습니다.

| 단계 | 핵심 질문 | 실제 수행 내용 |
|---|---|---|
| **1. 모델·정밀도 분석** | 어떤 연산과 정밀도가 정확도/비용에 민감한가? | QAT · KD · Mixed Precision · Layer/Boundary 분석 |
| **2. HW 구조 결정** | 어떤 병렬도·Pipeline·Memory 구조가 적합한가? | PE 역할 · Buffer · Dataflow · On-chip Reuse 설계 |
| **3. 수치·기능 검증** | Software와 RTL이 같은 계산을 하는가? | Integer Reference · Parameter Export · Golden Regression |
| **4. 시스템 통합** | PS/DDR/PL 환경에서도 안정적인가? | AXI4-Lite/Stream · DMA · FIFO · Backpressure 검증 |
| **5. 물리 구현** | 실제 FPGA에서 목표 PPA를 만족할 수 있는가? | Timing · Fanout · Congestion · Resource · Power 분석 |
| **6. Board Demo** | 전체 application으로 동작하는가? | ZCU102/ZCU104 PYNQ 영상 분류·객체 검출 Demo |

핵심은 특정 RTL 모듈 하나가 아니라 **Model → Numeric Design → RTL Architecture → Verification → Physical Implementation → System Demo**를 하나의 engineering flow로 닫는 것입니다.

---

## 프로젝트 자세히 보기

### 02 · MobileNetV1
- [MobileNetV1 RTL Accelerator](03_MOBILENET_RTL_ACCELERATOR/README.md)

### 03 · YOLOv5s
- [YOLOv5s RTL Accelerator](02_YOLOV5S_RTL_ACCELERATOR/README.md)
- [Software / QAT / Mixed Precision](02_YOLOV5S_RTL_ACCELERATOR/software/README.md)
- [Software–RTL Numeric Contract](02_YOLOV5S_RTL_ACCELERATOR/docs/02_SW_RTL_NUMERIC_CONTRACT.md)
- [Verification Strategy](02_YOLOV5S_RTL_ACCELERATOR/docs/03_VERIFICATION_STRATEGY.md)
- [AXI VIP Verification](02_YOLOV5S_RTL_ACCELERATOR/docs/04_AXI_VIP_VERIFICATION.md)
- [ZCU104 DMA Integration](02_YOLOV5S_RTL_ACCELERATOR/docs/05_ZCU104_DMA_INTEGRATION.md)
- [Physical Design Debugging](02_YOLOV5S_RTL_ACCELERATOR/docs/06_PHYSICAL_DESIGN_DEBUGGING.md)
- [Engineering Notes](02_YOLOV5S_RTL_ACCELERATOR/engineering_notes/README.md)

---

## 결과 해석 기준

서로 다른 검증 경계의 수치를 하나의 성능으로 섞지 않습니다.

- Accelerator cycle 기반 FPS ≠ Camera-to-display FPS
- Vivado/Implementation Power Report ≠ Board 전체 실측 전력
- Routing 성공 ≠ Timing Closure 완료
- Software Quantized Model ≠ RTL/C-style Integer Reference

---

## 공개 범위

논문 및 연구 결과의 지식재산을 보호하기 위해 전체 RTL, Trained Weight, Parameter Payload, Golden Vector, 상세 PE/Memory Architecture와 Bitstream은 공개하지 않습니다.

공개 범위는 [Disclosure Policy](DISCLOSURE_POLICY.md)를 따릅니다.

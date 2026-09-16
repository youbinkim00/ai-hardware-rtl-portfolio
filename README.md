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

- [MobileNetV1 RTL Accelerator 자세히 보기](02_MOBILENET_RTL_ACCELERATOR/README.md)
- [YOLOv5s RTL Accelerator 자세히 보기](03_YOLOV5S_RTL_ACCELERATOR/README.md)

---

## Software · Quantization · HW–SW Co-design 역량

두 프로젝트 모두 RTL을 먼저 만든 뒤 모델을 맞춘 것이 아니라, **학습·양자화 단계부터 실제 정수 하드웨어의 bit-width, scale, requantization과 연결**했습니다.

### MobileNetV1 — 실제 INT8 QAT Notebook 기반

**1. ImageNet pretrained MobileNetV1 + INT8 QAT**
- `timm`의 `mobilenetv1_100` pretrained model을 기반으로 QAT flow 구성
- FBGEMM QAT에서 activation은 **per-tensor asymmetric**, weight는 **per-channel symmetric INT8**로 학습
- `QuantStub / DeQuantStub`, FakeQuant와 Observer를 이용해 training 단계에서 정수 양자화 동작을 모사

**2. ImageNet QAT Fine-tuning**
- ILSVRC2012 train set, 224×224 입력
- `RandomResizedCrop`, `RandomHorizontalFlip`, `ColorJitter` 기반 augmentation
- Batch 64, **AdamW**, label smoothing, **CosineAnnealingLR**, 20 epoch fine-tuning
- activation/weight 분포에 맞춰 scale과 zero-point를 학습

**3. Fully Quantized INT8 Model 검증**
- QAT model을 실제 INT8 inference model로 변환
- FP32와 INT8 model을 동일한 ILSVRC2012 validation flow에서 Top-1 / Top-5로 비교

| MobileNetV1 Software Result | FP32 | INT8 QAT |
|---|---:|---:|
| Top-1 Accuracy | 69.64% | **69.24%** |
| Top-5 Accuracy | 89.20% | **88.79%** |
| Model Size | 16.67 MB | **4.40 MB** |

**4. RTL용 정수 Parameter 생성**
- INT8 weight와 per-channel weight scale 추출
- FP32 bias를 **INT32 bias**로 변환
- `(input scale × weight scale) / output scale`을 RTL에서 사용할 **integer multiplier + shift** 형태로 근사
- layer별 activation/feature map을 추출하고 RTL memory format용 정수/HEX data로 변환

**5. Integer Reference 경로 구성**
- Stem과 각 DWC/PWC block을 `INT32 accumulation → integer requantization → uint8 activation` 순서로 재구성
- PyTorch quantized layer output과 layer별로 비교할 수 있는 독립 정수 reference path를 구성

즉 MobileNetV1에서도 단순 INT8 변환에 그치지 않고, **QAT → 정수 parameter 추출 → requantization 설계 → RTL 입력/weight format → integer reference**까지 연결했습니다.

### YOLOv5s — 실제 학습 Notebook 기반

**1. Low-bit QAT와 Mixed Precision**
- FP32 model을 RTL 친화적인 ReLU 구조로 전환하고 accuracy recovery 수행
- INT8 QAT를 거쳐 모든 convolution weight는 **W4**
- 대부분의 activation은 **A4**, 입력과 민감한 공유 feature 경계는 **A8**로 구성

**2. Knowledge Distillation**
- FP32 Teacher와 Quantized Student 사이에서 **box · object/class · selected feature** 정보를 이용한 KD 구성
- 저비트 학습 과정에서 표현 손실을 완화하는 training component로 사용

**3. RTL Parameter Export + Integer Reference**
- Weight, activation scale, bias, requantization parameter와 multi-source scale 관계를 RTL용으로 export
- 원본 YOLO/Brevitas 객체에 의존하지 않는 **독립 Integer / RTL-C style Reference Model**로 전체 모델 재검증

| YOLOv5s Software Result | VOC2007 test |
|---|---:|
| W4 + selective A4/A8 Quantized Model | mAP@0.5 **80.48%** · mAP@0.5:0.95 **55.94%** |
| RTL/C-style Integer Reference | mAP@0.5 **79.79%** · mAP@0.5:0.95 **55.40%** |

두 프로젝트를 통해 보여주고 싶은 Software 역량은 단순한 “양자화 적용”이 아니라, **정확도 요구를 Bit-width · Scale · Requantization · RTL 연산 규칙 · Memory Cost와 연결해 판단하는 HW–SW 공동 최적화**입니다.

→ [YOLOv5s Software-to-RTL Pipeline](03_YOLOV5S_RTL_ACCELERATOR/software/README.md)

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

- [MobileNetV1 ZCU102 AXI/DMA System](02_MOBILENET_RTL_ACCELERATOR/README.md#zcu102-axi--dma-integration)
- [YOLOv5s ZCU104 AXI/DMA System](03_YOLOV5S_RTL_ACCELERATOR/docs/05_ZCU104_DMA_INTEGRATION.md)

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
- [MobileNetV1 RTL Accelerator](02_MOBILENET_RTL_ACCELERATOR/README.md)

### 03 · YOLOv5s
- [YOLOv5s RTL Accelerator](03_YOLOV5S_RTL_ACCELERATOR/README.md)
- [Software / QAT / Mixed Precision](03_YOLOV5S_RTL_ACCELERATOR/software/README.md)
- [Software–RTL Numeric Contract](03_YOLOV5S_RTL_ACCELERATOR/docs/02_SW_RTL_NUMERIC_CONTRACT.md)
- [Verification Strategy](03_YOLOV5S_RTL_ACCELERATOR/docs/03_VERIFICATION_STRATEGY.md)
- [AXI VIP Verification](03_YOLOV5S_RTL_ACCELERATOR/docs/04_AXI_VIP_VERIFICATION.md)
- [ZCU104 DMA Integration](03_YOLOV5S_RTL_ACCELERATOR/docs/05_ZCU104_DMA_INTEGRATION.md)
- [Physical Design Debugging](03_YOLOV5S_RTL_ACCELERATOR/docs/06_PHYSICAL_DESIGN_DEBUGGING.md)
- [Engineering Notes](03_YOLOV5S_RTL_ACCELERATOR/engineering_notes/README.md)

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

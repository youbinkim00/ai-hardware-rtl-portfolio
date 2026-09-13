# AI Accelerator RTL Engineering Portfolio

> AI 모델 분석부터 저정밀 학습, RTL 아키텍처, 자동 검증, AXI SoC 통합과 FPGA 물리 구현까지 직접 연결한 하드웨어 설계 포트폴리오

이 저장소는 “AI 모델을 FPGA에서 실행했다”는 결과보다, 복잡한 AI workload를 **검증 가능한 디지털 하드웨어 시스템**으로 바꾸는 과정과 판단 근거를 보여준다. 논문 투고 전 지식재산을 보호하기 위해 전체 RTL과 세부 스케줄은 공개하지 않으며, 외부에서 검토 가능한 설계 원칙·검증 결과·실패 분석을 중심으로 구성했다.

## 30-second summary

| 질문 | 답변 |
|---|---|
| 무엇을 설계했는가? | YOLOv5s 계열 detector를 위한 혼합 정밀도 SystemVerilog RTL 가속기와 Zynq 기반 SoC 데이터 경로 |
| 무엇이 다른가? | 모델의 주요 graph를 축소해 난도를 피하지 않고, 인접 2~3개 계층의 의존성과 데이터 수명을 함께 분석해 공유 PE의 역할·전달·실행 순서를 정함 |
| 정확성을 어떻게 증명했는가? | PyTorch 정수 모델 → 계층별 golden → full-layer RTL scoreboard → AXI VIP stress → routed implementation의 검증 사슬 구축 |
| 시스템 수준에서 무엇을 다뤘는가? | AXI4-Lite 제어, AXI4-Stream, DMA, backpressure, URAM 이식, timing·congestion·DCP 분석 |
| 공개하지 않는 것은? | 전체 RTL, 학습 weight, parameter payload, 상세 PE/메모리 구조, 논문용 핵심 도면과 bitstream |

## Evidence snapshot

| 검증 항목 | 확인된 결과 | 근거 수준 |
|---|---:|---|
| 전체 추론 PE 활용률 | 90.8% | RTL cycle schedule 측정 |
| RTL 수치 모델 정확도 | mAP@0.5 79.79%, mAP@0.5:0.95 55.40% | VOC2007 test 평가 |
| Full-layer regression | VOC 입력 10종, 이미지당 raw output 100,800개, mismatch 0 | 자동 scoreboard |
| AXI stress | 33,600 beat, input gap 3,729 cycle, output stall 18,200 cycle | AXI VIP simulation |
| ZCU104 구현 자원 | LUT 157.3K, FF 170.3K, BRAM 244, URAM 64, DSP 1,152 | Vivado implementation report |
| ZCU104 배치·배선 | legal-route baseline 확보 | route report |
| 최종 board video FPS | 공개 전 검증 단계 | bitstream/HWH pair와 board 측정 필요 |

수치는 서로 다른 검증 경계를 섞지 않는다. 예를 들어 cycle 기반 FPS, Vivado power estimate와 실제 PYNQ 영상 FPS는 별도의 결과이며, 최종 보드 측정 전에는 같은 성과로 표현하지 않는다.

## Portfolio map

| 영역 | 핵심 내용 | 추천 독자 |
|---|---|---|
| [AI Hardware Survey](01_AI_HARDWARE_SURVEY/README.md) | 양자화·pruning·dataflow·memory·power·physical design의 연결 | AI 가속기 기술 지도를 먼저 보고 싶은 분 |
| [YOLOv5s RTL Accelerator](02_YOLOV5S_RTL_ACCELERATOR/README.md) | SW–RTL 수치 계약부터 AXI/DMA와 ZCU104 구현까지의 주 프로젝트 | RTL·FPGA·SoC 설계 역량을 검토하는 분 |
| [Mission-System Relevance](02_YOLOV5S_RTL_ACCELERATOR/docs/08_MISSION_SYSTEM_RELEVANCE.md) | 실시간 센서 처리와 임무 시스템 관점에서의 기술 연관성 및 한계 | 방산·항공·무인체계 HW 직무 검토자 |
| [Engineering Notes](02_YOLOV5S_RTL_ACCELERATOR/engineering_notes/README.md) | AXI handshake, BRAM/URAM, OOC, DCP, timing·congestion 실무 노트 | 구현 세부 판단을 확인하려는 엔지니어 |
| [MobileNet RTL Accelerator](03_MOBILENET_RTL_ACCELERATOR/README.md) | 다른 CNN 구조에 대한 독립 설계 경험 | 확장 경험을 확인하려는 분 |

<p align="center">
  <img src="assets/diagrams/portfolio_map.svg" alt="Portfolio map" width="1050">
</p>

## Core engineering contribution

### Model-preserving hardware challenge

계층이나 채널을 임의로 크게 줄이면 구현은 쉬워지지만, 성능·자원 개선이 모델 축소 때문인지 하드웨어 설계 때문인지 분리하기 어렵다. 본 연구는 YOLOv5s의 backbone, neck, residual/concat, upsampling과 multi-scale detection의 주요 흐름을 유지해 실제 graph의 이질성과 메모리 수명 문제를 보존했다.

### Dependency-aware multi-layer execution

각 계층을 독립적으로 처리하지 않고 의존 관계가 있는 인접 2~3개 계층을 하나의 실행 범위로 분석했다. 데이터 준비 시점과 분기 관계에 따라 독립 연산 병렬화, 행 단위 전달, 생산–소비 중첩과 검출 경로 결합을 선택하고, 고정된 공유 PE fabric의 역할을 구간별로 전환했다. 개별 기법의 최초성을 주장하는 대신, **compute·data supply·control 병목을 하나의 full-network RTL에서 함께 닫은 방법론**을 기여의 중심으로 둔다.

### Evidence-driven closure

설계 변경은 정확성, protocol, timing, power와 resource를 동시에 확인한다. 한 지표가 좋아져도 다른 지표 또는 기능이 악화되면 채택하지 않는다. 특히 full AXI/DMA 통합 뒤 발생한 routing-dominated timing 문제는 Tcl로 동일 형식의 보고서를 수집하고 legal-route DCP, incremental reuse와 critical-path 분석을 통해 재현 가능한 문제로 바꾸었다.

## Why this matters for mission systems

전자기전·감시정찰·무인체계와 같은 임무 시스템에서는 높은 peak 연산량만으로 충분하지 않다. 입력 데이터의 경계, 고정소수점 수치 규칙, backpressure, 완료 시점과 오류 상태가 예측 가능해야 하며 제한된 전력·자원에서 지속적으로 동작해야 한다. 본 프로젝트는 다음 역량을 직접 보여준다.

- 센서/영상 AI workload를 cycle-level RTL 요구사항으로 변환
- 저정밀화 정확도와 PPA를 함께 판단하는 SW–HW co-design
- full-network bit-exact regression과 AXI stall 조건 검증
- PS–DDR–DMA–PL 경계를 포함한 SoC 통합
- 합성 결과가 아닌 배치·배선·DRC·timing을 기준으로 한 구현 판단
- 공개 interface와 비공개 핵심 구조를 구분하는 disclosure discipline

본 프로젝트가 군용 인증, 안전 인증 또는 실환경 전자기전 성능을 획득했다는 의미는 아니다. 공개된 학술 FPGA 사례를 통해 **신뢰성 있는 실시간 엣지 AI 하드웨어를 설계·검증하는 기반 역량**을 제시한다.

## Recommended reading path

1. [YOLOv5s project overview](02_YOLOV5S_RTL_ACCELERATOR/README.md)
2. [Model preservation and hardware contribution](02_YOLOV5S_RTL_ACCELERATOR/docs/01_MODEL_PRESERVATION_AND_HARDWARE_CONTRIBUTION.md)
3. [Verification strategy](02_YOLOV5S_RTL_ACCELERATOR/docs/03_VERIFICATION_STRATEGY.md)
4. [AXI VIP verification](02_YOLOV5S_RTL_ACCELERATOR/docs/04_AXI_VIP_VERIFICATION.md)
5. [Physical design debugging](02_YOLOV5S_RTL_ACCELERATOR/docs/06_PHYSICAL_DESIGN_DEBUGGING.md)
6. [Results and limitations](02_YOLOV5S_RTL_ACCELERATOR/docs/07_RESULTS_AND_LIMITATIONS.md)

## Disclosure

이 저장소에는 방산 기밀, 기업 영업비밀 또는 제3자 비공개 자료가 없다. production RTL, trained weights, parameter payload, golden vector, 상세 architecture, Vivado generated product와 bitstream은 공개하지 않는다. 세부 기준은 [Disclosure Policy](DISCLOSURE_POLICY.md)를 따른다.

# Real-Time Edge System Relevance

[← YOLOv5s project](../README.md) · [Portfolio home](../../README.md)

## Why this experience is relevant

실시간 센서·영상 데이터를 처리하는 엣지 AI 하드웨어는 높은 연산량뿐 아니라 예측 가능한 동작, 제한된 자원, interface correctness와 검증 가능성을 함께 요구한다. 본 프로젝트는 다음 기반 문제를 실제 RTL과 SoC 수준에서 다뤘다.

| 실시간 시스템의 요구 | 프로젝트에서 다룬 대응 역량 |
|---|---|
| 정해진 시간 안에 반복 가능한 처리 | cycle-level controller와 full-network schedule 분석 |
| 정수 연산 결과의 추적 가능성 | QAT–integer–RTL 수치 계약과 bit-exact scoreboard |
| 입력 지연·출력 정체에 대한 안정성 | AXI4-Stream `TVALID/TREADY`, input gap, backpressure stress |
| 제한된 FPGA 자원에서의 구현 | 공유 PE, mixed precision, BRAM–URAM mapping과 PPA trade-off |
| processor와 accelerator 사이의 데이터 이동 | PS–DDR–DMA–PL control/data plane 분리 |
| 구현 단계의 물리적 불확실성 | timing, high-fanout, congestion, DRC와 routed DCP 분석 |
| 핵심 IP 보호와 외부 연동 | 공개 interface와 비공개 core를 구분한 repository boundary |

## Reliability is an engineering process

SystemVerilog로 설계했다는 사실만으로 신뢰성이 생기지는 않는다. 본 프로젝트에서 신뢰성은 다음의 연속된 합격 조건으로 정의했다.

```text
Model accuracy
  → fixed-point semantic agreement
  → cycle and state correctness
  → AXI protocol behavior under stall
  → route / timing / DRC evidence
  → board-level replay and continuous-frame measurement
```

각 단계는 다음 단계의 결과를 대신하지 않는다. 예를 들어 RTL mismatch 0은 AXI timing closure를 보장하지 않고, legal route는 최종 보드 FPS를 증명하지 않는다. 이러한 구분을 통해 오류가 수치 모델, RTL control, protocol 또는 물리 구현 중 어느 경계에서 발생했는지 추적할 수 있다.

## Real-time AI integration boundary

공개 가능한 외부 구조는 다음과 같다.

```text
Camera / video source
        ↓
PS preprocessing and DDR buffer
        ↓ AXI DMA MM2S
Private mixed-precision RTL accelerator
        ↓ AXI DMA S2MM
PS decode / NMS / display
```

Board runtime은 다중 버퍼와 bounded queue를 사용해 capture, preprocess, serialized PL inference, postprocess와 display를 분리하도록 설계했다. Frame ID와 buffer ownership을 명시해 오래된 frame을 제거하더라도 사용 중인 DMA buffer가 덮어써지지 않게 한다. 실제 end-to-end FPS는 bitstream/HWH pair, 카메라와 display 조건을 고정한 뒤 별도로 측정해야 한다.

## Claim boundary

이 문서는 다음을 주장하지 않는다.

- 기능안전 또는 보안 인증 완료
- 모든 CNN/vision model에 대한 자동 mapping
- board 측정 전의 실시간 FPS 확정

대신 복잡한 AI workload를 저정밀 RTL로 변환하고, 수치 정확성·protocol·PPA·물리 구현을 하나의 검증 흐름으로 연결할 수 있는 설계 역량을 보여준다.

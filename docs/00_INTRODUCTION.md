# Introduction: Why YOLOv5s, Why RTL?

## Project objective

이 연구의 중심은 새로운 detection network를 제안하는 것이 아니라, 검증된 AI workload를 기능 정확성·처리량·전력·확장성을 고려한 RTL 시스템으로 변환하는 것입니다.

YOLOv5s의 backbone, neck과 multi-scale detection 흐름을 과도하게 축소하지 않고 유지함으로써 모델 단순화에서 얻은 이득과 hardware architecture에서 얻은 이득이 섞이지 않도록 했습니다. Dataset class, activation과 quantization contract는 목표 응용과 RTL 수치체계에 맞췄습니다. 따라서 “원본 모델을 완전히 변경하지 않았다”가 아니라, **주요 graph 구조는 보존하고 수치·응용 계약은 명시적으로 변환했다**고 설명하는 것이 정확합니다.

이 선택 덕분에 residual/concat branch, 서로 다른 feature-map 크기, multi-scale head와 계층 경계의 데이터 준비 문제를 제거하지 않고 RTL에서 직접 해결해야 했습니다. 즉, 구현 난도를 모델에서 삭제한 것이 아니라 memory hierarchy, scheduling, fixed-point datapath와 control correctness의 문제로 받아들였습니다.

## Hardware challenges exposed by YOLOv5s

- Layer마다 달라지는 feature-map resolution과 channel 수
- Convolution, residual add, concatenation, upsampling과 detection의 혼합
- Branch에 따라 달라지는 intermediate feature lifetime
- 제한된 on-chip memory와 반복되는 weight/feature access
- 현재 layer 연산과 다음 layer parameter 준비의 중첩
- 세 detection head의 streaming output과 host-side post-processing

이러한 특성 때문에 한 layer의 peak throughput만으로 전체 accelerator 성능을 설명할 수 없습니다. 실제 목표는 end-to-end schedule에서 연산기 유휴와 데이터 이동을 줄이고, 모든 계층의 정수 출력을 검증하는 것입니다.

## Public architectural differentiators

공개 가능한 수준에서 본 설계의 핵심은 다음과 같습니다.

- **Bottleneck-first design:** PE 사용률 숫자에서 출발하지 않고 compute, data supply와 completion/control 병목을 먼저 식별했습니다.
- **Inter-layer scope:** 항상 한 layer만 독립적으로 최적화하지 않고, 의존 관계가 있는 인접 producer-consumer 또는 branch 구간까지 함께 보았습니다.
- **Fixed-fabric reuse:** operator마다 별도 engine을 추가하는 대신 고정 compute fabric의 역할과 데이터 경로를 workload 구간에 맞게 전환했습니다.
- **Compute–memory–control closure:** local reuse와 prefetch만 따로 주장하지 않고 buffer readiness, port legality, writeback과 완료 시점을 같은 schedule에 포함했습니다.
- **Evidence continuity:** software accuracy, integer semantics, full-layer RTL, AXI backpressure와 routed implementation을 서로 분리된 데모가 아니라 하나의 검증 사슬로 연결했습니다.

개별 streaming, parallel execution, pipelining 또는 fusion 자체의 최초성을 주장하지 않습니다. 현재 강한 기여는 이들을 실제 graph 병목에 연결하고 하나의 RTL system에서 full-network 수준으로 닫은 engineering methodology입니다. 다른 network에 대한 일반성이나 baseline 대비 효율 개선률은 추가 실험 전에는 확정 claim으로 사용하지 않습니다.

자세한 경계는 [Model Preservation and Hardware Contribution](01_MODEL_PRESERVATION_AND_HARDWARE_CONTRIBUTION.md)을 참고하십시오.

## Determinism and reliability

RTL 구현의 장점은 cycle-level control입니다. 그러나 신뢰성은 구현 언어가 아니라 검증 과정에서 만들어집니다. 본 프로젝트는 software model, integer reference, RTL, AXI wrapper와 physical implementation 사이에 명시적인 acceptance criteria를 두었습니다.

```text
Numeric correctness
  + Cycle/protocol correctness
  + Full-network regression
  + Timing/DRC sign-off
  = Deployable hardware confidence
```

## What is intentionally not disclosed

논문 투고 전 보호가 필요한 PE microarchitecture, multi-layer scheduling rule, detailed memory organization과 layer-state mapping은 공개하지 않습니다. 공개 문서는 외부 interface, 검증 방법, 구현 결과와 engineering decisions에 집중합니다.


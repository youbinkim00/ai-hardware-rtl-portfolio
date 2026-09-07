# Introduction: Why YOLOv5s, Why RTL?

## Project objective

이 연구의 중심은 새로운 detection network를 제안하는 것이 아니라, 검증된 AI workload를 기능 정확성·처리량·전력·확장성을 고려한 RTL 시스템으로 변환하는 것입니다.

YOLOv5s의 backbone, neck과 multi-scale detection 흐름을 과도하게 축소하지 않고 유지함으로써 모델 단순화에서 얻은 이득과 hardware architecture에서 얻은 이득이 섞이지 않도록 했습니다. Dataset class와 quantization contract는 목표 응용과 RTL 수치체계에 맞췄습니다.

## Hardware challenges exposed by YOLOv5s

- Layer마다 달라지는 feature-map resolution과 channel 수
- Convolution, residual add, concatenation, upsampling과 detection의 혼합
- Branch에 따라 달라지는 intermediate feature lifetime
- 제한된 on-chip memory와 반복되는 weight/feature access
- 현재 layer 연산과 다음 layer parameter 준비의 중첩
- 세 detection head의 streaming output과 host-side post-processing

이러한 특성 때문에 한 layer의 peak throughput만으로 전체 accelerator 성능을 설명할 수 없습니다. 실제 목표는 end-to-end schedule에서 연산기 유휴와 데이터 이동을 줄이고, 모든 계층의 정수 출력을 검증하는 것입니다.

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


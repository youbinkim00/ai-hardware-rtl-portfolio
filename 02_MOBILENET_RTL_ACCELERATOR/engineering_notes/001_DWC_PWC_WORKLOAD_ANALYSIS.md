# DWC / PWC Workload Analysis

## Problem

MobileNetV1은 standard convolution을 줄인 하나의 연산 형태가 아니라 **Depthwise Convolution(DWC)**과 **Pointwise Convolution(PWC)**을 반복합니다.

두 연산은 hardware가 요구하는 병렬도와 data supply 특성이 다릅니다.

### DWC

- channel별 독립 convolution
- weight reuse 구조가 standard convolution과 다름
- 고정된 대형 MAC array를 그대로 사용하면 유효 병렬도가 낮아질 수 있음

### PWC

- 1×1 convolution
- DWC보다 channel mixing과 MAC 수가 큼
- compute throughput과 memory bandwidth의 균형이 중요

## Design implication

따라서 하나의 고정 parallelism만으로 network 전체를 처리하기보다, layer workload에 맞게 **연산 병렬도와 data supply 방식을 함께 조정**해야 합니다.

공개 implementation evidence에서는 전체 network 관점 PE utilization **98.64%**를 기록했습니다.

## Claim boundary

세부 mapping rule과 proposed architecture figure는 논문 novelty에 해당하므로 공개하지 않습니다.

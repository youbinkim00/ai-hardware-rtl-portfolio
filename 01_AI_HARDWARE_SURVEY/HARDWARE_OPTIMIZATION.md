# Hardware Architecture Optimization

## 1. Dataflow and mapping

Convolution loop를 어떤 공간·시간 순서로 PE와 memory에 배치하는지에 따라 weight, activation과 partial sum의 reuse가 달라집니다.

| 대표 관점 | 유지하려는 데이터 | 유리한 조건 | 주요 비용 |
|---|---|---|---|
| Weight-stationary | Weight | Weight reuse가 크고 array 공급이 쉬운 경우 | Activation/partial-sum 이동 |
| Output-stationary | Partial sum | Reduction이 길고 output accumulation이 큰 경우 | Weight/activation broadcast |
| Row-stationary | 여러 data type의 reuse 균형 | Convolution sliding-window locality | Mapping/control 복잡도 |
| Spatial mapping | 여러 PE가 동시 계산 | 충분한 독립 작업과 bandwidth | 작은 shape에서 underutilization |
| Temporal mapping | PE를 시간 공유 | 제한된 area와 다양한 operator | Cycle 증가와 buffer 요구 |

[Eyeriss](https://eyeriss.mit.edu/) 계열은 data movement와 layer shape를 함께 보는 대표적인 연구입니다. [Eyeriss v2](https://people.csail.mit.edu/emer/media/papers/2019.04.jetcas.eyeriss_v2.pdf)는 compact/sparse network의 다양한 shape에 대응하기 위한 flexible on-chip network를 제시합니다.

## 2. PE array and arithmetic

- Lane/PE parallelism: throughput과 routing/fanout/area의 trade-off
- SIMD 및 operand packing: 낮은 precision을 실제 병렬 처리량으로 변환
- Adder tree와 accumulation: pipeline 위치, overflow width와 reduction topology가 중요
- DSP mapping: RTL latency contract를 보존하면서 device primitive register 활용 여부 확인
- Requantization: multiplier, shift, rounding과 saturation의 latency·resource 균형
- Operator sharing: 전용 engine duplication과 shared-fabric mux/control 비용 비교

Peak GOPS만으로는 충분하지 않습니다. Useful operation cycle, lane utilization, memory stall과 end-to-end latency를 함께 보고해야 합니다.

## 3. Memory hierarchy and data movement

```text
Off-chip memory
   ↕ burst / DMA
Global on-chip buffer
   ↕ tile / row transfer
Local buffer or register file
   ↕ operand delivery
PE / accumulator
```

주요 최적화:

- Tiling과 double buffering
- Feature/weight reuse
- Bank partitioning과 port-conflict 제거
- Line/local buffer
- Current compute와 next parameter prefetch 중첩
- BRAM/URAM/register-file의 capacity·width·latency 배치
- Intermediate tensor를 off-chip에 쓰지 않는 inter-layer streaming/fusion

[Timeloop](https://research.nvidia.com/publication/2019-03_timeloop-systematic-approach-dnn-accelerator-evaluation)은 workload mapping과 architecture를 함께 탐색하며 performance와 energy를 비교하는 대표 framework입니다. [Accelergy](https://timeloop.csail.mit.edu/previous_versions/timeloop-accelergy-v3/accelergy)는 component action count와 energy/area model을 연결합니다.

## 4. Inter-layer execution

- **Streaming:** Producer의 일부 결과가 준비되면 consumer가 시작
- **Parallel execution:** Dependency가 없는 branch 또는 독립 작업을 동시에 처리
- **Pipeline:** Producer-consumer rate를 맞춰 서로 다른 단계를 중첩
- **Fusion:** Intermediate data를 외부 또는 큰 memory에 materialize하지 않고 연속 처리

개별 개념은 널리 알려져 있습니다. 실제 설계에서 중요한 것은 dependency, live buffer capacity, read/write port, rate balance와 completion 조건을 모두 만족하는 legal schedule을 만드는 것입니다.

## 5. Sparsity hardware

Sparse execution에는 단순 zero count 이상이 필요합니다.

- Compressed format decode
- Index/metadata fetch
- Nonzero work distribution
- PE load balancing
- Sparse accumulation address 관리
- Dense fallback 또는 low-sparsity 구간 처리

따라서 dense baseline과 비교할 때 decoder/control/memory overhead를 포함해야 합니다.

## 6. Power-oriented RTL

- Register clock-enable 기반 hold
- Operand isolation으로 combinational toggle 차단
- RAM enable과 write enable의 정확한 qualification
- Unused pipeline/state의 data update 억제
- Clock gating은 device 권장 primitive와 clock-domain 안전성을 확인한 뒤 적용
- Workload-informed switching activity로 dynamic power 추정

AMD [UG907](https://docs.amd.com/r/en-US/ug907-vivado-power-analysis-optimization/Use-Device-Resources-More-Efficiently)은 block RAM의 enable rate와 clock rate를 power 최적화의 중요한 요소로 설명합니다. 그러나 toggle 감소는 기능 regression과 timing을 통과한 뒤 실제 activity 기반 power로 효과를 확인해야 합니다.

## 7. Interface and system optimization

- AXI4-Lite: configuration/status와 low-rate control
- AXI4 memory-mapped: DDR burst access
- AXI4-Stream: payload transfer와 backpressure
- DMA: CPU 대신 memory–stream 이동 수행
- FIFO: burst/compute rate 차이와 host stall 흡수
- Interrupt/polling: latency, software overhead와 recovery trade-off
- Multi-buffer pipeline: capture, preprocess, PL, postprocess와 display 중첩

AMD [AXI DMA PG021](https://docs.amd.com/r/en-US/pg021_axi_dma/Core-Overview)은 MM2S와 S2MM channel, AXI4-Lite register control 및 optional scatter-gather의 역할을 구분합니다.

## 8. Physical-aware optimization

RTL 기능과 synthesis utilization이 같아도 placement와 routing에 따라 결과가 달라질 수 있습니다.

- High-fanout control의 local replication 또는 hierarchy 경계 등록
- Wide mux와 long control-to-enable path 축소
- Pipeline stage와 physical region의 일치
- Memory/DSP column 접근 및 cascade 방향 고려
- Congestion-aware placement directive
- 성공 route DCP의 보존과 제한적인 incremental implementation

AMD [UG906](https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Router-Initial-Congestion-Reporting)에서 router congestion은 방향·배선 종류·영역별로 분석하며, 심한 congestion에는 logic/connectivity 또는 placement strategy 검토가 필요하다고 설명합니다.

## 9. Hardware acceptance criteria

- Functional regression과 cycle/protocol assertions 통과
- 동일 workload와 clock constraint 사용
- Routed timing에서 setup/hold 확인
- LUT/FF/DSP/BRAM/URAM과 interface resource를 함께 보고
- Activity source와 confidence를 명시한 power 분석
- Throughput, single-frame latency와 end-to-end latency 분리
- Host/DMA/postprocess를 포함한 system bottleneck 측정

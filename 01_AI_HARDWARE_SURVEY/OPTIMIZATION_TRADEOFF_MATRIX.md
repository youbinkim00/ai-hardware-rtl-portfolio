# Optimization Trade-off Matrix

아래 표의 화살표는 일반적인 가능성을 나타내며 보장값이 아닙니다. 실제 효과는 workload, hardware 지원과 구현 품질에 따라 달라집니다.

| 기법 | Accuracy | Latency/Throughput | Energy | Area/Memory | 반드시 확인할 것 |
|---|---|---|---|---|---|
| PTQ | ↓ 가능 | ↑ 가능 | ↓ 가능 | ↓ | Calibration, integer kernel 지원 |
| QAT | PTQ보다 방어 가능 | ↑ 가능 | ↓ 가능 | ↓ | Fake-quant와 RTL semantics 일치 |
| Mixed precision | Pareto 개선 가능 | HW 종속 | HW 종속 | ↓ 가능 | Precision 전환/scale overhead |
| Structured pruning | ↓ 가능 | ↑ 가능 | ↓ 가능 | ↓ | 실제 shape와 kernel 변화 |
| Unstructured pruning | ↓ 가능 | Sparse HW에서 ↑ | Sparse HW에서 ↓ | Weight storage ↓ | Metadata/decode/load balance |
| Knowledge distillation | ↑/회복 가능 | Student graph에 종속 | Student graph에 종속 | Student에 종속 | 최종 student 독립 평가 |
| Low-rank decomposition | ↓ 가능 | ↑ 또는 중간 tensor로 ↓ | ↓ 가능 | ↓ 가능 | Intermediate traffic |
| Tiling/local reuse | 동일 | Stall 감소 가능 | Data movement ↓ | Local memory ↑ | Access count, port conflict |
| Double buffering/prefetch | 동일 | Boundary wait ↓ | 평균 power ↑ 가능, energy ↓ 가능 | Buffer/control ↑ | Overlap과 buffer ownership |
| PE parallelism 증가 | 동일 | Throughput ↑ | Energy는 utilization에 종속 | DSP/LUT/routing ↑ | Bandwidth와 placement |
| Inter-layer fusion | 동일 | Boundary wait ↓ | Intermediate traffic ↓ | Live buffer ↑ 가능 | Dependency와 lifetime |
| Operand isolation | 동일 | 보통 동일 | Toggle ↓ | Gating logic 소폭 ↑ | Enable critical path |
| Clock gating | 동일 | Wake-up/clocking 제약 | Clock power ↓ | Clock control ↑ | FPGA 권장 primitive와 timing |
| Wider AXI/data path | 동일 | Transfer cycle ↓ 가능 | System 종속 | Interconnect/FIFO ↑ | Routing, packing과 burst |
| Deeper pipeline | 동일 | Fmax ↑ 가능, latency ↑ | Clock/FF power ↑ 가능 | FF/control ↑ | Valid alignment와 congestion |

## Interpretation examples

- Pruning으로 parameter가 50% 줄어도 dense datapath가 zero MAC을 그대로 실행하면 throughput은 거의 변하지 않을 수 있습니다.
- Local buffer가 큰 memory read를 줄여도 추가 buffer의 static/clock/write 비용을 포함한 total energy는 별도로 계산해야 합니다.
- Pipeline은 critical path를 자르지만 valid/control register와 routing density를 늘릴 수 있습니다.
- Wider stream은 beat 수를 줄이지만 wide cross-chip net과 data-width converter가 생기면 timing 또는 congestion이 악화될 수 있습니다.

따라서 최적화의 최종 판정은 항상 다음 순서를 따릅니다.

```text
Functional correctness
 → target workload cycle behavior
 → routed PPA
 → system-level measurement
```

# Software–Hardware Co-design

## Co-design은 무엇인가

Co-design은 software와 hardware가 각각 최적화된 뒤 마지막에 연결되는 과정이 아닙니다. Model graph, numeric representation, data layout와 accelerator capability를 같은 설계 loop에서 결정하는 과정입니다.

```text
Application requirement
 → model and accuracy baseline
 → hardware cost model
 → precision / sparsity / operator contract
 → architecture and mapping
 → RTL and physical result
 → measured accuracy / latency / energy
 → revise the contract
```

## Proxy metric과 실제 metric

| Proxy | 알려주는 것 | 단독으로 알 수 없는 것 |
|---|---|---|
| Parameter count | Model storage 규모 | Runtime data movement와 utilization |
| MAC/FLOP count | Arithmetic work 규모 | Memory stall, sparsity overhead와 real latency |
| Bit width | Operand/storage precision | 실제 packing, scale cost와 accuracy |
| Sparsity ratio | Zero 비율 | Decode, imbalance와 skip 가능 cycle |
| Peak GOPS | 이론적 compute capacity | Full-network useful throughput |
| Pre-route power | 초기 비교 방향 | Routed capacitance와 real workload activity |

Hardware-aware 방법은 proxy를 버리는 것이 아니라, proxy가 실제 target metric과 얼마나 연결되는지 검증합니다. [HAQ](https://openaccess.thecvf.com/content_CVPR_2019/html/Wang_HAQ_Hardware-Aware_Automated_Quantization_With_Mixed_Precision_CVPR_2019_paper.html)과 [ProxylessNAS](https://arxiv.org/abs/1812.00332)는 target hardware feedback을 optimization loop에 넣는 대표 사례입니다.

## 실무적인 decision loop

1. **Acceptance criteria 고정:** Accuracy, clock, latency, resource, protocol과 power 측정 범위를 먼저 정합니다.
2. **Single-variable experiment:** Quantization, buffer, parallelism 또는 pipeline 변경을 한 번에 하나씩 적용합니다.
3. **Functional gate:** Bit-exact 또는 tolerance regression이 실패하면 PPA가 좋아도 폐기합니다.
4. **Physical gate:** Synthesis 추정이 좋아도 route/timing이 악화되면 재평가합니다.
5. **System gate:** DMA, software postprocess 또는 display가 병목이면 accelerator FPS와 demo FPS를 구분합니다.
6. **Evidence ledger:** 조건, artifact revision, tool version과 결과를 함께 기록합니다.

## Fair comparison checklist

- 같은 dataset split과 preprocessing
- 같은 accuracy target 또는 Pareto curve
- 같은 FPGA/device/technology와 clock constraint
- 같은 arithmetic precision과 overflow rule
- 같은 memory capacity와 external bandwidth 가정
- Controller, decoder, buffer와 interface overhead 포함
- Latency와 throughput을 혼동하지 않음
- Average power와 energy/inference를 함께 확인
- 예상, simulation, post-route estimate와 board measurement 구분

## YOLOv5s case-study connection

이 포트폴리오의 YOLOv5s 사례는 다음 연결을 보여줍니다.

```text
QAT accuracy
 ↔ RTL integer contract
 ↔ compute/memory/control schedule
 ↔ AXI/DMA behavior
 ↔ route/timing feasibility
```

모델 graph를 과도하게 축소하지 않은 이유도 이 연결을 평가하기 위해서입니다. Model compression에서 얻은 이득과 hardware scheduling에서 얻은 이득을 섞지 않고, 실제 detector의 branch와 multi-scale output을 유지한 상태에서 RTL 문제를 해결합니다.

세부 사례는 [YOLOv5s RTL Accelerator](../03_YOLOV5S_RTL_ACCELERATOR/README.md)를 참고하십시오.

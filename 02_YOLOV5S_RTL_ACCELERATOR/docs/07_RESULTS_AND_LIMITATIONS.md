# Results and Limitations

## Verified results

| Category | Evidence | Status |
|---|---|---:|
| QAT validation | VOC2007 test set evaluation | Verified |
| Integer reference | RTL-equivalent arithmetic evaluation | Verified |
| RTL regression | VOC inputs 10종, full-layer/output mismatch 0 | Verified |
| Detection output | 이미지당 raw output 100,800개 검사 | Verified |
| AXI VIP | 33,600 beat data/handshake metadata 비교 | Verified |
| Input discontinuity | 3,729 input-gap cycles 포함 | Verified |
| Output backpressure | 18,200 stalled cycles 포함 | Verified |
| ZCU104 legal route baseline | Routing error/unrouted/overlap 0 | Verified |
| Selective wrapper timing guardband | 5.000 ns nominal과 4.800 ns local guard 이중 검증 | Experimental / Pending |
| ZCU104 200 MHz closure | Incremental implementation 진행 | Pending |
| PYNQ video demo/FPS | Board 측정 전 | Pending |

## Accuracy context

기존 내부 평가에서 QAT 모델과 RTL-equivalent integer model 사이의 accuracy 차이를 별도로 확인했습니다. 공개용 최종 표에는 checkpoint, evaluation script와 dataset manifest를 다시 고정한 뒤 수치를 확정합니다. 현재 문서의 핵심은 floating accuracy를 과장하는 것이 아니라 software-to-RTL 변환 손실과 RTL mismatch를 분리했다는 점입니다.

## Known limitations

- 현재 accelerator는 arbitrary runtime graph를 실행하는 범용 NPU가 아니라 YOLOv5s 계열 workload에 최적화된 설계입니다.
- 상세 dataflow 선택 규칙과 multi-layer schedule은 논문 심사 전 공개하지 않습니다.
- Implementation power는 activity source에 따라 달라지므로 SAIF 기반 평가 전에는 확정 절감률을 주장하지 않습니다.
- PYNQ video throughput은 전처리·DMA·PL·후처리·display를 분리 측정한 뒤 제시해야 합니다.
- 하나의 legal route가 timing closure를 의미하지 않으므로 WNS/TNS와 DRC를 별도 관리합니다.

## Update rule

Pending 항목은 예상치로 채우지 않습니다. 최종 report 또는 board measurement가 확보되면 날짜, configuration과 측정 경계를 함께 기록합니다.

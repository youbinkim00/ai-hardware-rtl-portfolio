# Results and Limitations

[← YOLOv5s project](../README.md) · [Portfolio home](../../README.md)

## Evidence table

| Category | Result | Status |
|---|---:|---:|
| Selective mixed-precision ablation | 내부 activation 일괄 A4 baseline 대비 mAP@0.5:0.95 +0.46%p | Verified in software evaluation |
| RTL numeric model | mAP@0.5 79.79%, mAP@0.5:0.95 55.40% | Verified on VOC2007 test |
| PE utilization | 90.8% | Measured from full-inference RTL cycle schedule |
| RTL regression | VOC 입력 10종, 이미지당 raw output 100,800개, mismatch 0 | Verified |
| AXI VIP | 33,600 beat의 data/handshake/`TKEEP`/`TLAST` 비교 | Verified |
| Input discontinuity | 3,729 input-gap cycles 포함 | Verified |
| Output backpressure | 18,200 stalled cycles 포함 | Verified |
| ZCU104 resources | LUT 157.3K, FF 170.3K, BRAM 244, URAM 64, DSP 1,152 | Vivado implementation report |
| ZCU104 legal route baseline | Routing error/unrouted/overlap 0 | Verified |
| ZCU104 PYNQ object-detection demo | 실제 board + monitor detection overlay evidence | Implemented / demonstrated |
| Final clock timing closure | 후보별 190–200 MHz 검증 | In progress |
| Numeric continuous-video FPS | public matching `.bit`/`.hwh` + measurement log 미포함 | Not published |

## Measurement boundaries

- `mAP`는 고정된 checkpoint, dataset split과 evaluation script에 종속된다.
- PE utilization은 전체 cycle 중 유효 연산 cycle을 기준으로 한 RTL schedule 결과이다.
- Resource는 지정 device와 Vivado configuration의 implementation report에서 얻는다.
- GOPS/FPS가 clock와 cycle count로 산출된 경우 실제 camera-to-display FPS와 구분해야 한다.
- Vivado power는 activity source와 환경 조건에 따른 추정치이며, board 실측 전력과 동일하지 않다.
- Legal route는 timing pass를 의미하지 않으므로 WNS/TNS, hold, DRC와 route status를 별도 관리한다.
- PYNQ demo 구현 여부와 numeric continuous-video FPS 공개 benchmark는 서로 다른 evidence boundary이다.

## Known limitations

- 현재 accelerator는 arbitrary runtime graph를 실행하는 범용 NPU가 아니라 YOLOv5s 계열 workload에 최적화된 설계이다.
- 상세 dataflow 선택 규칙과 multi-layer schedule은 논문 심사 전 공개하지 않는다.
- MobileNetV1이라는 독립 workload의 RTL/FPGA/PYNQ 구현 경험은 별도로 확보했지만, YOLOv5s와 MobileNetV1 두 사례만으로 arbitrary CNN에 대한 일반성을 입증하지는 않는다.
- Implementation power는 SAIF 기반 activity와 board 실측 전력을 분리해 제시해야 한다.
- PYNQ video throughput은 전처리·DMA/PL·후처리·display를 분리 측정한 public measurement evidence가 있을 때만 numeric benchmark로 제시한다.

## Update rule

미완료 항목은 예상치로 채우지 않는다. 최종 report 또는 공개 가능한 board measurement가 확보되면 날짜, platform, clock, tool version과 측정 경계를 함께 기록한다.
